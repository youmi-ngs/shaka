# Shaka - Photography Social Network for Shutterbug / 写真愛好家のためのSNS

[English](#english) | [日本語](#japanese)

---

<a name="english"></a>
## English

Shaka is a social networking app designed for photography enthusiasts to share their work and connect with other photographers.

### Features

#### Core Features
- 📸 **Work Posts** - Share your photography with detailed metadata (location, camera settings, date)
- ❓ **Question Posts** - Ask questions to the community with optional image attachments
- 💬 **Comments** - Engage in discussions on posts
- ❤️ **Likes & Bookmarks** - Show appreciation and save posts for later
- 👥 **Follow System** - Follow photographers you admire
- 🔍 **Search** - Find posts by title, tags, or users
- 🚨 **Report System** - Report inappropriate content with email notifications to admins
- 🔔 **Push Notifications** - Get notified about likes, comments, and follows
- 📍 **Location Sharing** - Share real-time location with mutual followers
- 📱 **Live Activities** - Track location sharing status on lock screen (iOS 16.2+)

#### Safety & Security
- 🔒 Comprehensive Firebase security rules
- 📜 Terms of Service and Privacy Policy
- ✉️ Real-time email notifications for reported content (sent to admin)
- 🛡️ Anonymous authentication with Apple ID linking

### Tech Stack

- **Frontend**: SwiftUI
- **Backend**: Firebase (Firestore, Storage, Auth, Functions)
- **Email Service**: Nodemailer with Gmail SMTP

### Upcoming Features

- 🎨 **UI Improvements** - Enhanced user interface design
- 🚀 **Performance Optimization** - App performance improvements
- 🌐 **Multi-language Support** - Support for multiple languages
- 🗺️ **Advanced Map Features** - Heatmaps, photo clustering on map

### Setup

1. Clone the repository
2. Install Firebase CLI: `npm install -g firebase-tools`
3. Add your `GoogleService-Info.plist` to the Shaka folder
4. Run `npm install` in the functions directory
5. Configure Firebase project settings
6. Deploy Firebase rules and functions

---

<a name="japanese"></a>
## 日本語

Shakaは写真愛好家が作品を共有し、他の写真家とつながるためのソーシャルネットワーキングアプリです。

### 機能

#### 主要機能
- 📸 **作品投稿** - 位置情報、カメラ設定、撮影日などの詳細メタデータと共に写真を共有
- ❓ **質問投稿** - コミュニティに質問を投稿（画像添付可能）
- 💬 **コメント** - 投稿にコメントして議論に参加
- ❤️ **いいね＆ブックマーク** - 投稿への評価と後で見るための保存
- 👥 **フォローシステム** - 気に入った写真家をフォロー
- 🔍 **検索** - タイトル、タグ、ユーザーで投稿を検索
- 🚨 **通報システム** - 不適切なコンテンツを通報（管理者へメール通知）
- 🔔 **プッシュ通知** - いいね、コメント、フォローの通知を受け取る
- 📍 **位置情報共有** - 相互フォロワーとリアルタイム位置情報を共有
- 📱 **Live Activity** - ロック画面で位置情報共有状態を表示（iOS 16.2以降）

#### 安全性とセキュリティ
- 🔒 包括的なFirebaseセキュリティルール
- 📜 利用規約とプライバシーポリシー
- ✉️ 通報されたコンテンツのリアルタイムメール通知（管理者へ送信）
- 🛡️ 匿名認証とApple IDリンク機能

### 技術スタック

- **フロントエンド**: SwiftUI
- **バックエンド**: Firebase (Firestore, Storage, Auth, Functions)
- **メールサービス**: Nodemailer（Gmail SMTP）

### 今後実装予定の機能

- 🎨 **UI改善** - ユーザーインターフェースの向上
- 🚀 **パフォーマンス最適化** - アプリ動作の高速化
- 🌐 **多言語対応** - 複数言語のサポート
- 🗺️ **高度な地図機能** - ヒートマップ、地図上の写真クラスタリング

### セットアップ

1. リポジトリをクローン
2. Firebase CLIをインストール: `npm install -g firebase-tools`
3. `GoogleService-Info.plist`をShakaフォルダに追加
4. functionsディレクトリで`npm install`を実行
5. Firebaseプロジェクト設定を構成
6. Firebaseルールと関数をデプロイ

---

## Project Structure / プロジェクト構造

```
Shaka/
├── Shaka/              # iOS app source code / iOSアプリソースコード
├── ShakaWidget/        # Widget Extension for Live Activities
├── functions/          # Firebase Cloud Functions
├── firestore.rules     # Firestore security rules / Firestoreセキュリティルール
├── storage.rules       # Storage security rules / Storageセキュリティルール
├── docs/               # Documentation / ドキュメント
└── firebase.json       # Firebase configuration / Firebase設定
```

## Version / バージョン

Current Version: 1.0  
- Build 10: Latest - Location sharing with Live Activities
- Build 9: TestFlight - UI improvements  
- Build 8: Production release  

現在のバージョン: 1.0  
- ビルド10: 最新 - 位置情報共有とLive Activity機能
- ビルド9: TestFlight - UI改善  
- ビルド8: 本番リリース

## License / ライセンス

Private project - All rights reserved  
プライベートプロジェクト - All rights reserved

## Authors / 作者

- Youmi Nagase

### AI Assistants / AIアシスタント
- Claude (Anthropic)
- ChatGPT (OpenAI)
