import Foundation

public struct ChordProRenderer: Sendable {

    public init() {}

    public func render(_ song: Song) -> String {
        var output: [String] = []

        for section in song.sections {
            if !section.header.isEmpty {
                output.append("[\(section.header)]")
            }
            for line in section.lines {
                output.append(renderLine(line))
            }
        }

        return output.joined(separator: "\n")
    }

    func renderLine(_ line: Line) -> String {
        switch line {
        case .bars(let bars):
            return renderBars(bars)
        case .chordLyric(let fragments):
            return renderChordLyric(fragments)
        case .tab(let tabLine):
            return tabLine.string + tabLine.content
        case .lyrics(let text):
            return text
        case .empty:
            return ""
        }
    }

    func renderBars(_ bars: [Bar]) -> String {
        if bars.allSatisfy({ $0.chords.count == 1 }) {
            return bars.map { $0.chords[0].text }.joined(separator: " ")
        }
        let barStrings = bars.map { bar in
            bar.chords.map(\.text).joined(separator: " ")
        }
        return "| " + barStrings.joined(separator: " | ") + " |"
    }

    func renderChordLyric(_ fragments: [ChordLyricFragment]) -> String {
        fragments.map { fragment in
            if let chord = fragment.chord {
                return "[\(chord.text)]\(fragment.text)"
            }
            return fragment.text
        }.joined()
    }
}
