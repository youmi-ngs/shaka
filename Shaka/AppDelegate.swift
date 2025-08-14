//
//  AppDelegate.swift
//  Shaka
//
//  Created by Assistant on 2025/01/14.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Firebase Messagingのデリゲート設定
        Messaging.messaging().delegate = self
        
        // 通知センターのデリゲート設定
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        // APNs登録
        application.registerForRemoteNotifications()
        
        print("📱 AppDelegate configured for push notifications")
        
        return true
    }
    
    // MARK: - APNs Token
    
    /// APNsトークンを受信した時
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 APNs Device Token: \(token)")
        
        // FCMにAPNsトークンを設定
        Messaging.messaging().apnsToken = deviceToken
    }
    
    /// APNs登録に失敗した時
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Remote Notifications
    
    /// サイレントプッシュを受信した時
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("📱 Received remote notification: \(userInfo)")
        
        // NotificationManagerで処理
        NotificationManager.shared.handleNotification(userInfo)
        
        completionHandler(.newData)
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    /// FCMトークンが更新された時
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("⚠️ FCM token is nil")
            return
        }
        
        print("🔑 FCM Token received: \(fcmToken)")
        NotificationManager.shared.saveFCMToken(fcmToken)
    }
}