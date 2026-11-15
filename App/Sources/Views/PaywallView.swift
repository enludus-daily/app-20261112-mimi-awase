import StoreKit
import SwiftUI

/// 課金の画面：価値を感じた直後（無料の段階を終えた・鍵のある物を押した）にだけ出す。
/// 値段・購入・復元は下に固定し、スクロールしなくても見える
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason
    @State private var buying = false
    @State private var message: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(headline)
                            .font(Typo.label)
                            .kerning(0.6)
                            .foregroundStyle(Palette.moon)
                        Text("耳を、もっと先まで")
                            .font(Typo.display(30, .light))
                            .foregroundStyle(Palette.text)
                        Text("みみ合わせ Pro は 1 回だけの買い切りです。サブスクではありません。")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    preview
                    VStack(spacing: 0) {
                        Feature(systemName: "pianokeys", title: "和音と音程の 24 段階", detail: "長・短・sus4・減・増・長七、転回まで。音程は短2度からオクターブまで。")
                        Feature(systemName: "arrow.triangle.2.circlepath", title: "聞き直しの盤", detail: "取り違えた音だけで、何度でも 6 組の盤を作ります。")
                        Feature(systemName: "music.note", title: "音色 オルゴール・マリンバ", detail: "同じ音でも、音色が変わると聞き分けの練習になります。")
                        Feature(systemName: "square.grid.3x3", title: "26 週の記録", detail: "半年ぶんの遊んだ日を、1 枚のマスで。", last: true)
                    }
                    .glassPanel(radius: Radius.m)
                    Text("今日の盤・同じ音とオクターブの 30 段階・和音と音程の 3 段階ずつ・記録は、ずっと無料です。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(NightBackground())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    buyArea
                    HStack(spacing: 16) {
                        Button("購入を復元") {
                            Task {
                                await model.purchases.restore()
                                message = model.isPro ? "Pro を復元しました" : "復元できる購入が見つかりませんでした"
                            }
                        }
                        .accessibilityIdentifier("main.restore")
                        Link(destination: URL(string: "https://github.com/enludus-daily/app-20261112-mimi-awase/blob/main/PRIVACY.md")!) {
                            Text("プライバシーポリシー")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.glowStrong)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .background(
                    Palette.nightBottom
                        .overlay(alignment: .top) { Rectangle().fill(Palette.rule).frame(height: 1) }
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("main.closePaywall")
                }
            }
        }
        .tint(Palette.glowStrong)
        .task {
            if model.purchases.loadState == .idle { await model.purchases.load() }
        }
        .onChange(of: model.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private var headline: LocalizedStringKey {
        switch reason {
        case .cleared: return "無料の段階をおえました"
        case .stage: return "この段階は Pro"
        case .weakness: return "聞き直しの盤は Pro"
        case .timbre: return "この音色は Pro"
        case .history: return "26 週の記録は Pro"
        case .settings: return "Pro"
        }
    }

    /// 和音の盤の見本（押すと実際に鳴る。払う前に音を試せる）
    private var preview: some View {
        let samples: [(Concept, Int)] = [
            (.chord(root: 60, quality: .major), 0), (.chord(root: 62, quality: .minor), 1),
            (.chord(root: 65, quality: .sus4), 2), (.chord(root: 67, quality: .major7), 3),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ForEach(samples.indices, id: \.self) { i in
                    let sample = samples[i]
                    Button {
                        model.listen(sample.0)
                    } label: {
                        VStack(spacing: 4) {
                            let style = PairStyle.of(sample.1, concept: sample.0)
                            PairMark(style: style)
                                .padding(10)
                                .aspectRatio(1, contentMode: .fit)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.ebony))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(style.tint.opacity(0.8), lineWidth: 1.2))
                            Text(verbatim: model.label(sample.0))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Palette.text)
                        }
                    }
                    .buttonStyle(PressStyle())
                    .frame(maxWidth: .infinity)
                }
            }
            Text("押すと鳴ります：Pro の和音の盤に出る音")
                .font(.system(size: 11))
                .foregroundStyle(Palette.sub)
        }
    }

    @ViewBuilder
    private var buyArea: some View {
        VStack(spacing: 6) {
            switch model.purchases.loadState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 52)
            case .ready:
                if let product = model.purchases.products.first {
                    Button {
                        Task {
                            buying = true
                            let outcome = await model.purchases.purchase(product)
                            buying = false
                            switch outcome {
                            case .purchased: message = "ありがとうございます！ Pro が使えます"
                            case .pending: message = "購入の承認を待っています"
                            case .failed: message = "購入できませんでした。時間をおいてもう一度お試しください"
                            case .cancelled: message = nil
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Pro を買う")
                            Text(verbatim: "·")
                            Text(verbatim: product.displayPrice)
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ebonyText)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.ivory)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xA7AEC4)).offset(y: 3))
                        )
                        .glow(Palette.moon, radius: 10, opacity: 0.3)
                    }
                    .buttonStyle(PressStyle())
                    .disabled(buying)
                    .accessibilityIdentifier("main.buy")
                    Text("1 回だけのお支払い。ファミリー共有に対応しています。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.sub)
                }
            case .unavailable:
                VStack(spacing: 4) {
                    Text("いまは購入できません")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text("App Store につながらないようです。電波のよい所で、もう一度開いてください。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("もう一度読み込む") { Task { await model.purchases.load() } }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.glowStrong)
                }
                .frame(maxWidth: .infinity)
            }
            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.glowStrong)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct Feature: View {
    let systemName: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemName)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.glowStrong)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.ebony))
                    .overlay(Circle().stroke(Palette.glowLine, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.text)
                    Text(detail).font(.system(size: 12)).foregroundStyle(Palette.sub).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            if !last { Divider().padding(.leading, 56) }
        }
    }
}
