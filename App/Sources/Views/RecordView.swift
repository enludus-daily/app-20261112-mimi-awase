import SwiftUI

/// 聞き分けの記録：続けた日・モードごとの聞き分け・取り違えやすい音・週のマス
struct RecordView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    summary
                    if model.progress.playedDays == 0 && model.progress.tallies.isEmpty {
                        empty
                    } else {
                        heatmap
                        accuracy
                        confusions
                    }
                }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.mist.ignoresSafeArea())
            .navigationTitle(Text("聞き分けの記録"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("main.closeRecord")
                }
            }
        }
        .tint(Palette.skyDeep)
    }

    // MARK: -

    private var summary: some View {
        let streak = model.progress.streak(on: model.now, calendar: model.calendar)
        return HStack(spacing: 0) {
            big("\(streak)", "続けた日")
            Rectangle().fill(Palette.rule).frame(width: 1, height: 40)
            big("\(model.progress.playedDays)", "遊んだ日の合計")
            Rectangle().fill(Palette.rule).frame(width: 1, height: 40)
            big("\(model.progress.totalPairs)", "そろえた組")
        }
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(Palette.rule, lineWidth: 1))
    }

    private func big(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(Typo.serif(34))
                .kerning(-1.5)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(Typo.label)
                .kerning(0.5)
                .foregroundStyle(Palette.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            EmblemView(size: 96)
            Text("まだ記録がありません")
                .font(Typo.serif(20))
                .foregroundStyle(Palette.ink)
            Text("今日の盤を 1 回遊ぶと、どの音を取り違えやすいかがここに出ます。")
                .font(Typo.small)
                .foregroundStyle(Palette.sub)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
                model.startDaily()
            } label: {
                PrimaryButtonLabel(title: "今日の盤をはじめる", systemImage: "ear")
            }
            .buttonStyle(PressStyle())
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
    }

    private var heatmap: some View {
        let weeks = model.isPro ? 26 : 12
        let data = model.progress.weeks(weeks, endingAt: model.now, calendar: model.calendar)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "遊んだ日")
                Spacer()
                if model.isPro {
                    Text("26 週")
                        .font(Typo.small)
                        .foregroundStyle(Palette.sub)
                } else {
                    Button {
                        model.activeSheet = .paywall(.history)
                    } label: {
                        Text("26 週は Pro")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.peachDeep)
                    }
                }
            }
            Canvas { context, size in
                let gap: CGFloat = 3
                let cell = min((size.width - gap * CGFloat(weeks - 1)) / CGFloat(weeks), (size.height - gap * 6) / 7)
                for (w, week) in data.enumerated() {
                    for (d, value) in week.enumerated() {
                        guard let value else { continue }
                        let rect = CGRect(x: CGFloat(w) * (cell + gap), y: CGFloat(d) * (cell + gap), width: cell, height: cell)
                        let color: Color
                        switch value {
                        case 0: color = Palette.rule.opacity(0.6)
                        case 1: color = Palette.skyLine
                        case 2: color = Palette.sky
                        default: color = Palette.skyDeep.opacity(0.75)
                        }
                        context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                    }
                }
            }
            .frame(height: 104)
            .accessibilityElement()
            .accessibilityLabel(Text("遊んだ日の合計 \(model.progress.playedDays) 日"))
        }
    }

    private var accuracy: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "聞き分けの正確さ")
            ForEach(Mode.allCases) { mode in
                let tally = model.progress.tallies[mode] ?? Tally()
                HStack(spacing: 12) {
                    Text(verbatim: mode.title(japanese: model.japanese))
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 92, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.rule.opacity(0.7))
                            Capsule().fill(Palette.sky)
                                .frame(width: proxy.size.width * CGFloat(tally.rate ?? 0))
                        }
                    }
                    .frame(height: 8)
                    Text(verbatim: tally.rate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        .font(Typo.serif(15))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .frame(width: 46, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
            Text("覚えていたはずの音で、当てられた割合です。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.sub)
        }
    }

    private var confusions: some View {
        let top = model.progress.topConfusions(5)
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "取り違えやすい音")
            if top.isEmpty {
                Text("取り違えはまだありません。")
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
            } else {
                ForEach(top.map { $0.0 }, id: \.self) { confusion in
                    ConfusionRow(confusion: confusion, count: model.progress.confusionCounts[confusion])
                }
                Button {
                    model.activeSheet = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        model.startWeakness()
                    }
                } label: {
                    QuietButtonLabel(title: model.isPro ? "この音で聞き直しの盤" : "聞き直しの盤（Pro）", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(PressStyle())
                .padding(.top, 4)
            }
        }
    }
}
