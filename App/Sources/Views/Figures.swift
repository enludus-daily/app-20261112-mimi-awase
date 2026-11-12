import SwiftUI

// 題材の部品：音叉・水面の波紋・鍵盤。カードの絵柄の代わりに「音の形」を描く。

/// 音叉（カードの裏の小さな印・アイコン）
struct TuningFork: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let prongW = w * 0.16
        let gap = w * 0.28
        let left = rect.midX - gap / 2 - prongW
        let right = rect.midX + gap / 2
        let top = rect.minY
        let bend = rect.minY + h * 0.58
        // 2 本の歯
        p.addRoundedRect(in: CGRect(x: left, y: top, width: prongW, height: h * 0.6), cornerSize: CGSize(width: prongW / 2, height: prongW / 2))
        p.addRoundedRect(in: CGRect(x: right, y: top, width: prongW, height: h * 0.6), cornerSize: CGSize(width: prongW / 2, height: prongW / 2))
        // 底の U
        p.move(to: CGPoint(x: left, y: bend))
        p.addQuadCurve(to: CGPoint(x: right + prongW, y: bend), control: CGPoint(x: rect.midX, y: bend + h * 0.26))
        p.addLine(to: CGPoint(x: right, y: bend))
        p.addQuadCurve(to: CGPoint(x: left + prongW, y: bend), control: CGPoint(x: rect.midX, y: bend + h * 0.12))
        p.closeSubpath()
        // 柄
        p.addRoundedRect(in: CGRect(x: rect.midX - prongW / 2, y: bend + h * 0.14, width: prongW, height: h * 0.28), cornerSize: CGSize(width: prongW / 2, height: prongW / 2))
        return p
    }
}

/// 波紋の形。sides 0 は円、3 以上は角の数。petals > 0 は花びらの形
struct RippleShape: Shape {
    var sides: Int
    var petals: Int = 0
    var rotation: Double = 0

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        if petals > 0 {
            let steps = 120
            for i in 0...steps {
                let a = Double(i) / Double(steps) * 2 * .pi
                let rr = r * (0.82 + 0.18 * cos(Double(petals) * a))
                let pt = CGPoint(x: c.x + rr * cos(a + rotation), y: c.y + rr * sin(a + rotation))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        } else if sides < 3 {
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        } else {
            for i in 0..<sides {
                let a = Double(i) / Double(sides) * 2 * .pi - .pi / 2 + rotation
                let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
        return p
    }
}

/// ペアごとの波紋の形と色（12 通り）
struct PairStyle: Equatable {
    let shape: RippleShape
    let tint: Color

    static func of(_ index: Int) -> PairStyle {
        let shapes: [RippleShape] = [
            RippleShape(sides: 0), RippleShape(sides: 4, rotation: .pi / 4), RippleShape(sides: 6),
            RippleShape(sides: 0, petals: 5), RippleShape(sides: 3), RippleShape(sides: 4),
            RippleShape(sides: 0, petals: 4), RippleShape(sides: 5), RippleShape(sides: 8),
            RippleShape(sides: 0, petals: 6), RippleShape(sides: 3, rotation: .pi), RippleShape(sides: 0, petals: 3),
        ]
        let i = ((index % shapes.count) + shapes.count) % shapes.count
        return PairStyle(shape: shapes[i], tint: Palette.pairTints[i % Palette.pairTints.count])
    }

    static func == (lhs: PairStyle, rhs: PairStyle) -> Bool {
        lhs.shape.sides == rhs.shape.sides && lhs.shape.petals == rhs.shape.petals && lhs.shape.rotation == rhs.shape.rotation
    }
}

/// そろったペアの印：同じ形の輪が 3 重に重なる
struct PairMark: View {
    let style: PairStyle
    var glow: CGFloat = 1

    var body: some View {
        ZStack {
            style.shape.fill(style.tint.opacity(0.28))
                .scaleEffect(0.9)
            ForEach(0..<3) { i in
                style.shape
                    .stroke(style.tint, lineWidth: i == 0 ? 1.6 : 1)
                    .scaleEffect(0.32 + CGFloat(i) * 0.29 * glow)
                    .opacity(1 - Double(i) * 0.25)
            }
            style.shape.fill(style.tint).scaleEffect(0.14)
        }
    }
}

/// めくったときに広がる波紋（どの音でも同じ形。見た目で答えが分からないように）
struct ListeningRipple: View {
    let trigger: Int
    var tint: Color = Palette.sky
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 1

    var body: some View {
        ZStack {
            // 静かな輪（波紋が消えたあとも「聞いている」と分かるように）
            ForEach(0..<2) { i in
                Circle()
                    .stroke(tint.opacity(0.35), lineWidth: 0.8)
                    .scaleEffect(0.38 + CGFloat(i) * 0.3)
            }
            ForEach(0..<3) { i in
                let p = min(1, max(0, phase * 1.3 - CGFloat(i) * 0.18))
                Circle()
                    .stroke(tint, lineWidth: 1.4)
                    .scaleEffect(0.18 + p * 0.95)
                    .opacity(Double(1 - p) * 0.9)
            }
            Circle().fill(tint).frame(width: 6, height: 6)
        }
        .onChange(of: trigger) { _, _ in start() }
        .onAppear { start() }
    }

    private func start() {
        guard !reduceMotion, !Launch.isStill else { phase = 0.45; return }
        phase = 0
        withAnimation(.easeOut(duration: 1.1)) { phase = 1 }
    }
}

/// 止まった水面（カードの裏の模様）
struct StillWater: View {
    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width * 0.72, y: size.height * 0.78)
            for i in 1...4 {
                let r = CGFloat(i) * size.width * 0.16
                let rect = CGRect(x: c.x - r, y: c.y - r * 0.62, width: r * 2, height: r * 1.24)
                context.stroke(Path(ellipseIn: rect), with: .color(Palette.skyLine.opacity(1 - Double(i) * 0.18)), lineWidth: 0.7)
            }
        }
        .allowsHitTesting(false)
    }
}

/// 鍵盤（結果で、そろえた音を光らせる）。C4〜B5 の 2 オクターブ
struct KeyboardStrip: View {
    var lit: Set<Int>
    var low = 60
    var octaves = 2

    private static let whiteOffsets = [0, 2, 4, 5, 7, 9, 11]
    private static let blackOffsets: [(Int, Double)] = [(1, 1), (3, 2), (6, 4), (8, 5), (10, 6)]

    var body: some View {
        GeometryReader { proxy in
            let whites = 7 * octaves
            let w = proxy.size.width / CGFloat(whites)
            let h = proxy.size.height
            ZStack(alignment: .topLeading) {
                ForEach(0..<whites, id: \.self) { i in
                    let midi = low + (i / 7) * 12 + Self.whiteOffsets[i % 7]
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(lit.contains(midi) ? Palette.sky : Palette.paper)
                        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Palette.rule, lineWidth: 0.8))
                        .frame(width: w - 1.5, height: h)
                        .offset(x: CGFloat(i) * w)
                }
                ForEach(0..<(5 * octaves), id: \.self) { i in
                    let key = Self.blackOffsets[i % 5]
                    let midi = low + (i / 5) * 12 + key.0
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(lit.contains(midi) ? Palette.skyDeep : Palette.ink.opacity(0.72))
                        .frame(width: w * 0.58, height: h * 0.6)
                        .offset(x: (CGFloat(i / 5) * 7 + CGFloat(key.1)) * w - w * 0.29 - 0.75)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 星の代わりの、小さな波紋の点（3 つ）
struct RippleStars: View {
    let count: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: size * 0.45) {
            ForEach(0..<3) { i in
                ZStack {
                    Circle().stroke(i < count ? Palette.peachDeep : Palette.rule, lineWidth: 1)
                    Circle().fill(i < count ? Palette.peach : Color.clear).padding(size * 0.22)
                }
                .frame(width: size, height: size)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("星 \(count)"))
    }
}

/// アプリの印（音叉と波紋）。オンボーディング・空の画面に使う
struct EmblemView: View {
    var size: CGFloat = 120
    var trigger = 0

    var body: some View {
        ZStack {
            Circle().fill(Palette.skyPale)
            ListeningRipple(trigger: trigger, tint: Palette.sky)
                .padding(size * 0.04)
            TuningFork()
                .fill(Palette.skyDeep.opacity(0.85))
                .frame(width: size * 0.22, height: size * 0.42)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
