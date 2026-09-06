# SRBTCG - プロジェクト固有指示書

## 📌 共通ルール

全プロジェクト共通のルールは `~/.claude/CLAUDE.md` にあり、自動で読み込まれる。
共通スキルは `~/.claude/skills/` にある。

このファイルには**このプロジェクト固有の内容だけ**を書く。

---

## 🎯 このプロジェクト固有の設定

### プロジェクト概要
バイトチームコンテスト（サーモンラン）ガイドアプリ。
Wave管理とSTT（Speech to Text）機能を搭載。

### 技術スタック
- **UI**: SwiftUI
- **最小OS**: iOS 17.0
- **アーキテクチャ**: MVVM
- **状態管理**: @Observable マクロ
- **音声認識**: Speech Framework (STT)
- **音声合成**: AVFoundation (TTS)
- **広告**: Google AdMob
- **課金**: StoreKit 2

### プロジェクト構造
```
SRBTCG/
├── SRBTCGApp.swift              # エントリポイント
├── Views/                       # UI画面
│   ├── HomeView.swift          # タブ切り替えホーム
│   ├── MainView.swift          # リスト一覧
│   ├── WaveListView.swift      # Wave詳細
│   ├── PlaybackView.swift      # 再生画面
│   ├── SalmonRunGuideView.swift # ガイド画面
│   ├── SettingsView.swift      # 設定画面
│   ├── LanguageSelectView.swift # 言語選択
│   └── Components/
│       └── SphericalButton.swift # 球体ボタン
├── Models/                      # データモデル
├── ViewModels/                  # ビューモデル
├── Services/                    # サービス層
│   ├── PurchaseManager.swift   # 課金管理
│   ├── AdManager.swift         # 広告管理
│   ├── STTManager.swift        # 音声認識
│   ├── TTSManager.swift        # 音声合成
│   └── DataManager.swift       # データ管理
└── Utils/                       # ユーティリティ
    ├── AppColors.swift          # カラーテーマ
    ├── AppStrings.swift         # ローカライズ
    ├── DateUtil.swift           # 日付処理
    └── LiquidGlassEffects.swift # ビジュアルエフェクト
```

### カラーテーマ（サーモンラン風）
```swift
primary: #FF9600     // サーモンランオレンジ
accent: #3BC335      // クマサン商会グリーン
background: #1A1A2E  // イカスミブラック
surface: #2D4739     // インクグリーン濃
golden: #FFB800      // 金イクラゴールド
```

### 課金商品設定
```swift
// 商品ID
stt_export: "STT+Export機能" // ¥160
ad_free: "広告非表示"        // ¥320
premium_bundle: "プレミアムバンドル" // ¥400
```

### プロジェクト固有のビルドコマンド
```bash
# ビルド
xcodebuild build -project SRBTCG.xcodeproj \
  -scheme SRBTCG \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# アーカイブ（リリース用）
xcodebuild archive -project SRBTCG.xcodeproj \
  -scheme SRBTCG \
  -archivePath ./build/SRBTCG.xcarchive
```

### 多言語対応
- 日本語 (ja)
- 英語 (en)
- 韓国語 (ko)
- 中国語簡体字 (zh-Hans)

### 特有の機能
1. **STT（音声認識）**: Wave終了時の結果を音声で入力
2. **TTS（音声合成）**: Wave情報を音声で読み上げ
3. **バックグラウンド再生**: プレイ中も動作継続
4. **データエクスポート**: CSV形式でデータ出力

### デバッグ設定
```swift
#if DEBUG
// デバッグ用の課金解除
purchaseManager.unlockAllForDebug()
// テスト広告ID使用
AdManager.useTestAds = true
#endif
```

### 注意事項
- 音声認識の権限リクエスト必須
- バックグラウンド音声再生の設定確認
- App Store申請時は広告IDを本番に切り替え
- 多言語対応のテスト必須

### デプロイチェックリスト
詳細は `DEPLOYMENT_CHECKLIST.md` を参照

### よくある問題
1. **STTが動作しない**: マイク権限の確認
2. **TTSが聞こえない**: サイレントモードの確認
3. **課金が反映されない**: Sandboxアカウントの確認