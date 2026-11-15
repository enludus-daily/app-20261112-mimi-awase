import SwiftUI

/// ホーム：今日の盤・モードと段階・聞き直し
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var emblemTick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 見出しは夜の池の上に浮かべる（池がホームの主役）
                pond
                    .overlay(alignment: .top) {
                        header
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }
                if sizeClass == .regular {
                    // 広い画面（iPhone Duo の内側など）：左に今日の盤、右に段階
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 16) {
                            todayCard
                            weaknessCard
                        }
                        .frame(maxWidth: .infinity)
                        stagesSection
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    todayCard
                    stagesSection
                    weaknessCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: sizeClass == .regular ? 980 : 560)
            .frame(maxWidth: .infinity)
        }
        .background(NightBackground(lines: false))
    }

    // MARK: 夜の池（触ると鳴る。今日の盤の音が静かな波紋で浮かぶ）

    private var pond: some View {
        let marks = Self.pondMarks(for: model.now, calendar: model.calendar)
        return NightPond(marks: marks) { midi in
            model.synth.play(.note(midi), gain: 0.8)
        }
        .frame(height: sizeClass == .regular ? 210 : 176)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Palette.rule, lineWidth: 1))
        .overlay(alignment: .bottomLeading) {
            Text("触ると音が鳴ります")
                .font(Typo.label)
                .kerning(1.0)
                .foregroundStyle(Palette.sub)
                .padding(12)
                .allowsHitTesting(false)
        }
    }

    /// 日ごとに変わる、池に浮かぶ 3 つの静かな波紋
    static func pondMarks(for date: Date, calendar: Calendar) -> [NightPond.Mark] {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let scale = NightPond.scale
        return (0..<3).map { i in
            let k = (day * (i + 3) + i * 5) % scale.count
            let xs: [CGFloat] = [0.24, 0.5, 0.4]
            let ys: [CGFloat] = [0.64, 0.8, 0.5]
            return NightPond.Mark(x: xs[i] + CGFloat((day + i) % 3) * 0.04, y: ys[i], midi: scale[k], scale: ([1.0, 0.8, 0.6] as [CGFloat])[i])
        }
    }

    // MARK: 見出し

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.now, format: .dateTime.month().day().weekday())
                    .font(Typo.label)
                    .kerning(0.8)
                    .foregroundStyle(Palette.sub)
                    .textCase(.uppercase)
                Text("みみ合わせ")
                    .font(Typo.display(32, .ultraLight))
                    .kerning(1.5)
                    .foregroundStyle(Palette.text)
            }
            Spacer()
            HStack(spacing: 8) {
                iconButton("chart.bar.xaxis", label: "聞き分けの記録", id: "main.record") { model.activeSheet = .record }
                iconButton("gearshape", label: "設定", id: "main.settings") { model.activeSheet = .settings }
            }
        }
    }

    private func iconButton(_ systemName: String, label: LocalizedStringKey, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlassIcon(systemName: systemName)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }

    // MARK: 今日の盤

    private var todayCard: some View {
        let done = model.progress.isDailyDone(on: model.now, calendar: model.calendar)
        let streak = model.progress.streak(on: model.now, calendar: model.calendar)
        let mode = model.dailyMode
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "今日の盤")
                    Text(verbatim: mode.title(japanese: model.japanese))
                        .font(Typo.display(28, .light))
                        .foregroundStyle(Palette.text)
                    Text(verbatim: mode.rule(japanese: model.japanese))
                        .font(Typo.small)
                        .foregroundStyle(Palette.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                EmblemView(size: 76, trigger: emblemTick)
                    .onTapGesture { emblemTick += 1 }
            }
            HStack(spacing: 14) {
                Label {
                    Text("続けて \(streak) 日")
                } icon: {
                    Image(systemName: "moon.stars")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.moon)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Palette.moonSoft))
                Text("6 組 · 毎日かわる")
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
                Spacer()
                if done, let day = model.progress.days[Progress.dayKey(model.now, calendar: model.calendar)] {
                    RippleStars(count: day.dailyStars, size: 12)
                }
            }
            Button {
                model.startDaily()
            } label: {
                PrimaryButtonLabel(title: done ? "今日の盤をもう一度" : "今日の盤をはじめる", systemImage: "ear")
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("main.daily")
        }
        .padding(18)
        .glassPanel(stroke: Palette.glowLine.opacity(0.6))
    }

    // MARK: 段階

    private var stagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "段階")
                Spacer()
                Text("\(model.progress.totalStars(model.selectedMode)) / 45")
                    .font(Typo.display(14, .regular))
                    .monospacedDigit()
                    .foregroundStyle(Palette.sub)
            }
            modePicker
            Text(verbatim: model.selectedMode.rule(japanese: model.japanese))
                .font(Typo.small)
                .foregroundStyle(Palette.sub)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Stage.all(model.selectedMode)) { stage in
                    StageTile(stage: stage)
                }
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(Mode.allCases) { mode in
                let selected = model.selectedMode == mode
                Button {
                    model.select()
                    withAnimation(.easeOut(duration: 0.25)) { model.selectedMode = mode }
                } label: {
                    VStack(spacing: 2) {
                        Text(verbatim: mode.title(japanese: model.japanese))
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if mode == .chord || mode == .interval {
                            (model.isPro ? Text(verbatim: "Pro") : Text("3 段まで無料"))
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(selected ? Palette.ebonyText.opacity(0.6) : Palette.sub)
                        } else {
                            Text("無料")
                                .font(.system(size: 9))
                                .foregroundStyle(selected ? Palette.ebonyText.opacity(0.6) : Palette.sub)
                        }
                    }
                    // 選んだモードは白鍵、ほかは黒鍵
                    .foregroundStyle(selected ? Palette.ebonyText : Palette.text)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 10, bottomTrailingRadius: 10, topTrailingRadius: 4, style: .continuous)
                            .fill(selected ? Palette.ivory : Palette.ebony)
                    )
                    .overlay(
                        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 10, bottomTrailingRadius: 10, topTrailingRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(selected ? 0 : 0.14), lineWidth: 1)
                    )
                    .glow(Palette.glow, radius: 8, opacity: selected ? 0.35 : 0)
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: 聞き直しの盤（Pro）

    private var weaknessCard: some View {
        let top = model.progress.topConfusions(2)
        return Button {
            model.startWeakness()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Palette.ebony)
                    PairMark(style: PairStyle(shape: RippleShape(sides: 0, petals: 5), tint: Palette.pitch(66)))
                        .padding(9)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("聞き直しの盤")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.text)
                        if !model.isPro {
                            Text("Pro")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Palette.moon)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Palette.moonSoft))
                        }
                    }
                    if top.isEmpty {
                        Text("取り違えた音が、ここにたまります")
                            .font(Typo.small)
                            .foregroundStyle(Palette.sub)
                    } else {
                        Text(verbatim: top.map { "\(model.label($0.0.a))↔\(model.label($0.0.b))" }.joined(separator: "  "))
                            .font(Typo.small)
                            .foregroundStyle(Palette.sub)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
            }
            .padding(14)
            .glassPanel(radius: Radius.m)
        }
        .buttonStyle(PressStyle())
        .disabled(model.isPro && top.isEmpty)
    }
}

/// 段階の 1 マス
struct StageTile: View {
    @Environment(AppModel.self) private var model
    let stage: Stage

    var body: some View {
        let open = model.progress.isOpen(stage)
        let locked = !stage.isFree && !model.isPro
        let stars = model.progress.stars(of: stage)
        let isNext = model.progress.nextStage(in: stage.mode) == stage && open
        Button {
            model.start(stage)
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Text("\(stage.number)")
                        .font(Typo.display(22, .light))
                        .monospacedDigit()
                        .foregroundStyle(open ? Palette.text : Palette.sub.opacity(0.6))
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.moon)
                            .offset(x: 14, y: -10)
                    }
                }
                RippleStars(count: stars, size: 7)
                Text("\(stage.pairs * 2) 枚")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.sub)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(isNext ? Palette.glowSoft : Palette.glass))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(isNext ? Palette.glow : Palette.rule, lineWidth: isNext ? 1.4 : 1))
            .glow(Palette.glow, radius: 8, opacity: isNext ? 0.4 : 0)
            .opacity(open ? 1 : 0.5)
        }
        .buttonStyle(PressStyle())
        .disabled(!open)
        .accessibilityLabel(Text("\(stage.number) 段"))
        .accessibilityValue(locked ? Text(verbatim: "Pro") : (open ? Text("星 \(stars)") : Text("まだ開いていない")))
    }
}
