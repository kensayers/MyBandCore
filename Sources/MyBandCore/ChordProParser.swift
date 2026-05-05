import Foundation

public struct ChordProParser: Sendable {

    public init() {}

    public func parse(_ input: String) -> Song {
        let rawLines = input.components(separatedBy: .newlines)
        var sections: [Section] = []
        var currentHeader: String?
        var currentBars: [Bar] = []

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if let header = parseSectionHeader(trimmed) {
                if currentHeader != nil || !currentBars.isEmpty {
                    sections.append(Section(header: currentHeader ?? "", bars: currentBars))
                }
                currentHeader = header
                currentBars = []
            } else {
                currentBars.append(contentsOf: parseBarsFromLine(trimmed))
            }
        }

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
