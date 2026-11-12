# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.005 |
| アプリ名 | みみ合わせ：音の神経衰弱 / Ear Pairs: Pitch Memory |
| サポート URL | https://github.com/enludus-daily/app-20261112-mimi-awase/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261112-mimi-awase/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」の見込み（暴力・性的・ギャンブル・Web 閲覧・生成 AI・ユーザー同士の交流なし）→ 4+ |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：効果音・占い・単純なタイマーではなく、60 段階・判定・記録を持つ聞き分けのゲーム
- 既存のアプリとの意味のある違い：既存の音感アプリは問題に答える形。みみ合わせは「音だけの神経衰弱」で、記憶と聞き分けを同時に使い、取り違えた音が次の盤に出る
- 長く使える価値（4.2）：毎日かわる今日の盤、60 段階、取り違えの記録で、使うほど自分の苦手に合った盤になる
- 他社の名前・商標・見た目を使っていないか：使っていない（音はその場で合成、絵は自作の Shape）
- Apple Intelligence：使わない

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro ¥480（`com.enludus.daily.005.pro`、App 内課金。初めての審査はアプリと一緒に出す）
- 理由と比べた表・勝算の表：README の「課金」
- 審査の危険：消音スイッチでも音が鳴る（`.playback`＋`mixWithOthers`）。音そのものが遊びの入力のため。設定に説明を書いた
- 通知はオプトイン（設定でオンにしたときだけ許可を聞く）

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
