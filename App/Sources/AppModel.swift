import Foundation
import Observation
import SwiftUI

/// 画面の言語（撮影で日本語を撮るときは forcedJapanese を立てる。CI のシミュレータは英語のため）
enum Lang {
    nonisolated(unsafe) static var forcedJapanese = false

    static var isJapanese: Bool {
        forcedJapanese || (Bundle.main.preferredLocalizations.first ?? "ja").hasPrefix("ja")
    }
}

enum PaywallReason: Hashable, Sendable {
    case stage, weakness, timbre, history, cleared, settings
}

enum ActiveSheet: Identifiable, Hashable {
    case record, settings, paywall(PaywallReason)

    var id: String {
        switch self {
        case .record: "record"
        case .settings: "settings"
        case .paywall: "paywall"
        }
    }
}

/// 遊んでいる 1 回の盤
struct Session: Identifiable {
    let id = UUID()
    let kind: BoardKind
    let mode: Mode
    var game: Game

    func title(japanese: Bool) -> String {
        switch kind {
        case .tutorial: return japanese ? "はじめての盤" : "First board"
        case .daily: return japanese ? "今日の盤 · \(mode.title(japanese: true))" : "Today · \(mode.title(japanese: false))"
        case .weakness: return japanese ? "聞き直しの盤" : "Review board"
        case .stage(let id):
            let number = Stage.find(id)?.number ?? 1
            return japanese ? "\(mode.title(japanese: true)) · \(number) 段" : "\(mode.title(japanese: false)) · Level \(number)"
        }
    }

    var stage: Stage? {
        if case .stage(let id) = kind { return Stage.find(id) }
        return nil
    }
}

@MainActor
@Observable
final class AppModel {
    // MARK: 状態
    var progress: Progress
    var session: Session?
    /// 終わった盤の結果（盤の上に出す）
    var result: BoardResult?
    var activeSheet: ActiveSheet?
    var onboarded: Bool
    /// ホームで選んでいるモード
    var selectedMode: Mode = .unison

    // 設定
    var notation: Notation { didSet { saveSettings() } }
    var timbre: Timbre { didSet { synth.timbre = timbre; saveSettings() } }
    var volume: Double { didSet { synth.volume = Float(volume); saveSettings() } }
    var hapticsOn: Bool { didSet { saveSettings() } }
    var showNames: Bool { didSet { saveSettings() } }
    var reminderOn: Bool { didSet { saveSettings() } }

    // 手応えのきっかけ（画面が見て、動き・振動を出す）
    private(set) var flipTick = 0
    private(set) var matchTick = 0
    private(set) var comboTick = 0
    private(set) var missTick = 0
    private(set) var finishTick = 0
    /// 最後にめくったカードと、その回数（波紋を出す）
    private(set) var ripple: (card: Int, tick: Int) = (-1, 0)
    /// ちがった 2 枚（揺らす）
    private(set) var shaking: Set<Int> = []
    private(set) var lastCombo = 0

    // MARK: 依存
    let purchases: PurchaseStore
    let synth = Synth()
    var proOverride = false
    var now: Date
    var calendar: Calendar
    let persists: Bool
    private let defaults: UserDefaults
    private var missToken = 0

    var isPro: Bool { proOverride || purchases.entitlements.isPro }
    var japanese: Bool { Lang.isJapanese }

    init(persists: Bool = true, now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        self.persists = persists
        self.now = now
        self.calendar = calendar
        self.defaults = defaults
        let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.005"
        purchases = PurchaseStore(productIDs: [ProductID.pro(bundleID: bundleID)],
                                  proProductIDs: [ProductID.pro(bundleID: bundleID)])
        if persists, let data = defaults.data(forKey: "progress.v1"), let saved = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = saved
        } else {
            progress = Progress()
        }
        let ja = Lang.isJapanese
        onboarded = persists ? defaults.bool(forKey: "onboarded") : true
        notation = Notation(rawValue: persists ? defaults.string(forKey: "notation") ?? "" : "") ?? (ja ? .solfege : .letters)
        timbre = Timbre(rawValue: persists ? defaults.string(forKey: "timbre") ?? "" : "") ?? .piano
        volume = persists && defaults.object(forKey: "volume") != nil ? defaults.double(forKey: "volume") : 0.55
        hapticsOn = persists && defaults.object(forKey: "haptics") != nil ? defaults.bool(forKey: "haptics") : true
        showNames = persists && defaults.object(forKey: "showNames") != nil ? defaults.bool(forKey: "showNames") : true
        reminderOn = persists ? defaults.bool(forKey: "reminder") : false
        synth.timbre = timbre
        synth.volume = Float(volume)
        selectedMode = .unison
    }

    // MARK: 盤を始める

    func startTutorial() {
        let spec = BoardSpec(mode: .unison, pairs: 2, gap: 7, crowding: 0)
        begin(.tutorial, mode: .unison, cards: BoardMaker.make(spec, seed: 7))
    }

    func start(_ stage: Stage) {
        guard progress.isOpen(stage) else { return }
        guard stage.isFree || isPro else {
            activeSheet = .paywall(.stage)
            return
        }
        let seed = UInt64(now.timeIntervalSince1970 * 1000) ^ UInt64(stage.number * 977)
        begin(.stage(stage.id), mode: stage.mode, cards: BoardMaker.make(stage.spec, seed: seed, weights: progress.weights(for: stage.mode)))
    }

    func startDaily() {
        let spec = BoardSpec.daily(for: now, calendar: calendar)
        let seed = SeededRandom.seed(for: now, calendar: calendar)
        begin(.daily, mode: spec.mode, cards: BoardMaker.make(spec, seed: seed))
    }

    var dailyMode: Mode { BoardSpec.daily(for: now, calendar: calendar).mode }

    /// 苦手を中心にした盤（Pro）
    func startWeakness() {
        guard isPro else {
            activeSheet = .paywall(.weakness)
            return
        }
        guard let weak = progress.weakestFocus() else { return }
        let seed = UInt64(now.timeIntervalSince1970)
        begin(.weakness, mode: weak.0, cards: BoardMaker.weakness(mode: weak.0, focus: weak.1, pairs: 6, seed: seed))
    }

    func begin(_ kind: BoardKind, mode: Mode, cards: [Card]) {
        result = nil
        shaking = []
        session = Session(kind: kind, mode: mode, game: Game(cards: cards))
        synth.prepare(cards.map(\.sound))
    }

    func closeBoard() {
        session = nil
        result = nil
        shaking = []
    }

    func replay() {
        guard let session else { return }
        switch session.kind {
        case .tutorial: startTutorial()
        case .daily: startDaily()
        case .weakness: startWeakness()
        case .stage(let id): if let stage = Stage.find(id) { start(stage) }
        }
    }

    /// 次の段階（無ければホームへ）
    func goNext() {
        guard let session else { return }
        switch session.kind {
        case .stage(let id):
            if let next = Stage.find(id)?.next {
                selectedMode = next.mode
                if next.isFree || isPro { start(next) } else { closeBoard(); activeSheet = .paywall(.stage) }
            } else {
                closeBoard()
            }
        case .tutorial:
            finishOnboarding()
        default:
            closeBoard()
        }
    }

    func finishOnboarding() {
        onboarded = true
        if persists { defaults.set(true, forKey: "onboarded") }
        closeBoard()
    }

    // MARK: めくる

    func flip(_ id: Int) {
        guard var current = session, result == nil else { return }
        let hadMiss = current.game.hasPendingMiss
        let outcome = current.game.flip(id)
        session = current
        if hadMiss { shaking = [] }
        guard outcome != .ignored, let card = current.game.card(id) else { return }
        synth.play(card.sound)
        ripple = (id, ripple.tick + 1)
        switch outcome {
        case .first:
            flipTick += 1
        case .match(let combo):
            lastCombo = combo
            if combo > 1 { comboTick += 1 } else { matchTick += 1 }
            let wait = ToneRenderer.duration(of: card.sound) * 0.55
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(Int(wait * 1000)))
                self?.synth.chime(level: combo)
            }
            if current.game.isFinished {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(Int(wait * 1000) + 500))
                    self?.finish()
                }
            }
        case .miss:
            missTick += 1
            missToken += 1
            let token = missToken
            let ids = Set(current.game.faceUp)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(Int(ToneRenderer.duration(of: card.sound) * 700)))
                guard let self, self.missToken == token else { return }
                self.shaking = ids
                try? await Task.sleep(for: .milliseconds(600))
                guard self.missToken == token, var s = self.session, s.game.hasPendingMiss else { return }
                s.game.hideMismatch()
                self.session = s
                self.shaking = []
            }
        case .ignored:
            break
        }
    }

    func finish() {
        guard let session, session.game.isFinished, result == nil else { return }
        let game = session.game
        let r = BoardResult(kind: session.kind, mode: session.mode, pairs: game.pairs, moves: game.moves,
                            stars: game.stars, hits: game.hits, misses: game.misses, confusions: game.confusions)
        result = r
        progress.record(r, on: now, calendar: calendar)
        save()
        finishTick += 1
        synth.arpeggio(game.foundOrder.map { Self.sound(for: $0) })
        offerPaywallIfValuable(after: session)
    }

    /// 無料の最後の段階を終えた直後だけ、1 日 1 回 Pro を案内する
    private func offerPaywallIfValuable(after session: Session) {
        guard !isPro, let stage = session.stage, let next = stage.next, !next.isFree, stage.mode == next.mode else { return }
        let today = Progress.dayKey(now, calendar: calendar)
        guard progress.lastPaywallDay != today else { return }
        progress.lastPaywallDay = today
        save()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1600))
            guard let self, self.activeSheet == nil else { return }
            self.activeSheet = .paywall(.cleared)
        }
    }

    // MARK: 聞き直し

    static func sound(for concept: Concept) -> SoundItem {
        switch concept {
        case .pitch(let m): .note(m)
        case .pitchClass(let p): .note(60 + p)
        case let .chord(root, quality): .chord(root: root, quality: quality, inversion: 0)
        case .interval(let s): .interval(start: 60, semitones: s)
        }
    }

    /// A → B の順に聞き比べる
    func compare(_ confusion: Confusion) {
        let a = Self.sound(for: confusion.a)
        let b = Self.sound(for: confusion.b)
        synth.play(a)
        let wait = ToneRenderer.duration(of: a) * 0.8
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(wait * 1000)))
            self?.synth.play(b)
        }
    }

    func listen(_ concept: Concept) {
        synth.play(Self.sound(for: concept))
    }

    func label(_ concept: Concept) -> String {
        MusicNames.label(concept, notation: notation, japanese: japanese)
    }

    func longLabel(_ concept: Concept) -> String {
        MusicNames.longLabel(concept, notation: notation, japanese: japanese)
    }

    func select() {
        flipTick += 1
    }

    // MARK: 設定

    func setReminder(_ on: Bool) async {
        if on {
            reminderOn = await Reminder.enable(japanese: japanese)
        } else {
            Reminder.disable()
            reminderOn = false
        }
    }

    func resetTutorial() {
        onboarded = false
        if persists { defaults.set(false, forKey: "onboarded") }
        activeSheet = nil
    }

    // MARK: 保存

    func save() {
        guard persists, let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: "progress.v1")
    }

    private func saveSettings() {
        guard persists else { return }
        defaults.set(notation.rawValue, forKey: "notation")
        defaults.set(timbre.rawValue, forKey: "timbre")
        defaults.set(volume, forKey: "volume")
        defaults.set(hapticsOn, forKey: "haptics")
        defaults.set(showNames, forKey: "showNames")
        defaults.set(reminderOn, forKey: "reminder")
    }

    // MARK: 見本（撮影・デモ）

    /// 2 週間ほど遊んだ記録を作る（保存しない）
    func seedHistory() {
        var p = Progress()
        p.tutorialDone = true
        for stage in Stage.all(.unison).prefix(9) { p.stars[stage.id] = stage.number % 4 == 0 ? 2 : 3 }
        for stage in Stage.all(.octave).prefix(5) { p.stars[stage.id] = 3 }
        p.stars[Stage(mode: .chord, number: 1).id] = 2
        for back in 0..<40 {
            guard back % 6 != 5, let day = calendar.date(byAdding: .day, value: -back, to: now) else { continue }
            let key = Progress.dayKey(day, calendar: calendar)
            p.days[key] = DayRecord(boards: 1 + (back * 7) % 4, pairs: 10 + back % 9, dailyDone: back < 12 || back % 3 == 0,
                                    dailyStars: 2 + back % 2, dailyMoves: 9 + back % 5)
        }
        p.days[Progress.dayKey(now, calendar: calendar)] = nil
        p.tallies = [.unison: Tally(hits: 86, misses: 14), .octave: Tally(hits: 41, misses: 13), .chord: Tally(hits: 9, misses: 6), .interval: Tally(hits: 4, misses: 4)]
        p.confusionCounts = [
            Confusion(.pitch(64), .pitch(65)): 6,
            Confusion(.pitch(71), .pitch(72)): 4,
            Confusion(.pitchClass(2), .pitchClass(4)): 3,
            Confusion(.chord(root: 62, quality: .major), .chord(root: 62, quality: .minor)): 3,
            Confusion(.interval(3), .interval(4)): 2,
        ]
        progress = p
    }
}
