import SwiftUI

/// 最初の 1 枚：何のアプリかを 1 画面で伝え、すぐに 4 枚の盤を遊ぶ
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var tick = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            VStack(spacing: 22) {
                EmblemView(size: 150, trigger: tick)
                    .onTapGesture {
                        tick += 1
                        model.synth.play(.note(67))
                    }
                VStack(spacing: 10) {
                    Text("音だけの、神経衰弱")
                        .font(Typo.display(30, .light))
                        .foregroundStyle(Palette.text)
                        .multilineTextAlignment(.center)
                    Text("カードには絵がありません。めくると音が鳴ります。同じ音を耳だけで見つけて、2 枚そろえます。")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.sub)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 10) {
                    point("ear", "遊ぶうちに、音の高さを聞き分ける耳が育ちます")
                    point("waveform.path", "同じ音 → オクターブ → 和音 → 音程の順に進みます")
                    point("speaker.wave.1", "イヤホンなしでも遊べます。音量は小さめから")
                }
                .padding(16)
                .glassPanel(radius: Radius.m)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 520)
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .background(NightBackground())
        .safeAreaInset(edge: .bottom) {
            Button {
                model.startTutorial()
            } label: {
                PrimaryButtonLabel(title: "4 枚の盤で試す", systemImage: "play.fill")
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("main.start")
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 520)
        }
    }

    private func point(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Palette.glowStrong)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
