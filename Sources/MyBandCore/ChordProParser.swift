import Foundation

public struct ChordProParser: Sendable {

    public init() {}

    public func parse(_ input: String) -> Song {
        let rawLines = input.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var sections: [Section] = []
        var currentHeader: String?
        var currentBars: [Bar] = []
        var pendingChordRawLine: String?
        var pendingHasPipes = false

        func flushPendingChordLine() {
            if let raw = pendingChordRawLine {
                pendingChordRawLine = nil
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if pendingHasPipes {
                    currentBars.append(contentsOf: parsePipeBars(trimmed))
                } else {
                    currentBars.append(contentsOf: parseChordLine(trimmed).map { Bar(chords: [$0]) })
                }
            }
        }

        func bufferChordLine(_ rawLine: String, _ trimmed: String) {
            if isPipeChordLine(trimmed) {
                pendingChordRawLine = rawLine
                pendingHasPipes = true
            } else if isChordLine(trimmed) && !trimmed.contains("|") && !trimmed.contains("[") {
                pendingChordRawLine = rawLine
                pendingHasPipes = false
            } else {
                currentBars.append(contentsOf: parseBarsFromLine(trimmed))
            }
        }

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if pendingChordRawLine != nil {
                if let header = parseSectionHeader(trimmed) {
                    flushPendingChordLine()
                    if currentHeader != nil || !currentBars.isEmpty {
                        sections.append(Section(header: currentHeader ?? "", bars: currentBars))
                    }
                    currentHeader = header
                    currentBars = []
                    continue
                }

                let isLyrics: Bool
                if pendingHasPipes {
                    isLyrics = !trimmed.isEmpty
                        && !isTabLine(trimmed)
                        && !trimmed.contains("[")
                        && !isPipeChordLine(trimmed)
                        && !(isChordLine(trimmed) && !trimmed.contains("|"))
                } else {
                    isLyrics = !trimmed.isEmpty
                        && !isTabLine(trimmed)
                        && !trimmed.contains("|")
                        && !trimmed.contains("[")
                        && !isChordLine(trimmed)
                }

                if isLyrics {
                    let chordRaw = pendingChordRawLine!
                    pendingChordRawLine = nil
                    if pendingHasPipes {
                        if trimmed.contains("|") {
                            currentBars.append(contentsOf: mergePipeChordAndLyricLines(
                                chordLine: chordRaw,
                                lyricsLine: rawLine
                            ))
                        } else {
                            var bars = parsePipeBars(chordRaw.trimmingCharacters(in: .whitespaces))
                            if !bars.isEmpty {
                                bars[0].lyrics = trimmed
                            }
                            currentBars.append(contentsOf: bars)
                        }
                    } else {
                        currentBars.append(contentsOf: mergeChordAndLyricLines(
                            chords: parseChordLineWithPositions(chordRaw),
                            lyricsLine: rawLine
                        ))
                    }
                } else {
                    flushPendingChordLine()
                    bufferChordLine(rawLine, trimmed)
                }
                continue
            }

            if let header = parseSectionHeader(trimmed) {
                if currentHeader != nil || !currentBars.isEmpty {
                    sections.append(Section(header: currentHeader ?? "", bars: currentBars))
                }
                currentHeader = header
                currentBars = []
            } else {
                bufferChordLine(rawLine, trimmed)
            }
        }

        flushPendingChordLine()

        if currentHeader != nil || !currentBars.isEmpty {
            sections.append(Section(header: currentHeader ?? "", bars: currentBars))
        }

        return Song(sections: sections)
    }

    // MARK: - Section Header

    private static let sectionPatterns: Set<String> = [
        "verse", "chorus", "bridge", "intro", "outro",
        "pre-chorus", "prechorus", "interlude", "tag",
        "ending", "instrumental", "solo", "refrain",
        "coda", "hook", "break", "turnaround"
    ]

    func parseSectionHeader(_ line: String) -> String? {
        guard line.hasPrefix("["), line.hasSuffix("]"),
              line.count >= 3 else { return nil }
        let inner = String(line.dropFirst().dropLast())
        let words = inner.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
        guard words.contains(where: { Self.sectionPatterns.contains($0) }) else { return nil }
        return inner
    }

    // MARK: - Line to Bars

    func parseBarsFromLine(_ line: String) -> [Bar] {
        if line.isEmpty { return [] }
        if isTabLine(line) { return [] }
        if line.contains("|") { return parsePipeBars(line) }
        if line.contains("[") { return parseChordLyricBars(line) }
        if isChordLine(line) {
            return parseChordLine(line).map { Bar(chords: [$0]) }
        }
        return [Bar(chords: [], lyrics: line)]
    }

    // MARK: - Tab Line Detection

    func isTabLine(_ line: String) -> Bool {
        guard let first = line.first, "ABCDEFGabcdefg".contains(first) else { return false }
        let rest = line.dropFirst()
        if let second = rest.first {
            if second == "|" {
                let afterPipe = rest.dropFirst().first
                return afterPipe == "-" || afterPipe?.isNumber == true
            }
            if (second == "#" || second == "b"), rest.dropFirst().first == "|" {
                let afterPipe = rest.dropFirst(2).first
                return afterPipe == "-" || afterPipe?.isNumber == true
            }
        }
        return false
    }

    // MARK: - Chord Lines

    func isChordLine(_ line: String) -> Bool {
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !tokens.isEmpty else { return false }
        return tokens.allSatisfy { isStrictChordToken($0) }
    }

    func isStrictChordToken(_ token: String) -> Bool {
        var t = token
        if t.hasPrefix("(") && t.hasSuffix(")") {
            t = String(t.dropFirst().dropLast())
        }
        guard let chord = Chord(parsing: t) else { return false }
        return Chord.isValidQuality(chord.quality)
    }

    func parseChordLine(_ line: String) -> [Chord] {
        line.split(separator: " ", omittingEmptySubsequences: true)
            .compactMap { token in
                var t = String(token)
                if t.hasPrefix("(") && t.hasSuffix(")") {
                    t = String(t.dropFirst().dropLast())
                }
                return Chord(parsing: t)
            }
    }

    func isPipeChordLine(_ line: String) -> Bool {
        guard line.contains("|"), !isTabLine(line) else { return false }
        let segments = line.split(separator: "|", omittingEmptySubsequences: true)
        return segments.contains { segment in
            let text = segment.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { return false }
            let tokens = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            return !tokens.isEmpty && tokens.allSatisfy { isStrictChordToken($0) }
        }
    }

    // MARK: - Pipe-Delimited Bars

    func parsePipeBars(_ line: String) -> [Bar] {
        line.split(separator: "|", omittingEmptySubsequences: true)
            .compactMap { segment -> Bar? in
                let text = segment.trimmingCharacters(in: .whitespaces)
                if text.isEmpty { return nil }
                let chords = text
                    .split(separator: " ", omittingEmptySubsequences: true)
                    .compactMap { token -> Chord? in
                        var t = String(token)
                        if t.hasPrefix("(") && t.hasSuffix(")") {
                            t = String(t.dropFirst().dropLast())
                        }
                        return Chord(parsing: t)
                    }
                guard !chords.isEmpty else { return nil }
                return Bar(chords: chords)
            }
    }

    // MARK: - Chord-Over-Lyrics Merging

    func parseChordLineWithPositions(_ rawLine: String) -> [(chord: Chord, column: Int)] {
        var results: [(chord: Chord, column: Int)] = []
        var i = rawLine.startIndex
        while i < rawLine.endIndex {
            if rawLine[i] == " " {
                i = rawLine.index(after: i)
                continue
            }
            let tokenStart = i
            while i < rawLine.endIndex && rawLine[i] != " " {
                i = rawLine.index(after: i)
            }
            var tokenStr = String(rawLine[tokenStart..<i])
            if tokenStr.hasPrefix("(") && tokenStr.hasSuffix(")") {
                tokenStr = String(tokenStr.dropFirst().dropLast())
            }
            if let chord = Chord(parsing: tokenStr), Chord.isValidQuality(chord.quality) {
                let col = rawLine.distance(from: rawLine.startIndex, to: tokenStart)
                results.append((chord, col))
            }
        }
        return results
    }

    func mergePipeChordAndLyricLines(chordLine: String, lyricsLine: String) -> [Bar] {
        let chordSegments = chordLine.split(separator: "|", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let lyricSegments = lyricsLine.split(separator: "|", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var bars: [Bar] = []
        var lyricIdx = 0
        for chordText in chordSegments {
            let chords = chordText
                .split(separator: " ", omittingEmptySubsequences: true)
                .compactMap { token -> Chord? in
                    var t = String(token)
                    if t.hasPrefix("(") && t.hasSuffix(")") {
                        t = String(t.dropFirst().dropLast())
                    }
                    return Chord(parsing: t)
                }
            if chords.isEmpty { continue }
            let lyrics = lyricIdx < lyricSegments.count ? lyricSegments[lyricIdx] : ""
            lyricIdx += 1
            bars.append(Bar(chords: chords, lyrics: lyrics))
        }
        return bars
    }

    func mergeChordAndLyricLines(chords: [(chord: Chord, column: Int)], lyricsLine: String) -> [Bar] {
        guard !chords.isEmpty else { return [] }

        var wordSpans: [(word: String, start: Int)] = []
        var i = lyricsLine.startIndex
        while i < lyricsLine.endIndex {
            if lyricsLine[i] == " " {
                i = lyricsLine.index(after: i)
                continue
            }
            let wordStart = i
            while i < lyricsLine.endIndex && lyricsLine[i] != " " {
                i = lyricsLine.index(after: i)
            }
            let col = lyricsLine.distance(from: lyricsLine.startIndex, to: wordStart)
            wordSpans.append((String(lyricsLine[wordStart..<i]), col))
        }

        var barLyrics: [[String]] = Array(repeating: [], count: chords.count)

        for (word, wordCol) in wordSpans {
            var assignedIndex = 0
            for (ci, chordInfo) in chords.enumerated() {
                if chordInfo.column <= wordCol {
                    assignedIndex = ci
                } else {
                    break
                }
            }
            barLyrics[assignedIndex].append(word)
        }

        return chords.enumerated().map { (index, chordInfo) in
            Bar(chords: [chordInfo.chord], lyrics: barLyrics[index].joined(separator: " "))
        }
    }

    // MARK: - Chord-Lyric Bars

    func parseChordLyricBars(_ line: String) -> [Bar] {
        let fragments = parseChordLyricFragments(line)
        var bars: [Bar] = []
        var pendingLyrics = ""

        for fragment in fragments {
            if let chord = fragment.chord {
                bars.append(Bar(chords: [chord], lyrics: pendingLyrics + fragment.text))
                pendingLyrics = ""
            } else {
                pendingLyrics += fragment.text
            }
        }

        if !pendingLyrics.isEmpty {
            if bars.isEmpty {
                bars.append(Bar(chords: [], lyrics: pendingLyrics))
            } else {
                bars[bars.count - 1].lyrics += pendingLyrics
            }
        }

        for i in bars.indices {
            while bars[i].lyrics.hasSuffix(" ") { bars[i].lyrics.removeLast() }
        }

        return bars
    }

    // MARK: - Internal Fragment Parsing

    private struct ChordLyricFragment {
        var chord: Chord?
        var text: String
    }

    private func parseChordLyricFragments(_ line: String) -> [ChordLyricFragment] {
        var fragments: [ChordLyricFragment] = []
        var remaining = line[...]

        while let openBracket = remaining.firstIndex(of: "[") {
            let textBefore = String(remaining[remaining.startIndex..<openBracket])
            if !textBefore.isEmpty {
                if fragments.isEmpty {
                    fragments.append(ChordLyricFragment(text: textBefore))
                } else {
                    fragments[fragments.count - 1].text += textBefore
                }
            }

            guard let closeBracket = remaining[openBracket...].firstIndex(of: "]") else {
                let rest = String(remaining[openBracket...])
                if fragments.isEmpty {
                    fragments.append(ChordLyricFragment(text: rest))
                } else {
                    fragments[fragments.count - 1].text += rest
                }
                return fragments
            }

            let chordText = String(remaining[remaining.index(after: openBracket)..<closeBracket])
            let chord = Chord(parsing: chordText)
            remaining = remaining[remaining.index(after: closeBracket)...]
            fragments.append(ChordLyricFragment(chord: chord, text: ""))
        }

        let tail = String(remaining)
        if !tail.isEmpty {
            if fragments.isEmpty {
                fragments.append(ChordLyricFragment(text: tail))
            } else {
                fragments[fragments.count - 1].text += tail
            }
        }

        return fragments
    }
}
