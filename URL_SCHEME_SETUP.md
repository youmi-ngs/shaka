# URL Scheme Setup for Shaka App

## Xcodeでの設定手順

### 1. URLスキーマの追加

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲータで「Shaka」プロジェクトを選択
3. 「TARGETS」から「Shaka」を選択
4. 「Info」タブを開く
5. 「URL Types」セクションを展開（なければ「+」ボタンで追加）
6. 以下の設定を追加：
   - **Identifier**: `com.youmi.shaka`
   - **URL Schemes**: `shaka`
   - **Role**: `Editor`

### 2. Info.plistへの追加（Alternative）

Info.plistに直接追加する場合：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>shaka</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.youmi.shaka</string>
    </dict>
</array>
```

## 使用方法

### 友達追加URLの形式

```
shaka://friend/add/{userId}
```

例：
```
shaka://friend/add/SRF0jsggzwMUmS4JTBpZYHZYUX82
```

### プロフィール表示URLの形式

```
shaka://friend/{userId}
```

### 作品表示URLの形式

```
shaka://work/{workId}
```

### 質問表示URLの形式

```
shaka://question/{questionId}
```

## テスト方法

1. **Simulator/実機でのテスト**
   - Safariを開く
   - URLバーに `shaka://friend/add/testUserId` を入力
   - アプリが起動し、友達追加の確認ダイアログが表示される

2. **共有機能のテスト**
   - プロフィール画面を開く
   - 「友達追加リンクを共有」ボタンをタップ
   - メッセージやメールで共有
   - 受信側でリンクをタップ
   - アプリが起動し、友達追加の確認が表示される

## 注意事項

- URLスキーマは他のアプリと重複しないように注意
- 将来的にはUniversal Linksの実装を検討（より安全）
- iOS 14以降では、他のアプリからURLスキーマを開く際に確認ダイアログが表示される場合がある

## トラブルシューティング

### URLが開かない場合

1. URLスキーマが正しく設定されているか確認
2. アプリをクリーンビルド（Cmd+Shift+K → Cmd+B）
3. シミュレータ/実機からアプリを削除して再インストール

### ディープリンクが処理されない場合

1. `ShakaApp.swift`の`onOpenURL`が呼ばれているか確認
2. `DeepLinkManager`のログを確認
3. URLのフォーマットが正しいか確認