import Testing
@testable import MyBandCore

struct ChordProRendererTests {
    let parser = ChordProParser()
    let renderer = ChordProRenderer()

    // MARK: - Line Rendering

    @Test func rendersEmptyLine() {
        #expect(renderer.renderLine(.empty) == "")
    }

    @Test func rendersLyricsLine() {
        #expect(renderer.renderLine(.lyrics("Hello world")) == "Hello world")
    }

    @Test func rendersTabLine() {
        let tab = TabLine(string: "e", content: "|---7--10--|----")
        #expect(renderer.renderLine(.tab(tab)) == "e|---7--10--|----")
    }

    @Test func rendersSingleChordBarsWithoutPipes() {
        let bars = [
            Bar(chords: [Chord(root: "A", quality: "m")]),
            Bar(chords: [Chord(root: "D")])
        ]
        #expect(renderer.renderBars(bars) == "Am D")
    }

    @Test func rendersMultiChordBarsWithPipes() {
        let bars = [
            Bar(chords: [Chord(root: "G"), Chord(root: "C")]),
            Bar(chords: [Chord(root: "A", quality: "m"), Chord(root: "D")])
        ]
        #expect(renderer.renderBars(bars) == "| G C | Am D |")
    }

    @Test func rendersMixedBarSizes() {
        let bars = [
            Bar(chords: [Chord(root: "E")]),
            Bar(chords: [Chord(root: "A", quality: "m"), Chord(root: "D")])
        ]
        #expect(renderer.renderBars(bars) == "| E | Am D |")
    }

    @Test func rendersChordLyricLine() {
        let fragments = [
            ChordLyricFragment(chord: Chord(root: "G"), text: "Amazing "),
            ChordLyricFragment(chord: Chord(root: "C"), text: "grace")
        ]
        #expect(renderer.renderChordLyric(fragments) == "[G]Amazing [C]grace")
    }

    @Test func rendersChordLyricWithLeadingText() {
        let fragments = [
            ChordLyricFragment(text: "That "),
            ChordLyricFragment(chord: Chord(root: "G"), text: "saved")
        ]
        #expect(renderer.renderChordLyric(fragments) == "That [G]saved")
    }

    @Test func rendersChordWithQuality() {
        let fragments = [
            ChordLyricFragment(chord: Chord(root: "F#", quality: "7"), text: "hello")
        ]
        #expect(renderer.renderChordLyric(fragments) == "[F#7]hello")
    }

    // MARK: - Full Song Rendering

    @Test func rendersSectionHeaders() {
        let song = Song(sections: [
            Section(header: "Intro", lines: [.empty]),
            Section(header: "Verse 1", lines: [.lyrics("Hello")])
        ])
        let output = renderer.render(song)
        #expect(output.contains("[Intro]"))
        #expect(output.contains("[Verse 1]"))
    }

    @Test func skipsEmptyHeader() {
        let song = Song(sections: [
            Section(header: "", lines: [.lyrics("Before any section")])
        ])
        let output = renderer.render(song)
        #expect(!output.contains("["))
        #expect(output == "Before any section")
    }

    @Test func rendersMultipleSections() {
        let song = Song(sections: [
            Section(header: "Verse 1", lines: [
                .bars([Bar(chords: [Chord(root: "A", quality: "m")]), Bar(chords: [Chord(root: "D")])]),
                .lyrics("Hello"),
                .empty
            ]),
            Section(header: "Chorus", lines: [
                .bars([Bar(chords: [Chord(root: "F")]), Bar(chords: [Chord(root: "G")])])
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
        That [G]saved a [Em]wretch like [D]me

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

    @Test func roundTripTabLines() {
        let input = """
        [Intro]
        e|-------7--10--7----|----
        B|--7h10-------------|----
        G|----------------------|----
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
