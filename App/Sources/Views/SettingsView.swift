import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var reminderDenied = false
    @State private var restoreMessage: LocalizedStringKey?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $model.notation) {
                        Text("ドレミ").tag(Notation.solfege)
                        Text(verbatim: "C D E").tag(Notation.letters)
                    } label: {
                        Text("音の名前")
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: $model.showNames) { Text("そろったカードに音の名前を出す") }
                } header: {
                    Text("書き方")
                } footer: {
                    Text("ドレミで覚えるか、C D E で覚えるかを選べます。")
                }

                Section {
                    ForEach(Timbre.allCases) { timbre in
                        Button {
                            if timbre.isPro && !model.isPro {
                                model.activeSheet = .paywall(.timbre)
                            } else {
                                model.timbre = timbre
                                model.synth.play(.chord(root: 60, quality: .major, inversion: 0))
                            }
                        } label: {
                            HStack {
                                Text(verbatim: timbre.name(japanese: model.japanese))
                                    .foregroundStyle(Palette.ink)
                                if timbre.isPro && !model.isPro {
                                    Text(verbatim: "Pro")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Palette.peachDeep)
                                }
                                Spacer()
                                if model.timbre == timbre {
                                    Image(systemName: "checkmark").foregroundStyle(Palette.skyDeep)
                                }
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.1").foregroundStyle(Palette.sub)
                        Slider(value: $model.volume, in: 0.15...1, onEditingChanged: { editing in
                            if !editing { model.synth.play(.note(69)) }
                        })
                        Image(systemName: "speaker.wave.3").foregroundStyle(Palette.sub)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("音の大きさ"))
                } header: {
                    Text("音")
                } footer: {
                    Text("音はその場で合成しています。消音スイッチがオンでも鳴ります（音そのものが遊びの入力のため）。")
                }

                Section {
                    Toggle(isOn: $model.hapticsOn) { Text("振動") }
                    Toggle(isOn: Binding(
                        get: { model.reminderOn },
                        set: { on in
                            Task {
                                await model.setReminder(on)
                                reminderDenied = on && !model.reminderOn
                            }
                        }
                    )) {
                        Text("今日の盤のお知らせ（20:00）")
                    }
                    if reminderDenied {
                        Button("通知が許可されていません。設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .font(.system(size: 13))
                    }
                } header: {
                    Text("手ざわり")
                }

                Section {
                    if model.isPro {
                        Label { Text("Pro を使っています。ありがとうございます。") } icon: { Image(systemName: "checkmark.seal") }
                            .foregroundStyle(Palette.skyDeep)
                    } else {
                        Button {
                            model.activeSheet = .paywall(.settings)
                        } label: {
                            Text("Pro でできること")
                        }
                    }
                    Button("購入を復元") {
                        Task {
                            await model.purchases.restore()
                            restoreMessage = model.isPro ? "Pro を復元しました" : "復元できる購入が見つかりませんでした"
                        }
                    }
                    if let restoreMessage {
                        Text(restoreMessage).font(.system(size: 12)).foregroundStyle(Palette.sub)
                    }
                } header: {
                    Text(verbatim: "Pro")
                }

                Section {
                    Button("はじめての盤をもう一度") { model.resetTutorial() }
                    Link(destination: URL(string: "https://github.com/enludus-daily/app-20261112-mimi-awase/blob/main/PRIVACY.md")!) {
                        Text("プライバシーポリシー")
                    }
                } header: {
                    Text("そのほか")
                } footer: {
                    Text("記録はこの iPhone の中だけに残ります。外へ送ることはありません。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.mist.ignoresSafeArea())
            .navigationTitle(Text("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("main.closeSettings")
                }
            }
        }
        .tint(Palette.skyDeep)
    }
}
