import SwiftUI

/// ホーム：今日の盤・モードと段階・聞き直し
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var emblemTick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
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
        .background(Palette.mist.ignoresSafeArea())
    }

    // MARK: 見出し

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.now, format: .dateTime.month().day().weekday())
                    .font(Typo.label)
                    .kerning(0.8)
                    .foregroundStyle(Palette.sub)
                Text("みみ合わせ")
                    .font(Typo.serif(32))
                    .kerning(-1)
                    .foregroundStyle(Palette.ink)
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
            Image(systemName: systemName)
                .font(.system(size: 15))
                .foregroundStyle(Palette.skyDeep)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.paper))
                .overlay(Circle().stroke(Palette.rule, lineWidth: 1))
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
                        .font(Typo.serif(26))
                        .kerning(-0.6)
                        .foregroundStyle(Palette.ink)
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
                    Image(systemName: "drop")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.skyDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Palette.skySoft))
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
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Palette.paper)
                .shadow(color: Palette.shadow, radius: 10, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Palette.rule, lineWidth: 1))
    }

    // MARK: 段階

    private var stagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "段階")
                Spacer()
                Text("\(model.progress.totalStars(model.selectedMode)) / 45")
                    .font(Typo.serif(14))
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
                                .foregroundStyle(selected ? Palette.skyDeep : Palette.sub)
                        } else {
                            Text("無料")
                                .font(.system(size: 9))
                                .foregroundStyle(selected ? Palette.skyDeep : Palette.sub)
                        }
                    }
                    .foregroundStyle(selected ? Palette.skyDeep : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: Radius.s + 2, style: .continuous).fill(selected ? Palette.skySoft : Palette.paper))
                    .overlay(RoundedRectangle(cornerRadius: Radius.s + 2, style: .continuous).stroke(selected ? Palette.skyLine : Palette.rule, lineWidth: 1))
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
                    Circle().fill(Palette.peachSoft)
                    PairMark(style: PairStyle(shape: RippleShape(sides: 0, petals: 5), tint: Palette.peach))
                        .padding(9)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("聞き直しの盤")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        if !model.isPro {
                            Text("Pro")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Palette.peachDeep)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Palette.peachSoft))
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
            .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Palette.rule, lineWidth: 1))
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
                        .font(Typo.serif(20))
                        .monospacedDigit()
                        .foregroundStyle(open ? Palette.ink : Palette.sub.opacity(0.6))
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.peachDeep)
                            .offset(x: 14, y: -10)
                    }
                }
                RippleStars(count: stars, size: 7)
                Text("\(stage.pairs * 2) 枚")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.sub)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(isNext ? Palette.skySoft : Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(isNext ? Palette.sky : Palette.rule, lineWidth: isNext ? 1.4 : 1))
            .opacity(open ? 1 : 0.55)
        }
        .buttonStyle(PressStyle())
        .disabled(!open)
        .accessibilityLabel(Text("\(stage.number) 段"))
        .accessibilityValue(locked ? Text(verbatim: "Pro") : (open ? Text("星 \(stars)") : Text("まだ開いていない")))
    }
}
