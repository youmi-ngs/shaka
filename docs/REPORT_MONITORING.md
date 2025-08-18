# 通報モニタリング設定ガイド

## 通報の確認方法

### 1. Firebase Consoleで確認
1. [Firebase Console](https://console.firebase.google.com/project/shaka-shakatsu/firestore/data/~2Freports)にアクセス
2. `reports`コレクションを確認
3. 各通報の詳細：
   - `reporterId`: 通報したユーザーのID
   - `targetType`: 通報対象の種類（work/question/comment/user）
   - `targetId`: 通報対象のID
   - `reason`: 通報理由
   - `additionalDetails`: 詳細説明
   - `createdAt`: 通報日時
   - `status`: pending（未対応）/ reviewed（対応済み）

### 2. Cloud Functions ログで確認
通報があると自動的にログが記録されます：
1. [Cloud Functions ログ](https://console.cloud.google.com/functions/list?project=shaka-shakatsu)にアクセス
2. `onReportCreated`関数のログを確認
3. ログには以下が記録されます：
   - 通報ID
   - 通報の種類
   - 通報理由
   - 通報者名
   - 対象のタイトル
   - Firebase Consoleの直接リンク

### 3. 管理者通知コレクション
`admin_notifications`コレクションにも通報情報が保存されます（Firebase Consoleで確認可能）

## オプション：追加の通知設定

### Slack通知を設定する場合
1. Slack Incoming Webhookを作成
2. Firebase Functionsの環境変数を設定：
```bash
firebase functions:config:set slack.webhook_url="YOUR_SLACK_WEBHOOK_URL"
```
3. functions/index.jsのSlack通知部分のコメントを解除
4. 再デプロイ

### メール通知を設定する場合
Firebase ExtensionsのTrigger Emailを使用するか、SendGridなどのサービスと連携できます。

## 通報への対応

### 違反が確認された場合
1. Firebase Consoleで該当投稿を削除
   - `works`または`questions`コレクションから削除
2. 必要に応じてユーザーに警告
   - `users`コレクションに警告フラグを追加

### 虚偽の通報の場合
1. `reports`ドキュメントの`status`を`reviewed`に更新
2. 必要に応じて虚偽通報者に警告

## モニタリングのベストプラクティス
- 毎日Firebase Consoleをチェック
- Cloud Functionsのログを定期的に確認
- 重大な違反は即座に対応
- 通報パターンを分析して予防策を検討