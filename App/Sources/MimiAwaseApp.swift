import SwiftUI

@main
struct MimiAwaseApp: App {
    @State private var model = Launch.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    @State var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if model.session != nil {
                BoardView()
                    .transition(.opacity)
            } else if model.onboarded {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.session?.id)
        .animation(.easeOut(duration: 0.35), value: model.onboarded)
        .environment(model)
        // 淡い水色の地が世界観の中心。ダークでは波紋の色が沈むので、ライトに固定する
        .preferredColorScheme(.light)
        .modifier(JapaneseForScreenshots())
        .sheet(item: $model.activeSheet) { sheet in
            sheetView(sheet)
                .environment(model)
                .preferredColorScheme(.light)
                .modifier(JapaneseForScreenshots())
        }
        .sensoryFeedback(trigger: model.flipTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.matchTick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
        .sensoryFeedback(trigger: model.comboTick) { _, _ in model.hapticsOn ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: model.missTick) { _, _ in model.hapticsOn ? .impact(flexibility: .soft, intensity: 0.5) : nil }
        .sensoryFeedback(trigger: model.finishTick) { _, _ in model.hapticsOn ? .success : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && Launch.scene == nil && !Launch.isDemo { model.now = Date() }
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .record: RecordView()
        case .settings: SettingsView()
        case .paywall(let reason): PaywallView(reason: reason)
        }
    }
}

/// 撮影で日本語の画面を撮るとき（-screenshotScene <名前>_ja）、画面の文字と日付を日本語にする。
/// CI のシミュレータは英語のため（監督の指示 #21）
struct JapaneseForScreenshots: ViewModifier {
    @ViewBuilder
    func body(content: Self.Content) -> some View {
        if Launch.forcesJapanese {
            content.environment(\.locale, Locale(identifier: "ja_JP"))
        } else {
            content
        }
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない。
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（例：home_ja）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    /// 撮影中は動きを途中で止めて撮る
    static var isStill: Bool { scene != nil }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        guard isDemo || scene != nil else { return AppModel() }
        let model = AppModel(persists: false, now: Date())
        model.onboarded = scene != "onboarding"
        if scene != "empty" && scene != "onboarding" { model.seedHistory() }
        if scene == "pro" { model.proOverride = true }
        return model
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(300))
        switch scene {
        case "board":
            model.start(Stage(mode: .unison, number: 8))
            await Script.match(model, pairs: 3)
            await Script.missOnce(model)
        case "flip":
            model.startDaily()
            if let first = model.session?.game.cards.first { model.flip(first.id) }
        case "chord":
            model.proOverride = true
            model.selectedMode = .chord
            model.start(Stage(mode: .chord, number: 8))
            await Script.match(model, pairs: 3)
            if let card = model.session?.game.cards.first(where: { !(model.session?.game.matched.contains($0.id) ?? true) }) { model.flip(card.id) }
        case "interval":
            model.proOverride = true
            model.start(Stage(mode: .interval, number: 5))
            await Script.match(model, pairs: 2)
        case "result":
            model.start(Stage(mode: .unison, number: 6))
            await Script.missOnce(model, remembered: true)
            await Script.match(model, pairs: 99)
            model.finish()
        case "tutorial":
            model.onboarded = false
            model.startTutorial()
        case "record", "empty", "pro":
            model.activeSheet = .record
        case "settings":
            model.activeSheet = .settings
        case "paywall":
            model.activeSheet = .paywall(.cleared)
        case "chordhome":
            model.selectedMode = .chord
        default:
            break
        }
    }
}

/// 撮影とデモで、盤を決まった手順でめくる
@MainActor
enum Script {
    static func unmatched(_ model: AppModel) -> [Card] {
        guard let game = model.session?.game else { return [] }
        return game.cards.filter { !game.matched.contains($0.id) }
    }

    /// まだのペアを pairs 組そろえる
    static func match(_ model: AppModel, pairs: Int, pause: Double = 0) async {
        for _ in 0..<pairs {
            guard let game = model.session?.game, let a = unmatched(model).first, let b = game.partner(of: a.id) else { return }
            model.flip(a.id)
            if pause > 0 { try? await Task.sleep(for: .milliseconds(Int(pause * 1000))) }
            model.flip(b)
            if pause > 0 { try? await Task.sleep(for: .milliseconds(Int(pause * 1000))) }
        }
    }

    /// ちがう 2 枚をめくる（remembered なら、1 度見せてからもう一度外す）
    static func missOnce(_ model: AppModel, remembered: Bool = false, pause: Double = 0) async {
        let cards = unmatched(model)
        guard let a = cards.first, let b = cards.first(where: { $0.concept != a.concept }) else { return }
        model.flip(a.id)
        if pause > 0 { try? await Task.sleep(for: .milliseconds(Int(pause * 1000))) }
        model.flip(b.id)
        if remembered {
            model.flip(a.id)
            model.flip(b.id)
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }
        await wait(1.6)
        // 今日の盤：6 組
        model.startDaily()
        await wait(1.2)
        guard let game = model.session?.game, let a = game.cards.first,
              let b = game.cards.first(where: { $0.concept != a.concept }),
              let pa = game.partner(of: a.id), let pb = game.partner(of: b.id) else { return }
        // 1 回外す → 覚えた音で 2 組続けてそろえる
        model.flip(a.id); await wait(1.0)
        model.flip(b.id); await wait(1.8)
        model.flip(pb); await wait(0.9)
        model.flip(b.id); await wait(1.2)
        model.flip(pa); await wait(0.9)
        model.flip(a.id); await wait(1.2)
        // 残りをそろえる
        await Script.match(model, pairs: 99, pause: 0.55)
        await wait(4.0)
        // 聞き分けの記録
        model.closeBoard()
        await wait(0.6)
        model.activeSheet = .record
    }
}
