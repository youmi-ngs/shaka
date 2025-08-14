# Firebase Cloud Messaging (FCM) Setup Guide

## Xcodeでの設定

### 1. Swift Package Managerで Firebase SDK を追加

1. Xcode でプロジェクトを開く
2. File → Add Package Dependencies...
3. 以下のURLを入力:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. Version を選択 (latest を推奨)
5. 以下のパッケージを選択:
   - FirebaseAuth (追加済み)
   - FirebaseFirestore (追加済み)
   - **FirebaseMessaging** ← これを追加
6. Add Package をクリック

### 2. AppDelegate.swift を修正

Firebase Messaging を使用する場合は、以下のように修正:

```swift
import FirebaseMessaging

// application(_:didFinishLaunchingWithOptions:) 内に追加
Messaging.messaging().delegate = self

// APNsトークン受信時
func application(_ application: UIApplication, 
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
}
```

### 3. MessagingDelegate を実装

```swift
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("FCM registration token: \(fcmToken)")
        // NotificationManager に FCM トークンを渡す
        NotificationManager.shared.saveFCMToken(fcmToken)
    }
}
```

## なぜ FCM を使うべきか？

### FCM の利点:
1. **クロスプラットフォーム対応** - iOS/Android で同じバックエンドコード
2. **トークン管理** - FCM が自動的にトークンの更新を管理
3. **分析機能** - Firebase Console で配信状況を確認可能
4. **トピック購読** - グループ通知が簡単
5. **条件付き配信** - セグメント別の通知が可能

### 現在の実装 (APNs直接) の制限:
1. iOS のみ対応
2. トークン管理を自前で実装する必要がある
3. Cloud Functions から直接 APNs に送信するには追加設定が必要
4. 分析機能なし

## Cloud Functions の修正

FCM を使う場合、Cloud Functions はそのまま使用可能です。
APNs を直接使う場合は、以下の修正が必要:

```javascript
// APNs 直接送信の場合 (非推奨)
const apn = require('apn');

// APNs Provider の設定
const apnProvider = new apn.Provider({
  token: {
    key: '.p8ファイルの内容',
    keyId: 'KEY_ID',
    teamId: 'TEAM_ID'
  },
  production: true
});

// 通知送信
const notification = new apn.Notification();
notification.alert = { title, body };
notification.badge = unreadCount;
notification.sound = 'default';
notification.topic = 'com.yourcompany.shaka'; // Bundle ID

await apnProvider.send(notification, apnsTokens);
```

## 推奨事項

本番環境では **FCM を使用することを強く推奨** します。
理由:
- セットアップが簡単
- メンテナンスが楽
- 将来的に Android 対応する際の移行が容易
- Firebase の他の機能との統合が簡単

## トラブルシューティング

### Module 'FirebaseMessaging' not found
→ Swift Package Manager で FirebaseMessaging を追加

### No FCM token received
→ APNs の設定を確認 (.p8 ファイル、Key ID、Team ID)

### Notifications not received
→ 実機でテスト（シミュレーターは不可）
→ Firebase Console で Cloud Messaging の設定を確認