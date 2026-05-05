import Foundation

public struct ChordProRenderer: Sendable {

    public init() {}

    public func render(_ song: Song) -> String {
        var output: [String] = []

        for section in song.sections {
            if !section.header.isEmpty {
                output.append("[\(section.header)]")
            }
            output.append(contentsOf: renderSectionBars(section.bars))
        }

        return output.joined(separator: "\n")
    }

    func renderSectionBars(_ bars: [Bar]) -> [String] {
        var result: [String] = []
        var i = 0

        while i < bars.count {
            let bar = bars[i]

            if bar.chords.isEmpty {
                result.append(bar.lyrics)
                i += 1
            } else if bar.lyrics.isEmpty {
                var group: [Bar] = []
                while i < bars.count && !bars[i].chords.isEmpty && bars[i].lyrics.isEmpty {
                    group.append(bars[i])
                    i += 1
                }
                result.append(contentsOf: renderChordOnlyBars(group))
            } else {
                var group: [Bar] = []
                while i < bars.count && !bars[i].chords.isEmpty && !bars[i].lyrics.isEmpty {
                    group.append(bars[i])
                    i += 1
                }
                result.append(contentsOf: renderChordLyricBars(group))
            }
        }

        return result
    }

    func renderChordOnlyBars(_ group: [Bar]) -> [String] {
        group.chunked(size: 4).map { chunk in
            if chunk.contains(where: { $0.chords.count > 1 }) {
                let barStrings = chunk.map { bar in
                    bar.chords.map(\.text).joined(separator: " ")
                }
                return "| " + barStrings.joined(separator: " | ") + " |"
            } else {
                return chunk.map { $0.chords[0].text }.joined(separator: " ")
            }
        }
    }

    func renderChordLyricBars(_ group: [Bar]) -> [String] {
        group.chunked(size: 4).map { chunk in
            chunk.map { bar in
                let chordStr = bar.chords.map(\.text).joined(separator: " ")
                return "[\(chordStr)]\(bar.lyrics)"
            }.joined(separator: " ")
        }
    }
}

extension Array {
    func chunked(size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
