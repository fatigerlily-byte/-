# おじさんウォッチ iOS版

## Xcode セットアップ手順

1. **Xcode を開く**（14.0 以上推奨）
2. **新規プロジェクト作成**
   - File → New → Project → iOS → App
   - Product Name: `OjisanWatch`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Minimum Deployments: **iOS 15.0**
3. **ファイルを追加**
   - `OjisanWatch/` フォルダ内の Swift ファイルを全てプロジェクトへドラッグ
   - 既存の `ContentView.swift` と `OjisanWatchApp.swift` は上書き
4. **ビルド & 実行**

## iOS 版の制約について

| 機能                          | Android 版 | iOS 版 |
|-------------------------------|-----------|--------|
| 他アプリの上にオーバーレイ      | ✅ 可能   | ❌ 不可（OS制限）|
| アプリ内でスワイプ検知          | ✅        | ✅    |
| 視聴時間の計測                  | ✅        | ✅（アプリ内） |
| 他アプリの監視（Screen Time）   | ✅        | △ 要Apple審査 |

### iOS での TikTok/YouTube 監視を実現するには

Apple の `FamilyControls` フレームワーク（Screen Time API）を使うことで
実際の動画アプリの使用を監視・制限できます。ただし、以下が必要です：

1. Apple Developer Program への加入（年間 $99）
2. `com.apple.developer.family-controls` エンタイトルメントを Apple に申請
3. `DeviceActivity` + `ManagedSettings` フレームワークの実装

これらを実装すると、TikTok の利用時間が一定を超えた際に
「おじさんブロック画面」を表示することが可能です。

## ファイル構成

```
OjisanWatch/
├── OjisanWatchApp.swift       # アプリエントリーポイント
├── ContentView.swift          # 全体の ZStack 構成 + 警告オーバーレイ
├── Models/
│   └── VideoItem.swift        # 動画データモデル + サンプルデータ
├── Managers/
│   └── ScoreManager.swift     # 中毒度スコア計算 (ObservableObject)
└── Views/
    ├── VideoFeedView.swift    # TikTok 風縦スワイプフィード
    ├── VideoCardView.swift    # 個別動画カード
    ├── OjisanFaceView.swift   # Canvas でおじさん顔を描画
    ├── OjisanPeekView.swift   # 左端から侵食するオーバーレイ
    └── StatsBarView.swift     # 統計バー（時間・スワイプ数・中毒度）
```
