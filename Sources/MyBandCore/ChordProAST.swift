import Foundation

public struct Song: Equatable, Sendable {
    public var sections: [Section]

    public init(sections: [Section]) {
        self.sections = sections
    }
}

public struct Section: Equatable, Sendable {
    public var header: String
    public var bars: [Bar]

    public init(header: String, bars: [Bar]) {
        self.header = header
        self.bars = bars
    }
}

public struct Bar: Equatable, Sendable {
    public var chords: [Chord]
    public var lyrics: String

    public init(chords: [Chord], lyrics: String = "") {
        self.chords = chords
        self.lyrics = lyrics
    }
}

public struct Chord: Equatable, Sendable {
    public var root: String
    public var quality: String

    public var text: String { root + quality }

    public init(root: String, quality: String = "") {
        self.root = root
        self.quality = quality
    }

    public init?(parsing raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first,
              "ABCDEFGabcdefg".contains(first) else {
            return nil
        }
        var index = trimmed.index(after: trimmed.startIndex)
        if index < trimmed.endIndex && (trimmed[index] == "#" || trimmed[index] == "b") {
            index = trimmed.index(after: index)
        }
        self.root = String(trimmed[trimmed.startIndex..<index])
        self.quality = String(trimmed[index...])
    }

    public static func isValidQuality(_ quality: String) -> Bool {
        if quality.isEmpty { return true }

        var remaining = quality.lowercased()[...]

        for prefix in ["min", "maj", "dim", "aug", "add", "m", "+"] {
            if remaining.hasPrefix(prefix) {
                remaining = remaining.dropFirst(prefix.count)
                break
            }
        }

        if remaining.hasPrefix("sus") {
            remaining = remaining.dropFirst(3)
            if remaining.hasPrefix("2") || remaining.hasPrefix("4") {
                remaining = remaining.dropFirst(1)
            }
        }

        for ext in ["13", "11", "9", "7", "6", "5", "4", "2"] {
            if remaining.hasPrefix(ext) {
                remaining = remaining.dropFirst(ext.count)
                break
            }
        }

        if remaining.hasPrefix("sus") {
            remaining = remaining.dropFirst(3)
            if remaining.hasPrefix("2") || remaining.hasPrefix("4") {
                remaining = remaining.dropFirst(1)
            }
        }

        while remaining.hasPrefix("#") || remaining.hasPrefix("b") {
            remaining = remaining.dropFirst(1)
            guard let digit = remaining.first, digit.isNumber else { return false }
            remaining = remaining.dropFirst(1)
            if remaining.first?.isNumber == true {
                remaining = remaining.dropFirst(1)
            }
        }

        if remaining.hasPrefix("/") {
            remaining = remaining.dropFirst(1)
            guard let root = remaining.first, "abcdefg".contains(root) else { return false }
            remaining = remaining.dropFirst(1)
            if let acc = remaining.first, acc == "#" || acc == "b" {
                remaining = remaining.dropFirst(1)
            }
        }

        return remaining.isEmpty
    }
}
