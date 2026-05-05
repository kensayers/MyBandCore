import Testing
@testable import MyBandCore

struct ChordProRendererTests {
    let parser = ChordProParser()
    let renderer = ChordProRenderer()

    // MARK: - Bar Rendering

    @Test func rendersChordOnlyBarsSpaceSeparated() {
        let bars = [
            Bar(chords: [Chord(root: "A", quality: "m")]),
            Bar(chords: [Chord(root: "D")])
        ]
        let lines = renderer.renderChordOnlyBars(bars)
        #expect(lines == ["Am D"])
    }

    @Test func rendersMultiChordBarsWithPipes() {
        let bars = [
            Bar(chords: [Chord(root: "G"), Chord(root: "C")]),
            Bar(chords: [Chord(root: "A", quality: "m"), Chord(root: "D")])
        ]
        let lines = renderer.renderChordOnlyBars(bars)
        #expect(lines == ["| G C | Am D |"])
    }

    @Test func rendersMixedBarSizesWithPipes() {
        let bars = [
            Bar(chords: [Chord(root: "E")]),
            Bar(chords: [Chord(root: "A", quality: "m"), Chord(root: "D")])
        ]
        let lines = renderer.renderChordOnlyBars(bars)
        #expect(lines == ["| E | Am D |"])
    }

    @Test func rendersChordLyricBars() {
        let bars = [
            Bar(chords: [Chord(root: "G")], lyrics: "Amazing"),
            Bar(chords: [Chord(root: "C")], lyrics: "grace")
        ]
        let lines = renderer.renderChordLyricBars(bars)
        #expect(lines == ["[G]Amazing [C]grace"])
    }

    @Test func rendersFourBarsPerLine() {
        let bars = (0..<6).map { _ in Bar(chords: [Chord(root: "G")]) }
        let lines = renderer.renderChordOnlyBars(bars)
        #expect(lines.count == 2)
        #expect(lines[0] == "G G G G")
        #expect(lines[1] == "G G")
    }

    // MARK: - Section Rendering

    @Test func rendersSectionHeaders() {
        let song = Song(sections: [
            Section(header: "Intro", bars: [Bar(chords: [Chord(root: "G")])]),
            Section(header: "Verse 1", bars: [Bar(chords: [], lyrics: "Hello")])
        ])
        let output = renderer.render(song)
        #expect(output.contains("[Intro]"))
        #expect(output.contains("[Verse 1]"))
    }

    @Test func skipsEmptyHeader() {
        let song = Song(sections: [
            Section(header: "", bars: [Bar(chords: [], lyrics: "Before any section")])
        ])
        let output = renderer.render(song)
        #expect(!output.contains("["))
        #expect(output == "Before any section")
    }

    @Test func rendersMultipleSections() {
        let song = Song(sections: [
            Section(header: "Verse 1", bars: [
                Bar(chords: [Chord(root: "A", quality: "m")]),
                Bar(chords: [Chord(root: "D")]),
                Bar(chords: [], lyrics: "Hello")
            ]),
            Section(header: "Chorus", bars: [
                Bar(chords: [Chord(root: "F")]),
                Bar(chords: [Chord(root: "G")])
            ])
        ])
        let expected = """
        [Verse 1]
        Am D
        Hello
        [Chorus]
        F G
        """
        #expect(renderer.render(song) == expected)
    }

    // MARK: - Round Trip (AST equivalence)

    @Test func roundTripSimpleChordChart() {
        let input = """
        [Intro]
        Am D Am D
        [Verse 1]
        Am D Am D
        Am Dm G Dm
        [Chorus]
        F Am F Am
        """
        assertRoundTrip(input)
    }

    @Test func roundTripChordLyricSong() {
        let input = """
        [Verse 1]
        [G]Amazing [C]grace, how [G]sweet the sound
        [G]saved a [Em]wretch like [D]me
        [Chorus]
        [G]I once was [C]lost, but [G]now am found
        """
        assertRoundTrip(input)
    }

    @Test func roundTripBarLines() {
        let input = """
        [Intro]
        | G C | Am D |
        | E | F# |
        """
        assertRoundTrip(input)
    }

    @Test func roundTripMixedContent() {
        let input = """
        [Verse 1]
        G Am C D
        Lyrics go here
        [G]Inline [Am]chords with lyrics
        [Chorus]
        | G C | Am D |
        """
        assertRoundTrip(input)
    }

    @Test func roundTripAfterDark() {
        assertRoundTrip(ChordProParserTests.afterDark)
    }

    @Test func roundTripChordChart() {
        assertRoundTrip(ChordProParserTests.chordChart)
    }

    @Test func roundTripEmptyInput() {
        assertRoundTrip("")
    }

    @Test func roundTripLyricsOnly() {
        let input = """
        [Verse 1]
        Just some lyrics
        No chords at all
        """
        assertRoundTrip(input)
    }

    @Test func roundTripContentBeforeFirstSection() {
        let input = """
        Some preamble text
        [Verse 1]
        Am D
        """
        assertRoundTrip(input)
    }

    private func assertRoundTrip(_ input: String) {
        let ast = parser.parse(input)
        let output = renderer.render(ast)
        let ast2 = parser.parse(output)
        #expect(ast == ast2, "Round trip failed.\nRendered output:\n\(output)")
    }
}
