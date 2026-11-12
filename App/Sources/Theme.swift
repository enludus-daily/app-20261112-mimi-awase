import SwiftUI

/// 色・書体・形はここだけで決める（StudyReel のトーン：淡い水色＋桃の差し色、細い線、弱い影）
enum Palette {
    // 地と文字
    static let mist = Color(hex: 0xF2F6F9)      // 画面の地（ほぼ白、わずかに青）
    static let paper = Color(hex: 0xFBFCFD)     // カードの面
    static let ink = Color(hex: 0x2C3845)       // 文字（真っ黒にしない）
    static let sub = Color(hex: 0x8A96A3)       // 補助の文字
    static let rule = Color(hex: 0xE1E7ED)      // 細い線

    // 主な色：水色（5 段階）
    static let sky = Color(hex: 0xA3C7E4)       // L0.77
    static let skySoft = Color(hex: 0xE2EDF6)
    static let skyDeep = Color(hex: 0x5A88B3)   // 白い文字を載せるボタン・小さな文字だけ
    static let skyPale = Color(hex: 0xF0F5FA)
    static let skyLine = Color(hex: 0xC7DCEC)

    // 差し色：桃
    static let peach = Color(hex: 0xF3BEA8)     // L0.81
    static let peachSoft = Color(hex: 0xFBEBE3)
    static let peachDeep = Color(hex: 0xC48669) // 連続・星の小さな文字

    /// ペアの色（水色と桃の段階だけ。虹色にしない）。形でも見分ける
    static let pairTints: [Color] = [
        Color(hex: 0xA3C7E4), Color(hex: 0xF3BEA8), Color(hex: 0xBCD6EB),
        Color(hex: 0xF6D2C2), Color(hex: 0x9FC0DA), Color(hex: 0xEDCDB9),
    ]

    static let shadow = Color(hex: 0x2C3845).opacity(0.07)
    static let shadowLift = Color(hex: 0x2C3845).opacity(0.14)
}

enum Typo {
    /// 見出しと数字（セリフ）
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// 小さなラベル（字間を開けて使う）
    static let label = Font.system(size: 11, weight: .medium)
    static let body = Font.system(size: 14)
    static let small = Font.system(size: 12)
}

enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 14
    static let l: CGFloat = 20
    /// カードの角は大きさに合わせる
    static func card(_ side: CGFloat) -> CGFloat { max(10, side * 0.18) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// 押すと少し沈むボタン
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 主なボタン（水色の濃い段階に白い文字）
struct PrimaryButtonLabel: View {
    let title: LocalizedStringKey
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .medium)) }
            Text(title)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(Capsule().fill(Palette.skyDeep))
    }
}

/// 控えめなボタン（線だけ）
struct QuietButtonLabel: View {
    let title: LocalizedStringKey
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 13)) }
            Text(title)
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Palette.skyDeep)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(Capsule().fill(Palette.paper))
        .overlay(Capsule().stroke(Palette.skyLine, lineWidth: 1))
    }
}

/// 小さな見出し（字間を開ける）
struct SectionLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(Typo.label)
            .kerning(0.8)
            .foregroundStyle(Palette.sub)
            .textCase(.uppercase)
    }
}
