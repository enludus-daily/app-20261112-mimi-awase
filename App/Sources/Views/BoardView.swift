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
            .background(Palette.mist.ignoresSafeArea())
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
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.sub)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.paper))
                    .overlay(Circle().stroke(Palette.rule, lineWidth: 1))
            }
            .accessibilityLabel(Text("盤を閉じる"))
            .accessibilityIdentifier("main.closeBoard")

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: session.title(japanese: model.japanese))
                    .font(Typo.serif(18))
                    .foregroundStyle(Palette.ink)
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
                    .font(Typo.serif(26))
                    .kerning(-1)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.25), value: session.game.moves)
                Text("手数")
                    .font(Typo.label)
                    .kerning(0.6)
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
                    pairIndex: pairIndex[card.concept] ?? 0,
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
            // 残りのペア（点）
            HStack(spacing: 5) {
                ForEach(0..<session.game.pairs, id: \.self) { i in
                    Circle()
                        .fill(i < session.game.pairs - session.game.pairsLeft ? Palette.sky : Palette.rule)
                        .frame(width: 6, height: 6)
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
                .font(Typo.serif(20, .medium))
                .foregroundStyle(Palette.peachDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.peachSoft))
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
    let pairIndex: Int
    let rippleTick: Int
    let shaking: Bool
    let celebrate: Int
    let celebrateDelay: Double
    let label: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bump = false
    @State private var lift = false

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
            .fill(Palette.skySoft)
            .overlay(StillWater().clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous)))
            .overlay(
                TuningFork()
                    .fill(Palette.skyDeep.opacity(0.28))
                    .frame(width: side * 0.13, height: side * 0.26)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Palette.skyLine, lineWidth: 1))
            // 下辺だけ少し厚く：押せる札に見せる
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.skyLine)
                    .offset(y: 2.5)
            )
            .shadow(color: Palette.shadow, radius: 6, y: 3)
    }

    private var front: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Palette.paper)
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(state == .matched ? PairStyle.of(pairIndex).tint : Palette.skyLine, lineWidth: state == .matched ? 1.5 : 1))
                .shadow(color: state == .listening ? Palette.shadowLift : Palette.shadow, radius: state == .listening ? 10 : 5, y: 4)
            if state == .matched {
                PairMark(style: PairStyle.of(pairIndex))
                    .padding(side * 0.16)
                    .padding(.bottom, label == nil ? 0 : side * 0.08)
                if let label {
                    Text(verbatim: label)
                        .font(.system(size: max(9, side * 0.13), weight: .medium))
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, side * 0.07)
                }
            } else {
                ListeningRipple(trigger: rippleTick, tint: Palette.sky)
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
