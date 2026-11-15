import SwiftUI

// 題材の部品：夜の水面に落ちる音のしずく・光る波紋・鍵盤。カードの絵柄の代わりに「音の形」を描く。

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


/// ペアごとの波紋の形（並び順）と色（音の高さ）
struct PairStyle: Equatable {
    let shape: RippleShape
    let tint: Color

    static let shapes: [RippleShape] = [
        RippleShape(sides: 0), RippleShape(sides: 4, rotation: .pi / 4), RippleShape(sides: 6),
        RippleShape(sides: 0, petals: 5), RippleShape(sides: 3), RippleShape(sides: 4),
        RippleShape(sides: 0, petals: 4), RippleShape(sides: 5), RippleShape(sides: 8),
        RippleShape(sides: 0, petals: 6), RippleShape(sides: 3, rotation: .pi), RippleShape(sides: 0, petals: 3),
    ]

    static func of(_ index: Int, tint: Color) -> PairStyle {
        let i = ((index % shapes.count) + shapes.count) % shapes.count
        return PairStyle(shape: shapes[i], tint: tint)
    }

    static func of(_ index: Int, concept: Concept) -> PairStyle {
        of(index, tint: Palette.tint(of: concept))
    }

    static func == (lhs: PairStyle, rhs: PairStyle) -> Bool {
        lhs.shape.sides == rhs.shape.sides && lhs.shape.petals == rhs.shape.petals && lhs.shape.rotation == rhs.shape.rotation
    }
}

/// そろったペアの印：音の色で光る、同じ形の輪の 3 重
struct PairMark: View {
    let style: PairStyle
    var glow: CGFloat = 1

    var body: some View {
        ZStack {
            style.shape.fill(style.tint.opacity(0.16))
                .scaleEffect(0.92)
            ForEach(0..<3) { i in
                style.shape
                    .stroke(style.tint, lineWidth: i == 0 ? 1.8 : 1.1)
                    .scaleEffect(0.32 + CGFloat(i) * 0.29 * glow)
                    .opacity(1 - Double(i) * 0.28)
            }
            style.shape.fill(style.tint).scaleEffect(0.15)
        }
        .glow(style.tint, radius: 6, opacity: 0.55)
    }
}

/// めくったときに広がる波紋。答えが見た目で分からないよう、どの音でも同じ月明かりの色
struct ListeningRipple: View {
    let trigger: Int
    var tint: Color = Palette.glow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 1

    var body: some View {
        ZStack {
            // 静かな輪（波紋が消えたあとも「聞いている」と分かるように）
            ForEach(0..<2) { i in
                Circle()
                    .stroke(tint.opacity(0.28), lineWidth: 0.8)
                    .scaleEffect(x: 0.38 + CGFloat(i) * 0.3, y: (0.38 + CGFloat(i) * 0.3) * 0.86)
            }
            ForEach(0..<3) { i in
                let p = min(1, max(0, phase * 1.3 - CGFloat(i) * 0.18))
                Circle()
                    .stroke(tint, lineWidth: 1.5)
                    .scaleEffect(x: 0.18 + p * 0.95, y: (0.18 + p * 0.95) * 0.86)
                    .opacity(Double(1 - p) * 0.95)
            }
            Circle().fill(tint).frame(width: 7, height: 7)
        }
        .glow(tint, radius: 5, opacity: 0.6)
        .onChange(of: trigger) { _, _ in start() }
        .onAppear { start() }
    }

    private func start() {
        guard !reduceMotion, !Launch.isStill else { phase = 0.45; return }
        phase = 0
        withAnimation(.easeOut(duration: 1.1)) { phase = 1 }
    }
}

/// 伏せたカードの面：止まった夜の水面（楕円の波の跡と、月の映り）
struct StillWater: View {
    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width * 0.7, y: size.height * 0.76)
            for i in 1...4 {
                let r = CGFloat(i) * size.width * 0.16
                let rect = CGRect(x: c.x - r, y: c.y - r * 0.5, width: r * 2, height: r)
                context.stroke(Path(ellipseIn: rect), with: .color(Palette.glow.opacity(0.22 - Double(i) * 0.04)), lineWidth: 0.7)
            }
            // 月の映り（横に途切れる短い線）
            let mx = size.width * 0.3
            for j in 0..<3 {
                let y = size.height * (0.22 + CGFloat(j) * 0.07)
                let half = size.width * (0.09 - CGFloat(j) * 0.022)
                var p = Path()
                p.move(to: CGPoint(x: mx - half, y: y))
                p.addLine(to: CGPoint(x: mx + half, y: y))
                context.stroke(p, with: .color(Palette.moon.opacity(0.45 - Double(j) * 0.12)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

/// 鍵盤（結果で、そろえた音をその音の色で光らせる）。C4〜B5 の 2 オクターブ
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
                    let on = lit.contains(midi)
                    UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4, style: .continuous)
                        .fill(on ? Palette.pitch(midi) : Palette.ivory)
                        .frame(width: w - 1.5, height: h)
                        .glow(Palette.pitch(midi), radius: on ? 6 : 0, opacity: on ? 0.8 : 0)
                        .offset(x: CGFloat(i) * w)
                }
                ForEach(0..<(5 * octaves), id: \.self) { i in
                    let key = Self.blackOffsets[i % 5]
                    let midi = low + (i / 5) * 12 + key.0
                    let on = lit.contains(midi)
                    UnevenRoundedRectangle(bottomLeadingRadius: 2.5, bottomTrailingRadius: 2.5, style: .continuous)
                        .fill(on ? Palette.pitch(midi) : Palette.ebony)
                        .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 2.5, bottomTrailingRadius: 2.5, style: .continuous)
                            .stroke(Color.white.opacity(on ? 0 : 0.12), lineWidth: 0.6))
                        .frame(width: w * 0.58, height: h * 0.6)
                        .glow(Palette.pitch(midi), radius: on ? 6 : 0, opacity: on ? 0.9 : 0)
                        .offset(x: (CGFloat(i / 5) * 7 + CGFloat(key.1)) * w - w * 0.29 - 0.75)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 星の代わりの、月の金の小さな波紋（3 つ）
struct RippleStars: View {
    let count: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: size * 0.45) {
            ForEach(0..<3) { i in
                let on = i < count
                ZStack {
                    Circle().stroke(on ? Palette.moon : Palette.rule, lineWidth: 1)
                    Circle().fill(on ? Palette.moon : Color.clear).padding(size * 0.24)
                }
                .frame(width: size, height: size)
                .glow(Palette.moon, radius: on ? size * 0.3 : 0, opacity: on ? 0.6 : 0)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("星 \(count)"))
    }
}

/// アプリの印：夜の水面に、色の違う 3 つの波紋が重なる
struct EmblemView: View {
    var size: CGFloat = 120
    var trigger = 0

    var body: some View {
        ZStack {
            Circle().fill(
                RadialGradient(colors: [Palette.nightTop, Palette.nightBottom], center: .center, startRadius: 0, endRadius: size * 0.55)
            )
            Circle().stroke(Palette.rule, lineWidth: 1)
            ForEach(0..<3) { i in
                let colors = [Palette.pitch(60), Palette.pitch(64), Palette.pitch(67)]
                let offsets: [CGSize] = [CGSize(width: -0.12, height: 0.06), CGSize(width: 0.13, height: -0.05), CGSize(width: 0.02, height: 0.14)]
                ListeningRipple(trigger: trigger, tint: colors[i])
                    .frame(width: size * 0.62, height: size * 0.62)
                    .offset(x: offsets[i].width * size, y: offsets[i].height * size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// 夜の池：触ると、その場所の高さの音が鳴り、その音の色の波紋が広がる（ホームの主役）
/// 左ほど低く右ほど高い 5 音（ペンタトニック）なので、どこを触っても濁らない
struct NightPond: View {
    /// 置いておく静かな波紋（x, y は 0〜1、midi で色）
    struct Mark: Hashable { let x: CGFloat; let y: CGFloat; let midi: Int; let scale: CGFloat }
    struct Drop: Identifiable { let id = UUID(); let point: CGPoint; let midi: Int; let start: Date }

    var marks: [Mark]
    var onTouch: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drops: [Drop] = []

    static let scale = [60, 62, 64, 67, 69, 72, 74, 76, 79]
    static let life: Double = 2.2

    static func midi(atX x: CGFloat, width: CGFloat) -> Int {
        guard width > 0 else { return 60 }
        let i = Int((x / width) * CGFloat(scale.count))
        return scale[min(max(i, 0), scale.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: drops.isEmpty)) { timeline in
                Canvas { context, size in
                    // 月と、その映り
                    let moon = CGPoint(x: size.width * 0.62, y: size.height * 0.46)
                    let mr = min(size.width, size.height) * 0.07
                    context.fill(Path(ellipseIn: CGRect(x: moon.x - mr * 2.4, y: moon.y - mr * 2.4, width: mr * 4.8, height: mr * 4.8)), with: .color(Palette.moon.opacity(0.06)))
                    context.fill(Path(ellipseIn: CGRect(x: moon.x - mr, y: moon.y - mr, width: mr * 2, height: mr * 2)), with: .color(Palette.moon.opacity(0.9)))
                    for j in 0..<5 {
                        let y = size.height * (0.64 + CGFloat(j) * 0.07)
                        let half = mr * (1.6 - CGFloat(j) * 0.25)
                        var p = Path()
                        p.move(to: CGPoint(x: moon.x - half, y: y))
                        p.addLine(to: CGPoint(x: moon.x + half, y: y))
                        context.stroke(p, with: .color(Palette.moon.opacity(0.42 - Double(j) * 0.07)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    }
                    // 置いてある静かな波紋
                    for mark in marks {
                        let c = CGPoint(x: mark.x * size.width, y: mark.y * size.height)
                        ring(&context, at: c, radius: size.height * 0.36 * mark.scale, color: Palette.pitch(mark.midi), progress: 0.55, count: 4)
                    }
                    // 触って生まれた波紋
                    let now = timeline.date
                    for drop in drops {
                        let t = now.timeIntervalSince(drop.start) / Self.life
                        guard t >= 0, t < 1 else { continue }
                        ring(&context, at: drop.point, radius: size.height * 0.62, color: Palette.pitch(drop.midi), progress: CGFloat(t), count: 3)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let midi = Self.midi(atX: value.location.x, width: proxy.size.width)
                    onTouch(midi)
                    guard !reduceMotion else { return }
                    let drop = Drop(point: value.location, midi: midi, start: Date())
                    drops.append(drop)
                    if drops.count > 8 { drops.removeFirst(drops.count - 8) }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(Int(Self.life * 1000) + 100))
                        drops.removeAll { $0.id == drop.id }
                    }
                }
            )
        }
        .accessibilityElement()
        .accessibilityLabel(Text("夜の池"))
        .accessibilityHint(Text("触ると音が鳴ります"))
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    /// 楕円の輪を重ねる（水面を斜めから見た形）。progress 0→1 で広がって消える
    private func ring(_ context: inout GraphicsContext, at c: CGPoint, radius: CGFloat, color: Color, progress: CGFloat, count: Int) {
        for i in 0..<count {
            let p = min(1, max(0, progress * 1.25 - CGFloat(i) * 0.14))
            guard p > 0 else { continue }
            let r = radius * (0.12 + p * 0.88)
            let rect = CGRect(x: c.x - r, y: c.y - r * 0.38, width: r * 2, height: r * 0.76)
            let alpha = Double(1 - p) * 0.95
            var glow = context
            glow.addFilter(.blur(radius: 4))
            glow.stroke(Path(ellipseIn: rect), with: .color(color.opacity(alpha * 0.8)), lineWidth: 3)
            context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(alpha)), lineWidth: 1.2)
        }
        if progress < 0.7 {
            let d: CGFloat = 5
            context.fill(Path(ellipseIn: CGRect(x: c.x - d / 2, y: c.y - d * 0.19, width: d, height: d * 0.38)), with: .color(color.opacity(0.9)))
        }
    }
}
