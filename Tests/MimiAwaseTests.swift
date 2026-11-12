import Foundation
import Testing
@testable import MimiAwase

struct StageTests {
    @Test func everyModeHasFifteenStagesAndSixtyInAll() {
        for mode in Mode.allCases { #expect(Stage.all(mode).count == 15) }
        #expect(Stage.allStages.count == 60)
    }

    @Test func chordAndIntervalHaveThreeFreeStages() {
        #expect(Stage.all(.chord).filter(\.isFree).count == 3)
        #expect(Stage.all(.interval).filter(\.isFree).count == 3)
        #expect(Stage.all(.unison).allSatisfy(\.isFree))
        #expect(Stage.all(.octave).allSatisfy(\.isFree))
    }

    @Test func firstBoardIsFourCards() {
        #expect(Stage(mode: .unison, number: 1).pairs == 2)
    }

    @Test func nextGoesToTheNextModeAtTheEnd() {
        #expect(Stage(mode: .unison, number: 15).next == Stage(mode: .octave, number: 1))
        #expect(Stage(mode: .interval, number: 15).next == nil)
    }
}

struct BoardMakerTests {
    @Test(arguments: Stage.allStages)
    func everyStageMakesTheRightNumberOfDistinctPairs(stage: Stage) {
        let cards = BoardMaker.make(stage.spec, seed: 42)
        #expect(cards.count == stage.pairs * 2)
        let groups = Dictionary(grouping: cards, by: \.concept)
        #expect(groups.count == stage.pairs)
        #expect(groups.values.allSatisfy { $0.count == 2 })
        #expect(Set(cards.map(\.id)) == Set(0..<cards.count))
    }

    @Test(arguments: Stage.all(.unison))
    func unisonNotesKeepTheGapAndRange(stage: Stage) {
        let notes = BoardMaker.make(stage.spec, seed: 9).compactMap { card -> Int? in
            if case .pitch(let m) = card.concept { return m }
            return nil
        }
        let sorted = Array(Set(notes)).sorted()
        #expect(sorted.first! >= BoardMaker.low && sorted.last! <= BoardMaker.high)
        for (a, b) in zip(sorted, sorted.dropFirst()) { #expect(b - a >= min(stage.gap, 1)) }
    }

    @Test func octavePairsAreOneOctaveApart() {
        let cards = BoardMaker.make(Stage(mode: .octave, number: 10).spec, seed: 3)
        for group in Dictionary(grouping: cards, by: \.concept).values {
            let notes = group.flatMap(\.sound.midiNotes).sorted()
            #expect(notes[1] - notes[0] == 12)
        }
    }

    @Test func intervalPairsShareTheWidthButNotTheStart() {
        let cards = BoardMaker.make(Stage(mode: .interval, number: 15).spec, seed: 5)
        for group in Dictionary(grouping: cards, by: \.concept).values {
            guard case let .interval(s1, w1) = group[0].sound, case let .interval(s2, w2) = group[1].sound else {
                Issue.record("音程ではない"); continue
            }
            #expect(w1 == w2)
            #expect(s1 + w1 <= BoardMaker.high && s2 + w2 <= BoardMaker.high)
            #expect(s1 != s2)
        }
    }

    @Test func sameSeedSameBoard() {
        let spec = Stage(mode: .chord, number: 12).spec
        #expect(BoardMaker.make(spec, seed: 77) == BoardMaker.make(spec, seed: 77))
    }

    @Test func dailyBoardIsTheSameAllDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let morning = Date(timeIntervalSince1970: 1_793_934_000) // 03:00 UTC
        let night = morning.addingTimeInterval(3600 * 5)
        #expect(SeededRandom.seed(for: morning, calendar: calendar) == SeededRandom.seed(for: night, calendar: calendar))
        #expect(BoardSpec.daily(for: morning, calendar: calendar).pairs == 6)
    }

    @Test func weaknessWeightsPullConfusedNotesIn() {
        let spec = Stage(mode: .unison, number: 5).spec
        let weights: [Concept: Double] = [.pitch(64): 10, .pitch(65): 10]
        var withWeak = 0, without = 0
        for seed in 0..<40 as Range<UInt64> {
            let a = Set(BoardMaker.make(spec, seed: seed, weights: weights).map(\.concept))
            let b = Set(BoardMaker.make(spec, seed: seed).map(\.concept))
            withWeak += [Concept.pitch(64), .pitch(65)].filter(a.contains).count
            without += [Concept.pitch(64), .pitch(65)].filter(b.contains).count
        }
        #expect(withWeak > without)
    }
}

struct GameTests {
    /// 0,1 = ド、2,3 = ミ
    func twoPairs() -> Game {
        Game(cards: [
            Card(id: 0, concept: .pitch(60), sound: .note(60)),
            Card(id: 1, concept: .pitch(60), sound: .note(60)),
            Card(id: 2, concept: .pitch(64), sound: .note(64)),
            Card(id: 3, concept: .pitch(64), sound: .note(64)),
        ])
    }

    @Test func luckyMatchIsNotCountedAsHearing() {
        var game = twoPairs()
        #expect(game.flip(0) == .first)
        #expect(game.flip(1) == .match(combo: 1))
        #expect(game.hits == 0 && game.misses == 0)
        #expect(game.accuracy == nil)
    }

    @Test func rememberedMatchIsAHit() {
        var game = twoPairs()
        _ = game.flip(0)
        #expect(game.flip(2) == .miss(remembered: false))   // はじめて聞く 2 枚：責めない
        #expect(game.flip(1) == .first)                      // 外れた 2 枚は自動で伏せる
        #expect(game.flip(0) == .match(combo: 1))            // 覚えていたドを当てた
        #expect(game.hits == 1)
        #expect(game.flip(3) == .first)
        #expect(game.flip(2) == .match(combo: 2))
        #expect(game.isFinished)
        #expect(game.moves == 3)
        #expect(game.stars == 3)
        #expect(game.accuracy == 1)
    }

    @Test func missWithAKnownCardIsRecordedAsConfusion() {
        var game = twoPairs()
        _ = game.flip(0); _ = game.flip(2)       // ド・ミを聞いた
        _ = game.flip(1)                          // ドの相方
        #expect(game.flip(2) == .miss(remembered: true))  // 聞いたミを「同じ」と選んだ
        #expect(game.misses == 1)
        #expect(game.confusions == [Confusion(.pitch(60), .pitch(64))])
        #expect(game.combo == 0)
    }

    @Test func flippingTheSameOrAMatchedCardIsIgnored() {
        var game = twoPairs()
        _ = game.flip(0)
        #expect(game.flip(0) == .ignored)
        _ = game.flip(1)
        #expect(game.flip(1) == .ignored)
        #expect(game.moves == 1)
    }

    @Test func starsFollowThePar() {
        #expect(Game.par(pairs: 6) == (three: 10, two: 14))
    }

    @Test func confusionOrderDoesNotMatter() {
        #expect(Confusion(.pitch(65), .pitch(64)) == Confusion(.pitch(64), .pitch(65)))
    }
}

struct ProgressTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let day = Date(timeIntervalSince1970: 1_793_934_000)

    func result(_ kind: BoardKind, stars: Int = 3, confusions: [Confusion] = []) -> BoardResult {
        BoardResult(kind: kind, mode: .unison, pairs: 6, moves: 9, stars: stars, hits: 4, misses: 1, confusions: confusions)
    }

    @Test func clearingAStageOpensTheNext() {
        var p = Progress()
        let first = Stage(mode: .unison, number: 1)
        let second = Stage(mode: .unison, number: 2)
        #expect(p.isOpen(first) && !p.isOpen(second))
        p.record(result(.stage(first.id)), on: day, calendar: calendar)
        #expect(p.isOpen(second))
        #expect(p.nextStage(in: .unison) == second)
    }

    @Test func bestStarsAreKept() {
        var p = Progress()
        let id = Stage(mode: .octave, number: 1).id
        p.record(result(.stage(id), stars: 3), on: day, calendar: calendar)
        p.record(result(.stage(id), stars: 1), on: day, calendar: calendar)
        #expect(p.stars[id] == 3)
    }

    @Test func streakCountsDailyBoardsAndForgivesToday() {
        var p = Progress()
        for back in 1...3 {
            p.record(result(.daily), on: calendar.date(byAdding: .day, value: -back, to: day)!, calendar: calendar)
        }
        #expect(p.streak(on: day, calendar: calendar) == 3)      // 今日はまだ：昨日までの 3 日
        p.record(result(.daily), on: day, calendar: calendar)
        #expect(p.streak(on: day, calendar: calendar) == 4)
        let later = calendar.date(byAdding: .day, value: 3, to: day)!
        #expect(p.streak(on: later, calendar: calendar) == 0)     // 途切れた
        #expect(p.playedDays == 4)                                // 合計は減らない
    }

    @Test func confusionsBecomeWeights() {
        var p = Progress()
        let c = Confusion(.pitch(64), .pitch(65))
        p.record(result(.daily, confusions: [c, c]), on: day, calendar: calendar)
        #expect(p.topConfusions(1).first?.1 == 2)
        #expect(p.weights(for: .unison)[.pitch(64)] == 2)
        #expect(p.weakestFocus()?.0 == .unison)
    }

    @Test func progressSurvivesSaving() throws {
        var p = Progress()
        p.record(result(.stage("unison-1"), confusions: [Confusion(.chord(root: 60, quality: .major), .chord(root: 60, quality: .minor))]), on: day, calendar: calendar)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == p)
    }

    @Test func weeksEndToday() {
        var p = Progress()
        p.record(result(.daily), on: day, calendar: calendar)
        let weeks = p.weeks(12, endingAt: day, calendar: calendar)
        #expect(weeks.count == 12)
        #expect(weeks.last?.compactMap { $0 }.contains(1) == true)
    }
}

struct SoundTests {
    @Test func namesFollowTheNotation() {
        #expect(MusicNames.name(midi: 60, notation: .letters, japanese: true) == "C4")
        #expect(MusicNames.name(midi: 64, notation: .solfege, japanese: true) == "ミ")
        #expect(MusicNames.name(midi: 64, notation: .solfege, japanese: false) == "Mi")
        #expect(MusicNames.label(.chord(root: 62, quality: .minor), notation: .letters, japanese: false) == "Dm")
        #expect(MusicNames.label(.interval(7), notation: .letters, japanese: false) == "P5")
    }

    @Test func chordInversionRaisesTheRoot() {
        #expect(SoundItem.chord(root: 60, quality: .major, inversion: 0).midiNotes == [60, 64, 67])
        #expect(SoundItem.chord(root: 60, quality: .major, inversion: 1).midiNotes == [64, 67, 72])
    }

    @Test func a440() {
        #expect(abs(MusicNames.frequency(midi: 69) - 440) < 0.001)
        #expect(abs(MusicNames.frequency(midi: 81) - 880) < 0.001)
    }

    @Test(arguments: Timbre.allCases)
    func renderedToneStaysInRange(timbre: Timbre) {
        let samples = ToneRenderer.render(.chord(root: 60, quality: .major7, inversion: 0), timbre: timbre)
        #expect(samples.count == Int(ToneRenderer.duration(of: .chord(root: 60, quality: .major7, inversion: 0)) * ToneRenderer.sampleRate))
        let peak = samples.map(abs).max() ?? 0
        #expect(peak > 0.05 && peak <= 0.91)
        #expect(abs(samples.last ?? 1) < 0.01)   // 終わりはぷつっと切れない
    }

    @Test func intervalPlaysTheSecondNoteLater() {
        let samples = ToneRenderer.render(.interval(start: 60, semitones: 7), timbre: .piano)
        let firstPart = samples.prefix(Int(0.05 * ToneRenderer.sampleRate)).map(abs).max() ?? 0
        #expect(firstPart > 0)
        #expect(ToneRenderer.duration(of: .interval(start: 60, semitones: 7)) > ToneRenderer.duration(of: .note(60)))
    }
}
