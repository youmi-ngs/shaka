//
//  NotificationManager.swift
//  Shaka
//
//  Created by Assistant on 2025/01/14.
//

import Foundation
import UserNotifications
import FirebaseFirestore
import FirebaseAuth

/// プッシュ通知を管理するクラス
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private let db = Firestore.firestore()
    @Published var isNotificationEnabled = false
    @Published var apnsToken: String?
    private var apnsTokenData: Data?
    
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            if let error = error {
                print("❌ Error requesting notification permission: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.isNotificationEnabled = granted
                if granted {
                    // APNs登録
                    UIApplication.shared.registerForRemoteNotifications()
                    print("✅ Notification permission granted")
                } else {
                    print("⚠️ Notification permission denied")
                }
            }
        }
    }
    
    /// APNsトークンを処理
    func handleAPNsToken(_ tokenData: Data) {
        self.apnsTokenData = tokenData
        
        // トークンを文字列に変換
        let tokenParts = tokenData.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.apnsToken = token
        
        // Firestoreに保存
        saveAPNsToken(token)
    }
    
    /// APNsトークンをFirestoreに保存
    private func saveAPNsToken(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in, cannot save APNs token")
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
                    print("❌ Failed to save APNs token: \(error)")
                } else {
                    print("✅ APNs token saved successfully")
                }
            }
    }
    
    /// APNsトークンを削除（サインアウト時）
    func deleteAPNsToken() {
        guard let uid = Auth.auth().currentUser?.uid,
              let token = apnsToken else { return }
        
        db.collection("users_private")
            .document(uid)
            .collection("fcmTokens")
            .document(token)
            .delete { error in
                if let error = error {
                    print("❌ Failed to delete APNs token: \(error)")
                } else {
                    print("✅ APNs token deleted")
                }
            }
    }
    
    /// 通知タップ時の処理
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // 通知のタイプに応じて画面遷移
        guard let type = userInfo["type"] as? String else { return }
        
        print("📱 Handling notification of type: \(type)")
        
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
            print("⚠️ Unknown notification type: \(type)")
        }
    }
    
    private func handleLikeNotification(targetType: String, targetId: String) {
        // 投稿詳細画面に遷移
        print("→ Navigate to \(targetType) with id: \(targetId)")
        // DeepLinkManagerを使って遷移（実装済みの場合）
    }
    
    private func handleFollowNotification(actorUid: String) {
        // プロフィール画面に遷移
        print("→ Navigate to profile: \(actorUid)")
        // DeepLinkManagerを使って遷移（実装済みの場合）
    }
    
    private func handleCommentNotification(targetType: String, targetId: String) {
        // 投稿詳細画面に遷移
        print("→ Navigate to \(targetType) with id: \(targetId)")
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
        print("📱 Notification received in foreground: \(userInfo)")
        
        // フォアグラウンドでも通知を表示
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    /// 通知をタップした時
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
        
        handleNotification(userInfo)
        completionHandler()
    }
}