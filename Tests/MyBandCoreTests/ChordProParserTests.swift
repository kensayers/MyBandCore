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

    // MARK: - Line Parsing

    @Test func parsesEmptyLine() {
        #expect(parser.parseLine("") == .empty)
    }

    @Test func parsesPlainLyricLine() {
        #expect(parser.parseLine("Just a plain line") == .lyrics("Just a plain line"))
    }

    @Test func detectsBarLine() {
        if case .bars(let bars) = parser.parseLine("| G | C |") {
            #expect(bars.count == 2)
        } else {
            Issue.record("Expected bars line")
        }
    }

    @Test func detectsBarLineMultipleChordsInABar() {
        if case .bars(let bars) = parser.parseLine("| G C | G C |") {
            #expect(bars.count == 2)
        } else {
            Issue.record("Expected bars line")
        }
    }

    @Test func detectsBarInLinesWithNoBars() {
        if case .bars(let bars) = parser.parseLine("G C G C") {
            #expect(bars.count == 4)
        } else {
            Issue.record("Expected bars line")
        }
    }

    @Test func detectsChordLyricLine() {
        if case .chordLyric(let fragments) = parser.parseLine("[G]Hello") {
            #expect(fragments.count == 1)
        } else {
            Issue.record("Expected chord-lyric line")
        }
    }

    // MARK: - Chord-Lyric Parsing

    @Test func parsesChordLyricLine() {
        let fragments = parser.parseChordLyric("[G]Amazing [C]grace")
        #expect(fragments.count == 2)
        #expect(fragments[0].chord?.text == "G")
        #expect(fragments[0].text == "Amazing ")
        #expect(fragments[1].chord?.text == "C")
        #expect(fragments[1].text == "grace")
    }

    @Test func parsesChordLyricWithLeadingText() {
        let fragments = parser.parseChordLyric("That [G]saved a [Em]wretch")
        #expect(fragments.count == 3)
        #expect(fragments[0].chord == nil)
        #expect(fragments[0].text == "That ")
        #expect(fragments[1].chord?.text == "G")
        #expect(fragments[1].text == "saved a ")
        #expect(fragments[2].chord?.text == "Em")
        #expect(fragments[2].text == "wretch")
    }

    @Test func parsesChordOnlyLine() {
        let fragments = parser.parseChordLyric("[G]  [C]  [D]")
        #expect(fragments.count == 3)
        #expect(fragments[0].chord?.text == "G")
        #expect(fragments[0].text == "  ")
        #expect(fragments[1].chord?.text == "C")
        #expect(fragments[1].text == "  ")
        #expect(fragments[2].chord?.text == "D")
        #expect(fragments[2].text == "")
    }

    @Test func handlesUnclosedBracket() {
        let fragments = parser.parseChordLyric("[G]Hello [broken")
        #expect(fragments.count == 1)
        #expect(fragments[0].chord?.text == "G")
        #expect(fragments[0].text == "Hello [broken")
    }

    // MARK: - Bar Parsing

    @Test func parsesSimpleBarLine() {
        let bars = parser.parseBars("| G | Am | C | D |")
        #expect(bars.count == 4)
        #expect(bars[0].chords.map(\.text) == ["G"])
        #expect(bars[1].chords.map(\.text) == ["Am"])
        #expect(bars[2].chords.map(\.text) == ["C"])
        #expect(bars[3].chords.map(\.text) == ["D"])
    }

    @Test func parsesMultipleChordsPerBar() {
        let bars = parser.parseBars("| G C | Am D |")
        #expect(bars.count == 2)
        #expect(bars[0].chords.map(\.text) == ["G", "C"])
        #expect(bars[1].chords.map(\.text) == ["Am", "D"])
    }

    @Test func parsesBarLineWithoutLeadingBar() {
        let bars = parser.parseBars("G | Am | C | D")
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

    @Test func introSectionContainsBarLine() {
        let input = """
        [Intro]
        | G | C | G | D |
        """
        let song = parser.parse(input)
        let introLines = song.sections[0].lines
        if case .bars(let bars) = introLines[0] {
            #expect(bars.count == 4)
        } else {
            Issue.record("Expected bar line in intro")
        }
    }

    @Test func verseSectionContainsChordLyrics() {
        let input = """
        [Verse 1]
        [G]Amazing [C]grace
        """
        let song = parser.parse(input)
        let verseLines = song.sections[0].lines
        if case .chordLyric(let fragments) = verseLines[0] {
            #expect(fragments[0].chord?.text == "G")
            #expect(fragments[0].text == "Amazing ")
        } else {
            Issue.record("Expected chord-lyric line in verse")
        }
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
        #expect(song.sections[0].lines.count == 2)
        #expect(song.sections[1].header == "Verse 1")
    }

    @Test func emptyInputProducesOneSection() {
        let song = parser.parse("")
        #expect(song.sections.count == 1)
        #expect(song.sections[0].lines == [.empty])
    }

    @Test func preservesEmptyLinesBetweenContent() {
        let input = """
        [Verse 1]
        [G]Line one

        [G]Line two
        """
        let song = parser.parse(input)
        let lines = song.sections[0].lines
        #expect(lines.count == 3)
        #expect(lines[1] == .empty)
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

    @Test func parsesTabLine() {
        let tab = parser.parseTabLine("e|-------7--10--7----|----")
        #expect(tab.string == "e")
        #expect(tab.content == "|-------7--10--7----|----")
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

    // MARK: - Parenthesized Chords in Bars

    @Test func parsesParenthesizedChordsInBars() {
        let bars = parser.parseBars("|(B) A  | B  A  | B  A  |")
        #expect(bars.count == 3)
        #expect(bars[0].chords.map(\.text) == ["B", "A"])
        #expect(bars[1].chords.map(\.text) == ["B", "A"])
    }

    @Test func barLineIgnoresRepeatMarker() {
        let bars = parser.parseBars("| B  A  | B  A  | x2")
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

    @Test func afterDarkIntroHasTabLines() {
        let song = parser.parse(Self.afterDark)
        let intro = song.sections[0]
        let tabLines = intro.lines.filter {
            if case .tab = $0 { return true }
            return false
        }
        #expect(tabLines.count == 6)
    }

    @Test func afterDarkIntroTabStrings() {
        let song = parser.parse(Self.afterDark)
        let intro = song.sections[0]
        let tabStrings = intro.lines.compactMap { line -> String? in
            if case .tab(let tab) = line { return tab.string }
            return nil
        }
        #expect(tabStrings == ["e", "B", "G", "D", "A", "E"])
    }

    @Test func afterDarkIntroHasBarLines() {
        let song = parser.parse(Self.afterDark)
        let intro = song.sections[0]
        let barLines = intro.lines.compactMap { line -> [Bar]? in
            if case .bars(let bars) = line { return bars }
            return nil
        }
        #expect(barLines.count == 3)
        #expect(barLines[0].count == 1)
        #expect(barLines[1].count == 4)
        #expect(barLines[2].count == 3)
    }

    @Test func afterDarkIntroHasParenthesizedChord() {
        let song = parser.parse(Self.afterDark)
        let intro = song.sections[0]
        let barLines = intro.lines.compactMap { line -> [Bar]? in
            if case .bars(let bars) = line { return bars }
            return nil
        }
        #expect(barLines[0].count == 1)
        #expect(barLines[0][0].chords.map(\.text) == ["B"])
    }

    @Test func afterDarkVerse1Structure() {
        let song = parser.parse(Self.afterDark)
        let verse = song.sections[1]
        let lineTypes = verse.lines.map { line -> String in
            switch line {
            case .bars: return "bars"
            case .lyrics: return "lyrics"
            case .empty: return "empty"
            case .tab: return "tab"
            case .chordLyric: return "chordLyric"
            }
        }
        #expect(lineTypes == [
            "bars", "lyrics",
            "bars", "lyrics",
            "bars", "lyrics",
            "bars", "lyrics",
            "bars", "lyrics",
            "empty"
        ])
    }

    @Test func afterDarkVerse1Chords() {
        let song = parser.parse(Self.afterDark)
        let verse = song.sections[1]
        let allChords = verse.lines.compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }
        #expect(allChords[0].map(\.text) == ["B", "A", "B"])
        #expect(allChords[1].map(\.text) == ["A", "B", "A"])
        #expect(allChords[2].map(\.text) == ["B"])
        #expect(allChords[3].map(\.text) == ["A", "E"])
        #expect(allChords[4].map(\.text) == ["F#", "B"])
    }

    @Test func afterDarkVerse1Lyrics() {
        let song = parser.parse(Self.afterDark)
        let verse = song.sections[1]
        let lyrics = verse.lines.compactMap { line -> String? in
            if case .lyrics(let text) = line { return text }
            return nil
        }
        #expect(lyrics == [
            "Watching her",
            "Strolling in the night",
            "So white",
            "Wondering,   why",
            "It's only after dark"
        ])
    }

    @Test func afterDarkInterludeHasParenthesizedBar() {
        let song = parser.parse(Self.afterDark)
        let interlude = song.sections[2]
        if case .bars(let bars) = interlude.lines[0] {
            #expect(bars.count == 4)
            #expect(bars[0].chords.map(\.text) == ["B", "A"])
        } else {
            Issue.record("Expected bar line in interlude")
        }
    }

    @Test func afterDarkBridgeHasFiveChordBar() {
        let song = parser.parse(Self.afterDark)
        let bridge = song.sections[5]
        let chordLines = bridge.lines.compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }
        #expect(chordLines.last?.map(\.text) == ["F#", "E", "F#", "E", "B"])
    }

    @Test func afterDarkVerse3HasF7sharp() {
        let song = parser.parse(Self.afterDark)
        let verse3 = song.sections[7]
        let allChords = verse3.lines.compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }.flatMap { $0 }
        let f7sharp = allChords.first { $0.text == "F#7" }
        #expect(f7sharp != nil)
        #expect(f7sharp?.root == "F#")
        #expect(f7sharp?.quality == "7")
    }

    @Test func afterDarkOutroHasB7sus2() {
        let song = parser.parse(Self.afterDark)
        let outro = song.sections[11]
        let allChords = outro.lines.compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }.flatMap { $0 }
        let b7sus2 = allChords.first { $0.text == "B7sus2" }
        #expect(b7sus2 != nil)
        #expect(b7sus2?.root == "B")
        #expect(b7sus2?.quality == "7sus2")
    }

    @Test func afterDarkInstrumentalHasSingleChordBars() {
        let song = parser.parse(Self.afterDark)
        let instrumental = song.sections[8]
        let barLines = instrumental.lines.compactMap { line -> [Bar]? in
            if case .bars(let bars) = line { return bars }
            return nil
        }
        let singleChordBars = barLines.first { bars in
            bars.contains { $0.chords.count == 1 && $0.chords[0].text == "E" }
        }
        #expect(singleChordBars != nil)
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

    @Test func chordChartAllContentLinesAreChords() {
        let song = parser.parse(Self.chordChart)
        for section in song.sections {
            for line in section.lines {
                switch line {
                case .bars, .empty: break
                default: Issue.record("Unexpected line type in section '\(section.header)': \(line)")
                }
            }
        }
    }

    @Test func chordChartIntroProgression() {
        let song = parser.parse(Self.chordChart)
        let intro = song.sections[0]
        let chordLines = intro.lines.compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }
        #expect(chordLines.count == 1)
        #expect(chordLines[0].map(\.text) == ["Am", "D", "Am", "D"])
    }

    @Test func chordChartVerse1Progressions() {
        let song = parser.parse(Self.chordChart)
        let verse = song.sections[1]
        let chordLines = verse.lines.compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }
        #expect(chordLines.count == 3)
        #expect(chordLines[0].map(\.text) == ["Am", "D", "Am", "D"])
        #expect(chordLines[1].map(\.text) == ["Am", "Dm", "G", "Dm"])
        #expect(chordLines[2].map(\.text) == ["Am", "D", "Am"])
    }

    @Test func chordChartBridgeHasFiveChordsOnOneLine() {
        let song = parser.parse(Self.chordChart)
        let bridge = song.sections[3]
        let chordLines = bridge.lines.compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }
        #expect(chordLines[0].map(\.text) == ["F", "G", "C", "Am", "F"])
        #expect(chordLines[1].map(\.text) == ["G", "C", "F", "G"])
        #expect(chordLines[2].map(\.text) == ["C", "Am"])
    }

    @Test func chordChartRepeatedSectionsMatch() {
        let song = parser.parse(Self.chordChart)
        let choruses = song.sections.filter { $0.header == "Chorus" }
        #expect(choruses.count == 3)
        let chorusChords = choruses.map { section in
            section.lines.compactMap { line -> [Chord]? in
                if case .bars(let bars) = line { return bars.flatMap(\.chords) }
                return nil
            }
        }
        #expect(chorusChords[0] == chorusChords[1])
        #expect(chorusChords[1] == chorusChords[2])
    }

    @Test func chordChartOutroHasThreeIdenticalLines() {
        let song = parser.parse(Self.chordChart)
        let outro = song.sections[8]
        let chordLines = outro.lines.compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }
        #expect(chordLines.count == 3)
        #expect(chordLines[0] == chordLines[1])
        #expect(chordLines[1] == chordLines[2])
        #expect(chordLines[0].map(\.text) == ["Am", "D", "Am", "D"])
    }

    @Test func chordChartMinorChordsParseCorrectly() {
        let song = parser.parse(Self.chordChart)
        let allChords = song.sections.flatMap(\.lines).compactMap { line -> [Chord]? in
            if case .bars(let bars) = line { return bars.flatMap(\.chords) }
            return nil
        }.flatMap { $0 }
        let dm = allChords.first { $0.text == "Dm" }
        #expect(dm?.root == "D")
        #expect(dm?.quality == "m")
        let am = allChords.first { $0.text == "Am" }
        #expect(am?.root == "A")
        #expect(am?.quality == "m")
    }
}
