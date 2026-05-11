import Testing
@testable import MyBandCore

struct ChordProParserTests {
    let parser = ChordProParser()

    // MARK: - Chord Parsing

    @Test func parsesSimpleChord() {
        let chord = Chord(parsing: "G")
        #expect(chord?.root == "G")
        #expect(chord?.quality == "")
        #expect(chord?.text == "G")
    }

    @Test func parsesChordWithQuality() {
        let chord = Chord(parsing: "Am7")
        #expect(chord?.root == "A")
        #expect(chord?.quality == "m7")
    }

    @Test func parsesSharpChord() {
        let chord = Chord(parsing: "C#dim")
        #expect(chord?.root == "C#")
        #expect(chord?.quality == "dim")
    }

    @Test func parsesFlatChord() {
        let chord = Chord(parsing: "Bb")
        #expect(chord?.root == "Bb")
        #expect(chord?.quality == "")
    }

    @Test func parsesComplexQuality() {
        let chord = Chord(parsing: "Dsus4")
        #expect(chord?.root == "D")
        #expect(chord?.quality == "sus4")
    }

    @Test func rejectsInvalidChords() {
        #expect(Chord(parsing: "") == nil)
        #expect(Chord(parsing: "123") == nil)
        #expect(Chord(parsing: "|") == nil)
        #expect(Chord(parsing: " ") == nil)
    }

    // MARK: - Section Header Parsing

    @Test func parsesSectionHeaders() {
        #expect(parser.parseSectionHeader("[Verse 1]") == "Verse 1")
        #expect(parser.parseSectionHeader("[Chorus]") == "Chorus")
        #expect(parser.parseSectionHeader("[Bridge]") == "Bridge")
        #expect(parser.parseSectionHeader("[Intro]") == "Intro")
        #expect(parser.parseSectionHeader("[Outro]") == "Outro")
        #expect(parser.parseSectionHeader("[Pre-Chorus]") == "Pre-Chorus")
        #expect(parser.parseSectionHeader("[Interlude]") == "Interlude")
        #expect(parser.parseSectionHeader("[Solo]") == "Solo")
    }

    @Test func parsesCaseInsensitiveSectionHeaders() {
        #expect(parser.parseSectionHeader("[VERSE]") == "VERSE")
        #expect(parser.parseSectionHeader("[chorus]") == "chorus")
        #expect(parser.parseSectionHeader("[BRIDGE 2]") == "BRIDGE 2")
    }

    @Test func doesNotParseChordsAsSectionHeaders() {
        #expect(parser.parseSectionHeader("[G]") == nil)
        #expect(parser.parseSectionHeader("[Am7]") == nil)
        #expect(parser.parseSectionHeader("[C#m]") == nil)
        #expect(parser.parseSectionHeader("[Bb]") == nil)
    }

    // MARK: - Line to Bars

    @Test func emptyLineProducesNoBars() {
        #expect(parser.parseBarsFromLine("").isEmpty)
    }

    @Test func plainTextProducesLyricsBar() {
        let bars = parser.parseBarsFromLine("Just a plain line")
        #expect(bars.count == 1)
        #expect(bars[0].chords.isEmpty)
        #expect(bars[0].lyrics == "Just a plain line")
    }

    @Test func pipeLineProducesBars() {
        let bars = parser.parseBarsFromLine("| G | C |")
        #expect(bars.count == 2)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[1].chords.map(\.text) == ["C"])
    }

    @Test func pipeLineMultipleChordsPerBar() {
        let bars = parser.parseBarsFromLine("| G C | G C |")
        #expect(bars.count == 2)
        #expect(bars[0].chords.map(\.text) == ["G", "C"])
    }

    @Test func chordLineProducesSingleChordBars() {
        let bars = parser.parseBarsFromLine("G C G C")
        #expect(bars.count == 4)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[3].chords.map(\.text) == ["C"])
    }

    @Test func chordLyricLineProducesBars() {
        let bars = parser.parseBarsFromLine("[G]Hello [Am]world")
        #expect(bars.count == 2)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[0].lyrics == "Hello")
        #expect(bars[1].chords.map(\.text) == ["Am"])
        #expect(bars[1].lyrics == "world")
    }

    @Test func tabLineProducesNoBars() {
        #expect(parser.parseBarsFromLine("e|-------7--10--|----").isEmpty)
    }

    // MARK: - Chord-Lyric Bar Parsing

    @Test func parsesChordLyricBars() {
        let bars = parser.parseChordLyricBars("[G]Amazing [C]grace")
        #expect(bars.count == 2)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[0].lyrics == "Amazing")
        #expect(bars[1].chords.map(\.text) == ["C"])
        #expect(bars[1].lyrics == "grace")
    }

    @Test func chordLyricBarsWithLeadingText() {
        let bars = parser.parseChordLyricBars("That [G]saved a [Em]wretch")
        #expect(bars.count == 2)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[0].lyrics == "That saved a")
        #expect(bars[1].chords.map(\.text) == ["Em"])
        #expect(bars[1].lyrics == "wretch")
    }

    @Test func chordLyricBarsChordOnly() {
        let bars = parser.parseChordLyricBars("[G]  [C]  [D]")
        #expect(bars.count == 3)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[0].lyrics == "")
        #expect(bars[1].chords.map(\.text) == ["C"])
        #expect(bars[1].lyrics == "")
        #expect(bars[2].chords.map(\.text) == ["D"])
        #expect(bars[2].lyrics == "")
    }

    @Test func handlesUnclosedBracket() {
        let bars = parser.parseChordLyricBars("[G]Hello [broken")
        #expect(bars.count == 1)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[0].lyrics == "Hello [broken")
    }

    // MARK: - Pipe Bar Parsing

    @Test func parsesSimplePipeBars() {
        let bars = parser.parsePipeBars("| G | Am | C | D |")
        #expect(bars.count == 4)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[1].chords.map(\.text) == ["Am"])
        #expect(bars[2].chords.map(\.text) == ["C"])
        #expect(bars[3].chords.map(\.text) == ["D"])
    }

    @Test func parsesMultipleChordsPerPipeBar() {
        let bars = parser.parsePipeBars("| G C | Am D |")
        #expect(bars.count == 2)
        #expect(bars[0].chords.map(\.text) == ["G", "C"])
        #expect(bars[1].chords.map(\.text) == ["Am", "D"])
    }

    @Test func parsesPipeBarsWithoutLeadingPipe() {
        let bars = parser.parsePipeBars("G | Am | C | D")
        #expect(bars.count == 4)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[3].chords.map(\.text) == ["D"])
    }

    // MARK: - Full Song Parsing

    @Test func parsesFullSong() {
        let input = """
        [Intro]
        | G | C | G | D |

        [Verse 1]
        [G]Amazing [C]grace, how [G]sweet the sound
        That [G]saved a [Em]wretch like [D]me

        [Chorus]
        [G]I once was [C]lost, but [G]now am found
        Was [Em]blind but [D]now I [G]see
        """

        let song = parser.parse(input)
        #expect(song.sections.count == 3)

        #expect(song.sections[0].header == "Intro")
        #expect(song.sections[1].header == "Verse 1")
        #expect(song.sections[2].header == "Chorus")
    }

    @Test func introSectionContainsBars() {
        let input = """
        [Intro]
        | G | C | G | D |
        """
        let song = parser.parse(input)
        #expect(song.sections[0].bars.count == 4)
        #expect(song.sections[0].bars[0].chords.map(\.text) == ["G"])
    }

    @Test func verseSectionContainsChordLyricBars() {
        let input = """
        [Verse 1]
        [G]Amazing [C]grace
        """
        let song = parser.parse(input)
        #expect(song.sections[0].bars.count == 2)
        #expect(song.sections[0].bars[0].chords.map(\.text) == ["G"])
        #expect(song.sections[0].bars[0].lyrics == "Amazing")
    }

    @Test func linesBeforeAnySectionGetImplicitSection() {
        let input = """
        Just a line
        Another line
        [Verse 1]
        [G]Hello
        """
        let song = parser.parse(input)
        #expect(song.sections.count == 2)
        #expect(song.sections[0].header == "")
        #expect(song.sections[0].bars.count == 2)
        #expect(song.sections[1].header == "Verse 1")
    }

    @Test func emptyInputProducesNoSections() {
        let song = parser.parse("")
        #expect(song.sections.isEmpty)
    }

    // MARK: - Chord Quality Validation

    @Test func validatesCommonQualities() {
        #expect(Chord.isValidQuality("") == true)
        #expect(Chord.isValidQuality("m") == true)
        #expect(Chord.isValidQuality("7") == true)
        #expect(Chord.isValidQuality("m7") == true)
        #expect(Chord.isValidQuality("maj7") == true)
        #expect(Chord.isValidQuality("dim") == true)
        #expect(Chord.isValidQuality("sus4") == true)
        #expect(Chord.isValidQuality("sus2") == true)
        #expect(Chord.isValidQuality("7sus2") == true)
        #expect(Chord.isValidQuality("add9") == true)
        #expect(Chord.isValidQuality("m7b5") == true)
        #expect(Chord.isValidQuality("7#9") == true)
        #expect(Chord.isValidQuality("aug") == true)
        #expect(Chord.isValidQuality("/G") == true)
        #expect(Chord.isValidQuality("m/E") == true)
    }

    @Test func rejectsEnglishWordsAsQualities() {
        #expect(Chord.isValidQuality("urns") == false)
        #expect(Chord.isValidQuality("alling") == false)
        #expect(Chord.isValidQuality("fter") == false)
        #expect(Chord.isValidQuality("nd") == false)
        #expect(Chord.isValidQuality("one") == false)
        #expect(Chord.isValidQuality("right") == false)
    }

    // MARK: - Tab Line Detection

    @Test func detectsTabLines() {
        #expect(parser.isTabLine("e|-------7--10--7----|----") == true)
        #expect(parser.isTabLine("B|--7h10------------|----") == true)
        #expect(parser.isTabLine("G|---------------------|----") == true)
        #expect(parser.isTabLine("D|---------------------|----") == true)
        #expect(parser.isTabLine("A|---------------------|----") == true)
        #expect(parser.isTabLine("E|---------------------|----") == true)
    }

    @Test func doesNotMisclassifyAsTab() {
        #expect(parser.isTabLine("| B A | C D |") == false)
        #expect(parser.isTabLine("B   A   B") == false)
        #expect(parser.isTabLine("Watching her") == false)
    }

    // MARK: - Chord Line Detection

    @Test func detectsChordLines() {
        #expect(parser.isChordLine("B   A     B") == true)
        #expect(parser.isChordLine("A          E") == true)
        #expect(parser.isChordLine("F#             B") == true)
        #expect(parser.isChordLine("E          D    E        D") == true)
        #expect(parser.isChordLine("(B)") == true)
    }

    @Test func doesNotMisclassifyLyricsAsChords() {
        #expect(parser.isChordLine("Watching her") == false)
        #expect(parser.isChordLine("Strolling in the night") == false)
        #expect(parser.isChordLine("Burns bright") == false)
        #expect(parser.isChordLine("A distant fire light") == false)
        #expect(parser.isChordLine("Falling falling") == false)
        #expect(parser.isChordLine("Through the floor") == false)
        #expect(parser.isChordLine("After dark, after dark") == false)
    }

    @Test func parsesChordLineTokens() {
        let chords = parser.parseChordLine("F#     E        F#7")
        #expect(chords.map(\.text) == ["F#", "E", "F#7"])
    }

    @Test func parsesParenthesizedChordInChordLine() {
        let chords = parser.parseChordLine("(B)")
        #expect(chords.map(\.text) == ["B"])
    }

    // MARK: - Parenthesized Chords in Pipe Bars

    @Test func parsesParenthesizedChordsInPipeBars() {
        let bars = parser.parsePipeBars("|(B) A  | B  A  | B  A  |")
        #expect(bars.count == 3)
        #expect(bars[0].chords.map(\.text) == ["B", "A"])
        #expect(bars[1].chords.map(\.text) == ["B", "A"])
    }

    @Test func pipeBarIgnoresRepeatMarker() {
        let bars = parser.parsePipeBars("| B  A  | B  A  | x2")
        #expect(bars.count == 2)
        #expect(bars[0].chords.map(\.text) == ["B", "A"])
    }

    // MARK: - After Dark (Full Song)

    static let afterDark = """
    [Intro]
                                  (B)
    e|-------7--10--7------------|----
    B|--7h10-----------10--------|----
    G|---------------------9--7b-|----
    D|---------------------------|-9--
    A|---------------------------|----
    E|---------------------------|----

    | B  A  | B  A  | B  A  | B  A  | x2
    | B  A  | B  A  | B  A  |

    [Verse 1]
    B   A     B
    Watching her
    A         B            A
    Strolling in the night
       B
    So white
    A          E
    Wondering,   why
     F#             B
    It's only after dark

    [Interlude]
    |(B) A  | B  A  | B  A  | B  A  |

    [Verse 2]
    B   A     B
    In    her eyes
      A       B          A
    A distant fire light
          B
    Burns bright
    A          E
    Wondering,   why
     F#             B
    It's only after dark

    [Interlude]
    |(B) A  | B  A  | B  A  | B  A  |

    [Bridge 1]
    E          D    E        D
      I find myself   in her room
    E          D     E       D
      Feel the fever   of my doom
    F#     E        F#
       Falling falling
                    E
    Through the floor
    F#              E      F#       E      B
       I'm knocking on the Devil's door, yeah

    [Instrumental]
    |(B) A  | B  A  | B  A  | B  A  |

    [Verse 3]
    B   A     B
    In    the dawn
    A         B       A
    I wake up to find
        B    A
    Her gone
          E        F#7
    And a note says
              B     A  B  A
    Only after dark

    [Instrumental]
    | B  A  | B  A  | B  A  | B  A  | x4
    | E     | F#    |
    | B  A  | B  A  | B  A  | B  A  |
    | B  A  | B  A  | B  A  | B  A  | x4
    | E     | F#    |
    | B  A  | B  A  | B  A  | B  A  |

    [Bridge 2]
    E         D       E        D
      Burning burning   in the flame
    E       D        E        D
      Now I know her   secret name
    F#         E        F#      E
       You can tear her temple down
    F#               E
       But she'll be back
       F#                B  A  B  A
    And rule again, yeah!

    [Verse 4]
    B   A    B
    In    my heart
      A             B
    A deep and dark and
     A      B
    lonely part
    A       E
     Wants her, and
    F#              B
    Waits for after dark

    [Outro]
          C#          E
    After dark, after dark
         F#     B  A  B  A  B  A  B  A  B7sus2
    After   daaaaaaaaaaaaaaaaaaaaaaaaaaaaaark
    """

    @Test func afterDarkHasCorrectSections() {
        let song = parser.parse(Self.afterDark)
        let headers = song.sections.map(\.header)
        #expect(headers == [
            "Intro", "Verse 1", "Interlude", "Verse 2", "Interlude",
            "Bridge 1", "Instrumental", "Verse 3", "Instrumental",
            "Bridge 2", "Verse 4", "Outro"
        ])
    }

    @Test func afterDarkIntroBarCount() {
        let song = parser.parse(Self.afterDark)
        let intro = song.sections[0]
        #expect(intro.bars.count == 8)
    }

    @Test func afterDarkIntroFirstBarIsParenthesizedChord() {
        let song = parser.parse(Self.afterDark)
        let intro = song.sections[0]
        #expect(intro.bars[0].chords.map(\.text) == ["B"])
    }

    @Test func afterDarkVerse1Chords() {
        let song = parser.parse(Self.afterDark)
        let verse = song.sections[1]
        let allChords = verse.bars.flatMap(\.chords)
        #expect(allChords.map(\.text) == ["B", "A", "B", "A", "B", "A", "B", "A", "E", "F#", "B"])
    }

    @Test func afterDarkVerse1Lyrics() {
        let song = parser.parse(Self.afterDark)
        let verse = song.sections[1]
        let lyricsInBars = verse.bars.map(\.lyrics)
        #expect(lyricsInBars == [
            "Watching", "her", "",
            "Strolling", "in the night", "",
            "So white",
            "Wondering,", "why",
            "It's only after", "dark"
        ])
    }

    @Test func afterDarkInterludeHasParenthesizedBarChords() {
        let song = parser.parse(Self.afterDark)
        let interlude = song.sections[2]
        #expect(interlude.bars.count == 4)
        #expect(interlude.bars[0].chords.map(\.text) == ["B", "A"])
    }

    @Test func afterDarkBridgeEndsWith5Chords() {
        let song = parser.parse(Self.afterDark)
        let bridge = song.sections[5]
        let chordBars = bridge.bars.filter { !$0.chords.isEmpty }
        let lastFiveChords = chordBars.suffix(5).flatMap(\.chords).map(\.text)
        #expect(lastFiveChords == ["F#", "E", "F#", "E", "B"])
    }

    @Test func afterDarkVerse3HasF7sharp() {
        let song = parser.parse(Self.afterDark)
        let verse3 = song.sections[7]
        let allChords = verse3.bars.flatMap(\.chords)
        let f7sharp = allChords.first { $0.text == "F#7" }
        #expect(f7sharp != nil)
        #expect(f7sharp?.root == "F#")
        #expect(f7sharp?.quality == "7")
    }

    @Test func afterDarkOutroHasB7sus2() {
        let song = parser.parse(Self.afterDark)
        let outro = song.sections[11]
        let allChords = outro.bars.flatMap(\.chords)
        let b7sus2 = allChords.first { $0.text == "B7sus2" }
        #expect(b7sus2 != nil)
        #expect(b7sus2?.root == "B")
        #expect(b7sus2?.quality == "7sus2")
    }

    @Test func afterDarkInstrumentalHasSingleChordEBars() {
        let song = parser.parse(Self.afterDark)
        let instrumental = song.sections[8]
        let eBars = instrumental.bars.filter { $0.chords.count == 1 && $0.chords[0].text == "E" }
        #expect(!eBars.isEmpty)
    }

    // MARK: - Pure Chord Chart

    static let chordChart = """
    [Intro]
    Am D Am D


    [Verse 1]
    Am D Am D
    Am Dm G Dm
    Am D Am


    [Chorus]
    F Am F Am


    [Bridge]
    F G C Am F
    G C F G
    C Am


    [Chorus]
    F Am F Am


    [Verse 2]
    Am D Am D
    Am Dm G Dm
    Am D Am


    [Bridge]
    F G C Am F
    G C F G
    C Am


    [Chorus]
    F Am F Am


    [Outro]
    Am D Am D
    Am D Am D
    Am D Am D
    """

    @Test func chordChartHasCorrectSections() {
        let song = parser.parse(Self.chordChart)
        let headers = song.sections.map(\.header)
        #expect(headers == [
            "Intro", "Verse 1", "Chorus", "Bridge",
            "Chorus", "Verse 2", "Bridge", "Chorus", "Outro"
        ])
    }

    @Test func chordChartAllBarsHaveChords() {
        let song = parser.parse(Self.chordChart)
        for section in song.sections {
            for bar in section.bars {
                #expect(!bar.chords.isEmpty, "Expected chords in bar of section '\(section.header)'")
            }
        }
    }

    @Test func chordChartIntroProgression() {
        let song = parser.parse(Self.chordChart)
        let intro = song.sections[0]
        let allChords = intro.bars.flatMap(\.chords)
        #expect(allChords.map(\.text) == ["Am", "D", "Am", "D"])
    }

    @Test func chordChartVerse1Progressions() {
        let song = parser.parse(Self.chordChart)
        let verse = song.sections[1]
        let allChords = verse.bars.flatMap(\.chords)
        #expect(allChords.map(\.text) == [
            "Am", "D", "Am", "D",
            "Am", "Dm", "G", "Dm",
            "Am", "D", "Am"
        ])
    }

    @Test func chordChartBridgeProgressions() {
        let song = parser.parse(Self.chordChart)
        let bridge = song.sections[3]
        let allChords = bridge.bars.flatMap(\.chords)
        #expect(allChords.map(\.text) == [
            "F", "G", "C", "Am", "F",
            "G", "C", "F", "G",
            "C", "Am"
        ])
    }

    @Test func chordChartRepeatedSectionsMatch() {
        let song = parser.parse(Self.chordChart)
        let choruses = song.sections.filter { $0.header == "Chorus" }
        #expect(choruses.count == 3)
        #expect(choruses[0] == choruses[1])
        #expect(choruses[1] == choruses[2])
    }

    @Test func chordChartOutroHasThreeRepetitions() {
        let song = parser.parse(Self.chordChart)
        let outro = song.sections[8]
        #expect(outro.bars.count == 12)
        let pattern = outro.bars.prefix(4).flatMap(\.chords).map(\.text)
        #expect(pattern == ["Am", "D", "Am", "D"])
    }

    @Test func chordChartMinorChordsParseCorrectly() {
        let song = parser.parse(Self.chordChart)
        let allChords = song.sections.flatMap(\.bars).flatMap(\.chords)
        let dm = allChords.first { $0.text == "Dm" }
        #expect(dm?.root == "D")
        #expect(dm?.quality == "m")
        let am = allChords.first { $0.text == "Am" }
        #expect(am?.root == "A")
        #expect(am?.quality == "m")
    }
    
    static let batmanChart = """
    [Intro]
    | G | G | G | G | C | C | G | G | D | C | G | D

    [Bat Verse]
    G G G G C C G G D C G D

    [Bat Chorus]
    G G G G C C G G D C G D

    [Bat Verse]
    G G G G C C G G D C G D

    [Bat Chorus]
    G G G G C C G G D C G D

    [Wipe Verse]
    G G G G C C G G D C G D

    [Wipe Solo]
    G G G G C C G G D C G D

    [Wipe Chorus]
    G G G G C C G G D C G D

    [Bat Verse]
    G G G G C C G G D C G D

    [Bat Chorus]
    G G G G C C G G D C G D

    [Bat Chorus]
    G G G G C C G G D C G D
    """

    @Test func batmanChartHasCorrectSections() {
        let song = parser.parse(Self.batmanChart)
        let headers = song.sections.map(\.header)
        #expect(headers == [
            "Intro", "Bat Verse", "Bat Chorus", "Bat Verse",
            "Bat Chorus", "Wipe Verse", "Wipe Solo", "Wipe Chorus", "Bat Verse",
            "Bat Chorus", "Bat Chorus"
        ])
    }

    // MARK: - Pipe Chord + Lyrics Merging

    @Test func mergesPipeChordWithPipeLyrics() {
        let input = """
        [Verse 1]
        | G     | C     | Am    | D     |
        | Hello | World | How   | Now   |
        """
        let song = parser.parse(input)
        let verse = song.sections[0]
        #expect(verse.bars.count == 4)
        #expect(verse.bars[0].chords.map(\.text) == ["G"])
        #expect(verse.bars[0].lyrics == "Hello")
        #expect(verse.bars[1].chords.map(\.text) == ["C"])
        #expect(verse.bars[1].lyrics == "World")
        #expect(verse.bars[2].chords.map(\.text) == ["Am"])
        #expect(verse.bars[2].lyrics == "How")
        #expect(verse.bars[3].chords.map(\.text) == ["D"])
        #expect(verse.bars[3].lyrics == "Now")
    }

    @Test func mergesPipeChordWithMultiWordPipeLyrics() {
        let input = """
        [Verse 1]
        | G C   | Am D     |
        | Hello | Big World |
        """
        let song = parser.parse(input)
        let verse = song.sections[0]
        #expect(verse.bars.count == 2)
        #expect(verse.bars[0].chords.map(\.text) == ["G", "C"])
        #expect(verse.bars[0].lyrics == "Hello")
        #expect(verse.bars[1].chords.map(\.text) == ["Am", "D"])
        #expect(verse.bars[1].lyrics == "Big World")
    }

    @Test func mergesPipeChordWithPlainLyrics() {
        let input = """
        [Verse 1]
        | G C | Am D |
        Hello world
        """
        let song = parser.parse(input)
        let verse = song.sections[0]
        #expect(verse.bars.count == 2)
        #expect(verse.bars[0].chords.map(\.text) == ["G", "C"])
        #expect(verse.bars[0].lyrics == "Hello world")
        #expect(verse.bars[1].chords.map(\.text) == ["Am", "D"])
        #expect(verse.bars[1].lyrics == "")
    }

    @Test func pipeChordWithoutLyricsStillWorks() {
        let input = """
        [Intro]
        | G | C | Am | D |
        | G | C | Am | D |
        """
        let song = parser.parse(input)
        let intro = song.sections[0]
        #expect(intro.bars.count == 8)
        #expect(intro.bars.allSatisfy { $0.lyrics.isEmpty })
    }

    @Test func pipeChordWithRepeatMarkerAndLyrics() {
        let input = """
        [Verse 1]
        | B A | B A | x2
        Watching her
        """
        let song = parser.parse(input)
        let verse = song.sections[0]
        #expect(verse.bars.count == 2)
        #expect(verse.bars[0].chords.map(\.text) == ["B", "A"])
        #expect(verse.bars[0].lyrics == "Watching her")
        #expect(verse.bars[1].chords.map(\.text) == ["B", "A"])
        #expect(verse.bars[1].lyrics == "")
    }

}
