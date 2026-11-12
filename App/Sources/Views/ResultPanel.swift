import SwiftUI

/// 盤を終えたときの結果（盤の上に重ねる。ボタンは下に固定）
struct ResultPanel: View {
    @Environment(AppModel.self) private var model
    let result: BoardResult
    let session: Session
    @State private var appear = false

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.18).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        heading
                        stats
                        keyboard
                        review
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                buttons
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: 460)
            .background(
                RoundedRectangle(cornerRadius: Radius.l + 6, style: .continuous)
                    .fill(Palette.mist)
                    .shadow(color: Palette.shadowLift, radius: 18, y: 8)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .scaleEffect(appear ? 1 : 0.94)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { appear = true }
        }
    }

    // MARK: -

    private var heading: some View {
        VStack(spacing: 8) {
            EmblemView(size: 64, trigger: model.finishTick)
            Text(headline)
                .font(Typo.serif(26))
                .kerning(-0.6)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            RippleStars(count: result.stars, size: 18)
        }
    }

    private var headline: LocalizedStringKey {
        switch result.kind {
        case .tutorial: return "耳で、そろえられました"
        case .daily: return "今日の盤、おしまい"
        case .weakness: return "聞き直し、おしまい"
        case .stage: return result.stars == 3 ? "ぴたりと合いました" : "そろいました"
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(value: "\(result.moves)", label: "手数")
            divider
            stat(value: "\(Game.par(pairs: result.pairs).three)", label: "3つ星の目安")
            divider
            stat(value: accuracyText, label: "聞き分け")
        }
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Palette.rule, lineWidth: 1))
    }

    private var accuracyText: String {
        let total = result.hits + result.misses
        guard total > 0 else { return "—" }
        return "\(Int((Double(result.hits) / Double(total) * 100).rounded()))%"
    }

    private var divider: some View {
        Rectangle().fill(Palette.rule).frame(width: 1, height: 30)
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(Typo.serif(24))
                .kerning(-0.8)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(Typo.label)
                .kerning(0.5)
                .foregroundStyle(Palette.sub)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// そろえた音を鍵盤で光らせる（音名と鍵盤がつながる）
    @ViewBuilder
    private var keyboard: some View {
        let notes = Set(session.game.foundOrder.flatMap { AppModel.sound(for: $0).midiNotes })
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "そろえた音")
                KeyboardStrip(lit: notes, low: 60, octaves: 2)
                    .frame(height: 46)
                Text(verbatim: session.game.foundOrder.map { model.label($0) }.joined(separator: "  ·  "))
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
                    .lineLimit(2)
            }
        }
    }

    /// 聞き直し：取り違えた組を、並べて聞き比べる
    @ViewBuilder
    private var review: some View {
        let unique = Array(Set(result.confusions)).sorted { $0.a < $1.a }.prefix(3)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "聞き直し")
            if unique.isEmpty {
                Text("取り違えはありません。耳がよく合っています。")
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(unique), id: \.self) { confusion in
                    ConfusionRow(confusion: confusion)
                }
                Text("取り違えた音は、次の盤に少し多く出ます。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.sub)
            }
        }
    }

    // MARK: ボタン

    private var buttons: some View {
        VStack(spacing: 8) {
            Button {
                model.goNext()
            } label: {
                PrimaryButtonLabel(title: primaryTitle, systemImage: primaryIcon)
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("main.next")

            HStack(spacing: 8) {
                if case .tutorial = result.kind {
                    EmptyView()
                } else {
                    Button {
                        model.replay()
                    } label: {
                        QuietButtonLabel(title: "もう一度", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("main.replay")
                    ShareLink(item: shareText) {
                        QuietButtonLabel(title: "共有", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var primaryTitle: LocalizedStringKey {
        switch result.kind {
        case .tutorial: return "はじめる"
        case .stage(let id):
            guard let next = Stage.find(id)?.next else { return "ホームへ" }
            return next.isFree || model.isPro ? "次の段階へ" : "次の段階（Pro）"
        default: return "ホームへ"
        }
    }

    private var primaryIcon: String {
        if case .stage = result.kind { return "arrow.right" }
        return "house"
    }

    /// 答えの分からない共有の文（星と手数だけ）
    private var shareText: String {
        let dots = String(repeating: "◉", count: result.stars) + String(repeating: "○", count: 3 - result.stars)
        let title = session.title(japanese: model.japanese)
        return model.japanese
            ? "みみ合わせ｜\(title)\n\(dots)  \(result.moves) 手で \(result.pairs) 組をそろえました"
            : "Ear Pairs | \(title)\n\(dots)  \(result.pairs) pairs in \(result.moves) moves"
    }
}

/// 取り違えた 2 つの音を、押すと続けて鳴らす
struct ConfusionRow: View {
    @Environment(AppModel.self) private var model
    let confusion: Confusion
    var count: Int?

    var body: some View {
        Button {
            model.compare(confusion)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.skyDeep)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.skySoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(model.longLabel(confusion.a))  ↔  \(model.longLabel(confusion.b))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let distance = Concept.distance(confusion.a, confusion.b, japanese: model.japanese) {
                        Text(verbatim: distance)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.sub)
                    }
                }
                Spacer(minLength: 0)
                if let count {
                    Text(verbatim: "×\(count)")
                        .font(Typo.serif(15))
                        .monospacedDigit()
                        .foregroundStyle(Palette.peachDeep)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).stroke(Palette.rule, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text(verbatim: "\(model.longLabel(confusion.a)), \(model.longLabel(confusion.b))"))
        .accessibilityHint(Text("2 つの音を続けて鳴らす"))
    }
}
