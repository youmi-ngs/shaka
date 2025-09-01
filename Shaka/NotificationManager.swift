//
//  NotificationManager.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import UserNotifications
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging

/// プッシュ通知を管理するクラス
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private let db = Firestore.firestore()
    @Published var isNotificationEnabled = false
    @Published var fcmToken: String?
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    /// 通知の初期設定
    private func setupNotifications() {
        // 通知デリゲート設定
        UNUserNotificationCenter.current().delegate = self
        
        // 現在の通知許可状態を確認
        checkNotificationStatus()
    }
    
    /// 通知許可状態を確認
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isNotificationEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// 通知許可をリクエスト
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error = error {
                return
            }
            
            DispatchQueue.main.async {
                self?.isNotificationEnabled = granted
                if granted {
                    // APNs登録
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                }
            }
        }
    }
    
    /// FCMトークンをFirestoreに保存
    func saveFCMToken(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        let tokenData: [String: Any] = [
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users_private")
            .document(uid)
            .collection("fcmTokens")
            .document(token)
            .setData(tokenData) { error in
                if let error = error {
                } else {
                }
            }
        
        // ローカルに保存
        self.fcmToken = token
    }
    
    /// FCMトークンを削除（サインアウト時）
    func deleteFCMToken() {
        guard let uid = Auth.auth().currentUser?.uid,
              let token = fcmToken else { return }
        
        db.collection("users_private")
            .document(uid)
            .collection("fcmTokens")
            .document(token)
            .delete { error in
                if let error = error {
                } else {
                }
            }
    }
    
    /// FCMトークンを強制的にリフレッシュ
    func refreshFCMToken() {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        // 古いトークンをすべて削除
        db.collection("users_private")
            .document(uid)
            .collection("fcmTokens")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    return
                }
                
                // すべての古いトークンを削除
                snapshot?.documents.forEach { doc in
                    doc.reference.delete()
                }
                
                
                // 新しいトークンを要求
                Messaging.messaging().deleteToken { error in
                    if let error = error {
                    }
                    
                    // 新しいトークンを取得
                    Messaging.messaging().token { token, error in
                        if let error = error {
                        } else if let token = token {
                            self?.saveFCMToken(token)
                        }
                    }
                }
            }
    }
    
    /// プッシュ通知の設定状態を確認
    func checkPushNotificationSetup() -> String {
        var status = "Push Notification Setup Status:\n"
        
        // 1. 通知許可状態
        status += "1. Permission: \(isNotificationEnabled ? "✅ Granted" : "❌ Not granted")\n"
        
        // 2. FCMトークン
        if let token = fcmToken {
            status += "2. FCM Token: ✅ Active (\(token.prefix(20))...)\n"
        } else {
            status += "2. FCM Token: ❌ Not available\n"
        }
        
        // 3. APNsトークン（今後の確認用）
        status += "3. APNs: ⚠️ Check Xcode console for APNs token\n"
        
        return status
    }
    
    /// 通知タップ時の処理
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // 通知のタイプに応じて画面遷移
        guard let type = userInfo["type"] as? String else { return }
        
        
        switch type {
        case "like":
            if let targetType = userInfo["targetType"] as? String,
               let targetId = userInfo["targetId"] as? String {
                handleLikeNotification(targetType: targetType, targetId: targetId)
            }
            
        case "follow":
            if let actorUid = userInfo["actorUid"] as? String {
                handleFollowNotification(actorUid: actorUid)
            }
            
        case "comment":
            if let targetType = userInfo["targetType"] as? String,
               let targetId = userInfo["targetId"] as? String {
                handleCommentNotification(targetType: targetType, targetId: targetId)
            }
            
        default:
            break
        }
    }
    
    private func handleLikeNotification(targetType: String, targetId: String) {
        // 投稿詳細画面に遷移
        // DeepLinkManagerを使って遷移（実装済みの場合）
    }
    
    private func handleFollowNotification(actorUid: String) {
        // プロフィール画面に遷移
        // DeepLinkManagerを使って遷移（実装済みの場合）
    }
    
    private func handleCommentNotification(targetType: String, targetId: String) {
        // 投稿詳細画面に遷移
        // DeepLinkManagerを使って遷移（実装済みの場合）
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    /// フォアグラウンドで通知を受信した時の表示設定
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // フォアグラウンドでも通知を表示（バッジなし）
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    /// 通知をタップした時
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        handleNotification(userInfo)
        completionHandler()
    }
}