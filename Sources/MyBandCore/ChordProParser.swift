import Foundation

public struct ChordProParser: Sendable {

    public init() {}

    public func parse(_ input: String) -> Song {
        let rawLines = input.components(separatedBy: .newlines)
        var sections: [Section] = []
        var currentHeader: String?
        var currentLines: [Line] = []

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if let header = parseSectionHeader(trimmed) {
                if currentHeader != nil || !currentLines.isEmpty {
                    sections.append(Section(header: currentHeader ?? "", lines: currentLines))
                }
                currentHeader = header
                currentLines = []
            } else {
                currentLines.append(parseLine(trimmed))
            }
        }

        if currentHeader != nil || !currentLines.isEmpty {
            sections.append(Section(header: currentHeader ?? "", lines: currentLines))
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
        let base = inner.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .first ?? ""
        guard Self.sectionPatterns.contains(base) else { return nil }
        return inner
    }

    // MARK: - Line

    func parseLine(_ line: String) -> Line {
        if line.isEmpty {
            return .empty
        }
        if isTabLine(line) {
            return .tab(parseTabLine(line))
        }
        if line.contains("|") {
            return .bars(parseBars(line))
        }
        if line.contains("[") {
            return .chordLyric(parseChordLyric(line))
        }
        if isChordLine(line) {
            return .bars(parseChordLine(line).map { Bar(chords: [$0]) })
        }
        return .lyrics(line)
    }

    // MARK: - Tab Lines

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

    func parseTabLine(_ line: String) -> TabLine {
        guard let pipeIndex = line.firstIndex(of: "|") else {
            return TabLine(string: "", content: line)
        }
        let stringName = String(line[line.startIndex..<pipeIndex])
        let content = String(line[pipeIndex...])
        return TabLine(string: stringName, content: content)
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

    // MARK: - Bar Lines

    func parseBars(_ line: String) -> [Bar] {
        line.split(separator: "|", omittingEmptySubsequences: true)
            .compactMap { segment in
                let chords = segment
                    .trimmingCharacters(in: .whitespaces)
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

    // MARK: - Chord-Lyric Lines

    func parseChordLyric(_ line: String) -> [ChordLyricFragment] {
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
