# Shaka アプリ - デプロイメントガイド

## 🎯 実装概要

### 1. displayName同期機能
- **方式**: Cloud Functions (onUpdateトリガー)
- **SLA**: 5-30秒以内に全投稿へ反映
- **コスト**: 約$0.00002/更新

### 2. 画像読み込み改善
- **キャッシュ**: メモリキャッシュ実装
- **リトライ**: 3回まで自動リトライ
- **タイムアウト**: 30秒

## 📦 必要な準備

### Firebase CLIのインストール
```bash
npm install -g firebase-tools
firebase login
```

### プロジェクトの初期化
```bash
# プロジェクトルートで実行
firebase init functions

# 既存プロジェクトを選択
# JavaScriptを選択
# ESLintは任意
# 依存関係のインストール: Yes
```

## 🚀 Cloud Functionsのデプロイ

### 1. 依存関係のインストール
```bash
cd functions
npm install
```

### 2. 環境変数の設定（必要に応じて）
```bash
firebase functions:config:set backfill.secret="YOUR-SECRET-TOKEN"
```

### 3. デプロイ
```bash
# 全ての関数をデプロイ
firebase deploy --only functions

# 特定の関数のみ
firebase deploy --only functions:syncDisplayName
```

### 4. 動作確認
```bash
# ログの確認
firebase functions:log

# 特定の関数のログ
firebase functions:log --only syncDisplayName
```

## 🔄 既存データのバックフィル

### 方法1: Cloud Functions経由（推奨）

```bash
# バックフィル関数のURLを取得
firebase functions:list

# curlで実行（YOUR-SECRET-TOKENを設定済みの値に置き換え）
curl -H "Authorization: Bearer YOUR-SECRET-TOKEN" \
     https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/backfillDisplayNames
```

### 方法2: ローカルスクリプト

1. サービスアカウントキーを取得
```
Firebase Console → プロジェクト設定 → サービスアカウント → 新しい秘密鍵を生成
```

2. スクリプトを設定
```bash
# service-account-key.jsonを配置
cp ~/Downloads/your-service-account-key.json ./scripts/service-account-key.json

# スクリプトのパスを更新
# scripts/backfill_displaynames.js の9行目を編集
```

3. 実行
```bash
# ドライラン（変更なし、統計のみ）
node scripts/backfill_displaynames.js --dry-run

# 実際に実行
node scripts/backfill_displaynames.js
```

## 🖼 画像ローダーの導入

### Xcodeでの設定

1. `ImageLoader.swift`をプロジェクトに追加
2. ビルド設定でSwiftUIフレームワークが有効であることを確認
3. ビルド＆実行

### 使用方法

#### 既存のAsyncImageを置き換え
```swift
// Before
AsyncImage(url: post.imageURL) { ... }

// After
CachedAsyncImage(url: post.imageURL) {
    ProgressView()
}
```

## 📊 モニタリング

### Cloud Functionsのメトリクス
```bash
# Firebase Console
Firebase Console → Functions → ダッシュボード

# 重要メトリクス
- 実行回数
- エラー率
- 実行時間（中央値/95パーセンタイル）
- メモリ使用量
```

### 画像読み込みのデバッグ
```swift
// Xcodeコンソールで確認
🖼 ImageLoader: Loading from https://...
🖼 HTTP Status: 200
🖼 Downloaded: 245KB
🖼✅ Image loaded successfully

// エラー時
🖼❌ Load failed: timeout
🖼🔄 Retrying... (1/3)
```

## ✅ 受け入れ基準チェックリスト

### displayName同期
- [ ] プロフィールで名前を変更
- [ ] 30秒待つ
- [ ] 投稿一覧を更新（pull to refresh）
- [ ] 全投稿で新しい名前が表示される

### 画像表示
- [ ] 新規投稿で画像アップロード成功
- [ ] 投稿一覧で画像が表示される
- [ ] ネットワークオフ→オンで画像が再読み込みされる
- [ ] 大きい画像（5MB+）でもタイムアウトしない
- [ ] エラー時に「Retry」ボタンが表示される

## ⚠️ トラブルシューティング

### Functions がデプロイできない
```bash
# Node.jsバージョン確認（18推奨）
node --version

# package.jsonのenginesフィールドを確認
"engines": {
  "node": "18"
}
```

### 画像が表示されない
1. Storageルールを確認
2. ダウンロードURLの形式を確認（https://firebasestorage.googleapis.com/...）
3. Xcodeコンソールでエラーログを確認
4. ネットワーク接続を確認

### displayNameが更新されない
1. Cloud Functionsのログを確認
2. Firestoreのインデックスを確認
3. バッチサイズ（500）を超えていないか確認

## 💰 コスト見積もり

### Cloud Functions
- 呼び出し: $0.40 / 100万回
- 実行時間: $0.0000025 / GB-秒
- **月間見積もり**: 1000ユーザー、各10回更新 = $0.04

### Firestore
- 書き込み: $0.02 / 10万回
- **月間見積もり**: 10000投稿更新 = $0.02

### 合計
**月額約 $0.06**（最小規模）

## 📞 サポート

問題が発生した場合：
1. Firebaseコンソールのログを確認
2. Xcodeのコンソールログを確認
3. このガイドのトラブルシューティングを参照