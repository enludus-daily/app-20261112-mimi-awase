import SwiftUI

/// 色・書体・形はここだけで決める。
/// 世界：夜の水面と光る波紋（2026-11-16 作り直し）。深い藍〜黒の地に、音ごとに色の違う光。
/// ピアノの鍵盤の白（象牙）と黒を、ボタンと選択の差し色に使う。
enum Palette {
    // 夜の地（上が藍、下ほど黒）
    static let nightTop = Color(hex: 0x1C2A5C)     // 輝度 ≈ 44（撮影の「まっ黒」判定に掛からない明るさを上に残す）
    static let nightMid = Color(hex: 0x111A3D)
    static let nightBottom = Color(hex: 0x070B1C)

    // 月の光（文字と線）
    static let text = Color(hex: 0xE9EDF8)         // 本文。真っ白にしない
    static let sub = Color(hex: 0x8E9AC0)          // 補助
    static let rule = Color.white.opacity(0.12)    // 細い線
    static let glass = Color.white.opacity(0.06)   // 水面のガラスの板
    static let glassHi = Color.white.opacity(0.10)

    // 主な光：月明かりの水色（波紋・選択）
    static let glow = Color(hex: 0x8FD8F2)
    static let glowStrong = Color(hex: 0xC2ECFB)   // 暗い地の上の小さな文字・アイコン
    static let glowSoft = Color(hex: 0x8FD8F2).opacity(0.14)
    static let glowLine = Color(hex: 0x8FD8F2).opacity(0.38)

    // 月の金（星・連続・Pro の印。小さな点だけ）
    static let moon = Color(hex: 0xF4D990)
    static let moonSoft = Color(hex: 0xF4D990).opacity(0.16)

    // 鍵盤
    static let ivory = Color(hex: 0xEEF0F6)        // 白鍵：主なボタン・選択中
    static let ebony = Color(hex: 0x0A0E1E)        // 黒鍵：控えめなボタン
    static let ebonyText = Color(hex: 0x0D1328)    // 白鍵の上の文字

    static let shadow = Color.black.opacity(0.35)

    /// 音の高さの色。5 度の輪（C→G→D…）で色相を回す：
    /// 半音となり（いちばん取り違えやすい）ほど色がはっきり違い、5 度の仲間は近い色になる
    static func pitch(_ midi: Int) -> Color {
        Color(hue: pitchHue(midi), saturation: 0.52, brightness: 1.0)
    }

    /// 音の高さの色相（0〜1）。オクターブ違いは同じ色
    static func pitchHue(_ midi: Int) -> Double {
        let pc = ((midi % 12) + 12) % 12
        let fifths = (pc * 7) % 12
        return (0.56 + Double(fifths) / 12).truncatingRemainder(dividingBy: 1)
    }

    /// 音の概念の色（和音は根音、音程は上の音の高さ）
    static func tint(of concept: Concept) -> Color {
        switch concept {
        case .pitch(let m): pitch(m)
        case .pitchClass(let p): pitch(p)
        case let .chord(root, _): pitch(root)
        case .interval(let s): pitch(60 + s)
        }
    }
}

enum Typo {
    /// 見出しと大きな数字（細いサンセリフ。夜の静けさ）
    static func display(_ size: CGFloat, _ weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// 小さなラベル（楽譜の書き込みのような等幅。字間を開けて使う）
    static let label = Font.system(size: 10.5, weight: .medium, design: .monospaced)
    static let body = Font.system(size: 14)
    static let small = Font.system(size: 12)
}

enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 14
    static let l: CGFloat = 22
    /// カードの角は大きさに合わせる
    static func card(_ side: CGFloat) -> CGFloat { max(10, side * 0.2) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// 夜の水面の地：藍→黒のグラデーションに、横に流れるかすかな水の線
struct NightBackground: View {
    var lines = true

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.nightTop, Palette.nightMid, Palette.nightBottom], startPoint: .top, endPoint: .bottom)
            if lines {
                Canvas { context, size in
                    var y: CGFloat = size.height * 0.38
                    var i = 0
                    while y < size.height {
                        let inset = size.width * (0.08 + 0.1 * CGFloat(i % 3))
                        var p = Path()
                        p.move(to: CGPoint(x: inset, y: y))
                        p.addLine(to: CGPoint(x: size.width - inset * 1.4, y: y))
                        context.stroke(p, with: .color(.white.opacity(0.025)), lineWidth: 0.7)
                        y += 26 + CGFloat(i % 4) * 9
                        i += 1
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// 水面のガラスの板（パネル・カードの地）
struct GlassPanel: ViewModifier {
    var radius: CGFloat = Radius.l
    var stroke: Color = Palette.rule

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.glass))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(stroke, lineWidth: 1))
    }
}

extension View {
    func glassPanel(radius: CGFloat = Radius.l, stroke: Color = Palette.rule) -> some View {
        modifier(GlassPanel(radius: radius, stroke: stroke))
    }

    /// 光る（色の影を 2 重に）
    func glow(_ color: Color, radius: CGFloat = 8, opacity: Double = 0.7) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
            .shadow(color: color.opacity(opacity * 0.4), radius: radius * 2.2)
    }
}

/// 押すと少し沈むボタン（鍵盤のように下へ）
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 主なボタン：白鍵（象牙の面に黒い文字、下辺だけ厚い）
struct PrimaryButtonLabel: View {
    let title: LocalizedStringKey
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .medium)) }
            Text(title)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Palette.ebonyText)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.ivory)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: 0xA7AEC4))
                        .offset(y: 3)
                )
        )
        .glow(Palette.glow, radius: 10, opacity: 0.28)
    }
}

/// 控えめなボタン：黒鍵（黒い面に月の文字）
struct QuietButtonLabel: View {
    let title: LocalizedStringKey
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 13)) }
            Text(title)
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Palette.text)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ebony))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
    }
}

/// 小さな見出し（等幅・字間を開ける）
struct SectionLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(Typo.label)
            .kerning(1.4)
            .foregroundStyle(Palette.sub)
            .textCase(.uppercase)
    }
}

/// 丸いガラスのアイコンボタンの中身
struct GlassIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15))
            .foregroundStyle(Palette.glowStrong)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Palette.glassHi))
            .overlay(Circle().stroke(Palette.rule, lineWidth: 1))
    }
}
