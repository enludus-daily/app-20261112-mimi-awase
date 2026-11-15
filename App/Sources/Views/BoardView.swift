import SwiftUI

/// 盤の並べ方：カードがいちばん大きくなる列の数を選ぶ（スクロールなしで全部見える）
enum BoardLayout {
    static func columns(count: Int, in size: CGSize, spacing: CGFloat) -> (columns: Int, side: CGFloat) {
        guard count > 0, size.width > 0, size.height > 0 else { return (2, 60) }
        var best = (columns: 2, side: CGFloat(0))
        for c in 2...8 {
            let rows = Int((Double(count) / Double(c)).rounded(.up))
            let w = (size.width - CGFloat(c - 1) * spacing) / CGFloat(c)
            let h = (size.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            let side = min(w, h)
            if side > best.side { best = (c, side) }
        }
        return (best.columns, min(best.side, 150))
    }
}

struct BoardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var comboShown = 0

    var body: some View {
        if let session = model.session {
            VStack(spacing: 0) {
                header(session)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                GeometryReader { proxy in
                    grid(session, size: proxy.size)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                footer(session)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
            .background(NightBackground())
            .overlay(alignment: .top) { comboBadge }
            .overlay {
                if let result = model.result {
                    ResultPanel(result: result, session: session)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.easeOut(duration: 0.3), value: model.result != nil)
        }
    }

    // MARK: -

    private func header(_ session: Session) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                model.closeBoard()
            } label: {
                GlassIcon(systemName: "xmark")
            }
            .accessibilityLabel(Text("盤を閉じる"))
            .accessibilityIdentifier("main.closeBoard")

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: session.title(japanese: model.japanese))
                    .font(Typo.display(19, .regular))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: session.mode.rule(japanese: model.japanese))
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(session.game.moves)")
                    .font(Typo.display(30, .thin))
                    .kerning(-1)
                    .monospacedDigit()
                    .foregroundStyle(Palette.text)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.25), value: session.game.moves)
                Text("手数")
                    .font(Typo.label)
                    .kerning(1.2)
                    .foregroundStyle(Palette.sub)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func grid(_ session: Session, size: CGSize) -> some View {
        let spacing: CGFloat = session.game.cards.count > 12 ? 8 : 12
        let layout = BoardLayout.columns(count: session.game.cards.count, in: size, spacing: spacing)
        let columns = Array(repeating: GridItem(.fixed(layout.side), spacing: spacing), count: layout.columns)
        let pairIndex = Self.pairIndex(session.game.cards)
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(session.game.cards) { card in
                CardView(
                    card: card,
                    side: layout.side,
                    state: state(of: card, in: session.game),
                    style: PairStyle.of(pairIndex[card.concept] ?? 0, concept: card.concept),
                    rippleTick: model.ripple.card == card.id ? model.ripple.tick : 0,
                    shaking: model.shaking.contains(card.id),
                    celebrate: model.finishTick,
                    celebrateDelay: Double(card.id) * 0.04,
                    label: model.showNames ? model.label(card.concept) : nil
                ) {
                    model.flip(card.id)
                }
                .accessibilityIdentifier("main.card\(card.id)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func footer(_ session: Session) -> some View {
        HStack(spacing: 8) {
            // 残りのペア（そろえた順に、その音の色で光る点）
            HStack(spacing: 6) {
                ForEach(0..<session.game.pairs, id: \.self) { i in
                    let found = session.game.foundOrder
                    let tint = i < found.count ? Palette.tint(of: found[i]) : nil
                    Circle()
                        .fill(tint ?? Palette.rule)
                        .frame(width: 7, height: 7)
                        .glow(tint ?? .clear, radius: 3, opacity: tint == nil ? 0 : 0.8)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("残り \(session.game.pairsLeft) 組"))
            Spacer()
            if case .tutorial = session.kind {
                Text("外れても大丈夫。音を覚えていこう")
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
            } else {
                let par = Game.par(pairs: session.game.pairs)
                Text("3つ星の目安 \(par.three) 手")
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
            }
        }
        .frame(minHeight: 28)
    }

    @ViewBuilder
    private var comboBadge: some View {
        if model.lastCombo > 1 && comboShown == model.comboTick && model.comboTick > 0 {
            Text("×\(model.lastCombo)")
                .font(Typo.display(24, .light))
                .monospacedDigit()
                .foregroundStyle(Palette.moon)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.ebony.opacity(0.85)))
                .overlay(Capsule().stroke(Palette.moon.opacity(0.5), lineWidth: 1))
                .glow(Palette.moon, radius: 8, opacity: 0.45)
                .padding(.top, 64)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityHidden(true)
        }
        Color.clear.frame(height: 0)
            .onChange(of: model.comboTick) { _, tick in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { comboShown = tick }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1100))
                    if comboShown == tick { withAnimation(.easeOut(duration: 0.3)) { comboShown = -1 } }
                }
            }
    }

    private func state(of card: Card, in game: Game) -> CardView.FaceState {
        if game.matched.contains(card.id) { return .matched }
        if game.faceUp.contains(card.id) { return .listening }
        return .down
    }

    /// ペアごとの番号（カードの並び順で最初に出た順）
    static func pairIndex(_ cards: [Card]) -> [Concept: Int] {
        var result: [Concept: Int] = [:]
        for card in cards.sorted(by: { $0.id < $1.id }) where result[card.concept] == nil {
            result[card.concept] = result.count
        }
        return result
    }
}

/// 1 枚のカード
struct CardView: View {
    enum FaceState: Equatable { case down, listening, matched }

    let card: Card
    let side: CGFloat
    let state: FaceState
    let style: PairStyle
    let rippleTick: Int
    let shaking: Bool
    let celebrate: Int
    let celebrateDelay: Double
    let label: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bump = false
    @State private var lift = false
    /// そろった瞬間、カードの外へ広がる光の輪（0 → 1）
    @State private var burst: CGFloat = 1

    var body: some View {
        let up = state != .down
        Button(action: action) {
            ZStack {
                back
                    .opacity(up ? 0 : 1)
                front
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(up ? 1 : 0)
            }
            .frame(width: side, height: side)
            .background {
                if !reduceMotion && burst < 1 {
                    ForEach(0..<2) { i in
                        let p = min(1, max(0, burst * 1.2 - CGFloat(i) * 0.2))
                        RoundedRectangle(cornerRadius: radius * 1.4, style: .continuous)
                            .stroke(style.tint, lineWidth: 2 - CGFloat(i) * 0.8)
                            .scaleEffect(1 + p * 0.75)
                            .opacity(Double(1 - p))
                            .glow(style.tint, radius: 6, opacity: 0.6)
                    }
                }
            }
            .rotation3DEffect(.degrees(up && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(lift ? 1.06 : (bump ? 1.08 : 1))
            .modifier(ShakeEffect(travel: shaking && !reduceMotion ? 1 : 0))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: up)
            .animation(.easeInOut(duration: 0.42), value: shaking)
        }
        .buttonStyle(PressStyle())
        .disabled(state == .matched)
        .accessibilityLabel(accessibilityText)
        .onChange(of: state) { old, new in
            guard !reduceMotion else { return }
            if new == .listening {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { lift = true }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75).delay(0.15)) { lift = false }
            }
            if new == .matched && old != .matched {
                burst = 0
                withAnimation(.easeOut(duration: 0.9).delay(0.12)) { burst = 1 }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bump = true }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.2)) { bump = false }
            }
        }
        .onChange(of: celebrate) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55).delay(celebrateDelay)) { bump = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(celebrateDelay + 0.22)) { bump = false }
        }
    }

    private var radius: CGFloat { Radius.card(side) }

    private var back: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x223268), Color(hex: 0x131C42)], startPoint: .top, endPoint: .bottom))
            .overlay(StillWater().clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous)))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
            // 下辺だけ厚く：押せる鍵に見せる
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.ebony)
                    .offset(y: 3)
            )
            .shadow(color: Palette.shadow, radius: 6, y: 4)
    }

    private var front: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Palette.ebony)
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill((state == .matched ? style.tint : Palette.glow).opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(state == .matched ? style.tint.opacity(0.8) : Palette.glowLine, lineWidth: state == .matched ? 1.5 : 1))
                .glow(state == .matched ? style.tint : Palette.glow, radius: state == .listening ? 10 : 6, opacity: state == .listening ? 0.45 : 0.3)
            if state == .matched {
                PairMark(style: style)
                    .padding(side * 0.16)
                    .padding(.bottom, label == nil ? 0 : side * 0.08)
                if let label {
                    Text(verbatim: label)
                        .font(.system(size: max(9, side * 0.13), weight: .medium))
                        .foregroundStyle(Palette.text.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, side * 0.07)
                }
            } else {
                ListeningRipple(trigger: rippleTick, tint: Palette.glow)
                    .padding(side * 0.1)
            }
        }
    }

    private var accessibilityText: Text {
        switch state {
        case .down: return Text("伏せたカード")
        case .listening: return Text("めくったカード")
        case .matched: return Text("そろったカード \(label ?? "")")
        }
    }
}

/// 外れたときの小さな横揺れ（責めない程度に）
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = sin(travel * .pi * 4) * 5 * (1 - abs(travel - 0.5))
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
