# Shaka データモデル移行ガイド

## 概要
このガイドでは、Shakaアプリのユーザーデータを新しい public/private/stats 構造に移行する手順を説明します。

## 前提条件
- Node.js v14以上がインストールされていること
- Firebase CLIがインストールされていること (`npm install -g firebase-tools`)
- Firebase Admin SDKの認証情報を持っていること

## 移行手順

### 1. 準備

#### 1.1 サービスアカウントキーの取得
```bash
# Firebase Console にアクセス
# Project Settings > Service Accounts > Generate New Private Key
# ダウンロードしたファイルを service-account-key.json として保存
cp ~/Downloads/shaka-shakatsu-*.json ./service-account-key.json
```

#### 1.2 依存関係のインストール
```bash
cd scripts
npm install
```

#### 1.3 現在のデータのバックアップ（Firebase Console経由）
```bash
# Firestore データのエクスポート
firebase firestore:export gs://shaka-shakatsu-backup/$(date +%Y%m%d-%H%M%S) --project shaka-shakatsu

# または、スクリプトによるJSONバックアップ（ドライラン時に自動実行）
npm run backfill:dry
```

### 2. ドライラン実行

**重要**: 本番環境での実行前に必ずドライランを実行してください。

```bash
# ドライランモードで実行（実際の変更は行われません）
npm run backfill:dry

# 出力例：
# 🚀 Starting user data backfill...
# Mode: DRY RUN
# 📦 Starting backup...
# ✅ Backup saved to: backup-users-1234567890.json
# 📊 Found 42 users to process
# 🔐 Fetching Auth users...
# 📊 Found 45 Auth users
# 
# 📝 Processing batch 1/1
# ✨ Processing abc123def456:
#    displayName: John Doe
#    stats: works=5, questions=3
# ⏭  Skipping xyz789uvw012 (already migrated)
# ...
# 
# ==========================================
# 📊 RESULTS:
# ✅ Success: 38 users
# ⏭  Skipped: 3 users (already migrated)
# ❌ Failed: 1 users
# 
# ⚠️  DRY RUN COMPLETE - No changes were made
```

### 3. 本番実行

ドライランで問題がないことを確認したら、本番実行を行います。

```bash
# 本番モードで実行
npm run backfill:prod

# 実行時間の目安：
# - 100ユーザー: 約1分
# - 1,000ユーザー: 約10分
# - 10,000ユーザー: 約90分
```

### 4. Firestore ルールのデプロイ

```bash
# 新しいルールをバックアップ
cp firestore.rules firestore.rules.backup

# 新しいルールを適用
cp firestore.rules.new firestore.rules

# ルールのテスト
firebase emulators:start --only firestore

# 本番環境にデプロイ
firebase deploy --only firestore:rules

# Storage ルールもデプロイ
firebase deploy --only storage:rules
```

### 5. アプリケーションの更新

#### 5.1 Xcodeプロジェクトにファイルを追加
1. Xcodeを開く
2. Shaka グループを右クリック > "Add Files to Shaka..."
3. 以下のファイルを追加：
   - UserProfile.swift
   - UserProfileViewModel.swift
   - UserProfileEditView.swift
   - UserProfileView.swift

#### 5.2 既存コードの更新
```swift
// AuthManager.swift の getDisplayName() メソッドを更新
func getDisplayName() -> String {
    // 新しい構造から取得するように変更
    // 実装は UserProfileViewModel を参照
}
```

### 6. 検証

#### 6.1 コンソールでの検証
```javascript
// Firebase Console > Firestore > users コレクションで確認
// 各ドキュメントが以下の構造になっていることを確認：
{
  public: {
    displayName: "User Name",
    photoURL: "https://...",
    bio: "...",
    links: { website: "...", instagram: "...", github: "..." }
  },
  private: {
    joinedAt: Timestamp,
    email: "user@example.com"
  },
  stats: {
    worksCount: 5,
    questionsCount: 3
  }
}
```

#### 6.2 アプリでの検証
1. アプリを起動
2. プロフィール画面を開く
3. 編集機能をテスト
4. 他人のプロフィールを表示（private情報が見えないことを確認）

### 7. ロールバック手順（必要な場合）

問題が発生した場合のロールバック手順：

```bash
# 1. 古いルールに戻す
cp firestore.rules.backup firestore.rules
firebase deploy --only firestore:rules

# 2. バックアップからデータを復元
# Firebase Console > Firestore > Import/Export から復元
# または、作成されたJSONバックアップから手動で復元

# 3. アプリを以前のバージョンに戻す
git checkout HEAD~1
```

## トラブルシューティング

### エラー: "Missing or insufficient permissions"
- Firestore ルールが正しくデプロイされているか確認
- サービスアカウントに適切な権限があるか確認

### エラー: "displayName cannot be empty"
- バックフィルスクリプトがデフォルト値を設定するはずですが、手動で修正が必要な場合：
```javascript
// Firebase Console のCloud Shell で実行
const batch = db.batch();
const snapshot = await db.collection('users').where('public.displayName', '==', '').get();
snapshot.forEach(doc => {
  batch.update(doc.ref, {
    'public.displayName': `User_${doc.id.substring(0, 6)}`
  });
});
await batch.commit();
```

### パフォーマンスの問題
- BATCH_SIZE を小さくする（scripts/backfill-users.js の14行目）
- RATE_LIMIT_DELAY を大きくする（15行目）

## Cloud Functions による自動統計更新（オプション）

将来的に統計を自動更新したい場合は、以下のCloud Functionsをデプロイ：

```bash
# functions/index.js に statsUpdateFunction の内容を追加
# その後：
firebase deploy --only functions
```

## セキュリティ考慮事項

1. **バックアップファイルの取り扱い**
   - backup-users-*.json ファイルには個人情報が含まれます
   - 移行完了後は安全に削除するか、暗号化して保管してください

2. **サービスアカウントキー**
   - service-account-key.json は絶対にGitにコミットしないでください
   - .gitignore に追加済みであることを確認してください

3. **アクセス制御**
   - 新しいルールでは private.* フィールドは本人のみアクセス可能
   - public.* フィールドは全員がアクセス可能
   - stats.* は読み取りのみ可能（クライアントからの更新不可）

## サポート

問題が発生した場合は、以下の情報とともに報告してください：
- エラーメッセージ全文
- 実行したコマンド
- backup-users-*.json のユーザー数
- Firebase Console のスクリーンショット（個人情報は隠す）