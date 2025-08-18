# Push Notification Setup Guide for Shaka

## Prerequisites
- Apple Developer Account
- Firebase project configured
- Physical iOS device (simulator doesn't support push notifications)

## 1. Apple Developer Console Setup

### Create APNs Authentication Key
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles** → **Keys**
3. Click **+** to create a new key
4. Name it (e.g., "Shaka Push Notifications")
5. Check **Apple Push Notifications service (APNs)**
6. Click **Continue** then **Register**
7. Download the `.p8` file and save it securely
8. Note down:
   - **Key ID** (10 characters)
   - **Team ID** (found in Membership section)

### Verify App ID
1. Go to **Identifiers**
2. Find your app (Bundle ID should match Xcode)
3. Ensure **Push Notifications** capability is enabled

## 2. Firebase Console Setup

### Upload APNs Key
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your Shaka project
3. Navigate to **Project Settings** → **Cloud Messaging**
4. Under **Apple app configuration**, find your iOS app
5. Click **Upload** under **APNs Authentication Key**
6. Upload the `.p8` file
7. Enter:
   - **Key ID**: From Apple Developer Portal
   - **Team ID**: From Apple Developer Portal

## 3. Xcode Configuration

### Enable Push Notifications Capability
1. Open `Shaka.xcodeproj` in Xcode
2. Select the Shaka target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes**
   - Check **Remote notifications**

### Verify Bundle ID
- Ensure Bundle ID in Xcode matches Firebase and Apple Developer Portal

## 4. Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

This deploys the following notification triggers:
- `onWorkLiked` - Sends notification when someone likes a work
- `onQuestionLiked` - Sends notification when someone likes a question
- `onUserFollowed` - Sends notification when someone follows a user
- `onWorkCommented` - Sends notification when someone comments on a work
- `onQuestionCommented` - Sends notification when someone comments on a question

## 5. Test Push Notifications

### On Physical Device
1. Build and run the app on a physical iOS device
2. Accept notification permissions when prompted
3. Verify FCM token is saved to Firestore:
   - Check `users_private/{uid}/fcmTokens/{token}`
4. Test notifications:
   - Have another user like/comment/follow
   - Notification should appear even in foreground

### Debugging Tips
- Check Xcode console for FCM token logs
- Verify `.p8` file, Key ID, and Team ID are correct
- Check Firebase Functions logs:
  ```bash
  firebase functions:log
  ```
- Common issues:
  - Wrong Bundle ID
  - Expired or invalid APNs key
  - Missing capabilities in Xcode
  - Testing on simulator (use real device)

## 6. Notification Behavior

### Foreground
- Notifications display as banner with sound
- Handled by `NotificationManager`

### Background
- System displays notification
- Badge updates with unread count
- Tap to open specific content

### Data Structure
Notifications are stored in Firestore:
```
notifications/{userId}/items/{notificationId}
{
  type: 'like' | 'follow' | 'comment',
  actorUid: string,
  actorName: string,
  targetType?: 'work' | 'question',
  targetId?: string,
  message: string,
  snippet?: string,
  createdAt: timestamp,
  read: boolean
}
```

## 7. Troubleshooting

### No notifications received
1. Check device has internet connection
2. Verify notification permissions are granted
3. Check FCM token exists in Firestore
4. Review Cloud Functions logs for errors

### Invalid token errors
- Token might be expired or invalid
- App automatically cleans up invalid tokens

### Badge count incorrect
- Badge shows unread notification count
- Mark notifications as read to update badge

## Security Notes
- Never commit `.p8` file to repository
- Keep Key ID and Team ID secure
- FCM tokens are device-specific and private
- Only authenticated users can save tokens