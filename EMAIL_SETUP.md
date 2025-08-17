# メール通知設定ガイド

## Gmailでのメール通知設定手順

### 1. Gmailアプリパスワードの作成

1. [Googleアカウント設定](https://myaccount.google.com/security)にアクセス
2. 2段階認証を有効化（まだの場合）
3. 「アプリパスワード」をクリック
4. アプリ選択で「メール」、デバイス選択で「その他」を選択
5. 名前を「Shaka App」などと入力
6. 生成された16文字のパスワードをコピー（スペースなし）

### 2. Firebase環境変数の設定

ターミナルで以下のコマンドを実行：

```bash
# 管理者のメールアドレス（通知を受け取るアドレス）
firebase functions:config:set admin.email="your-email@example.com"

# Gmail送信用アカウント設定
firebase functions:config:set gmail.email="your-gmail@gmail.com"
firebase functions:config:set gmail.password="xxxx-xxxx-xxxx-xxxx"
```

例：
```bash
firebase functions:config:set admin.email="admin@example.com"
firebase functions:config:set gmail.email="shaka.notifications@gmail.com"
firebase functions:config:set gmail.password="abcd1234efgh5678"
```

### 3. 設定の確認

```bash
firebase functions:config:get
```

以下のような出力が表示されればOK：
```json
{
  "admin": {
    "email": "admin@example.com"
  },
  "gmail": {
    "email": "shaka.notifications@gmail.com",
    "password": "abcd1234efgh5678"
  }
}
```

### 4. Cloud Functionsの再デプロイ

```bash
firebase deploy --only functions:onReportCreated
```

## トラブルシューティング

### メールが届かない場合

1. **迷惑メールフォルダを確認**
   - 初回は迷惑メールに分類される可能性があります

2. **Gmailの「安全性の低いアプリ」設定**
   - 最新のGoogleアカウントではアプリパスワードが必須です
   - 通常のパスワードは使用できません

3. **Cloud Functionsのログを確認**
   ```bash
   firebase functions:log --only onReportCreated
   ```

4. **環境変数が正しく設定されているか確認**
   ```bash
   firebase functions:config:get
   ```

### エラーメッセージと対処法

- `Invalid login`: アプリパスワードが間違っています
- `Username and Password not accepted`: 2段階認証とアプリパスワードを確認
- `Timeout`: ネットワーク接続を確認

## 通知メールの内容

通報があると以下の情報がメールで送信されます：

- 通報ID
- 通報の種類（作品/質問/コメント/ユーザー）
- 通報理由
- 通報者名
- 対象のタイトル
- 詳細説明（ある場合）
- Firebase Consoleへの直接リンク

## セキュリティ上の注意

- アプリパスワードは絶対に公開しない
- Gitにコミットしない（環境変数として管理）
- 定期的にパスワードを更新することを推奨

## 代替案：SendGridの使用

より本格的なメール送信が必要な場合は、SendGridの使用を検討してください：

1. [SendGrid](https://sendgrid.com/)でアカウント作成
2. APIキーを生成
3. `@sendgrid/mail`パッケージをインストール
4. 環境変数にAPIキーを設定

SendGridは月100通まで無料で、配信率も高いです。