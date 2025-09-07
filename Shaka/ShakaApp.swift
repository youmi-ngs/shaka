//
//  ShakaApp.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@main
struct ShakaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        FirebaseApp.configure()
        let db = Firestore.firestore()
        
        // Register Live Activity (if needed and available)
        #if !targetEnvironment(macCatalyst)
        // ActivityRegistry.register() // Commented out as it's not defined
        #endif
        
        // 既存ユーザーのマイグレーション（アップデート後の初回起動対応）
        // 一度だけ実行するためのフラグ
        if !UserDefaults.standard.bool(forKey: "hasPerformedOnboardingMigration") {
            if Auth.auth().currentUser != nil {
                // 既にログイン済みのユーザーは自動的にオンボーディング完了とする
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
            // マイグレーション完了フラグを設定
            UserDefaults.standard.set(true, forKey: "hasPerformedOnboardingMigration")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // オンボーディング完了済みの場合のみContentViewを表示
                if hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(deepLinkManager)
                        .environmentObject(notificationManager)
                        .onOpenURL { url in
                            // Handle Live Activity deep links
                            if url.absoluteString == "shaka://stoplocation" {
                                LocationSharingManager.shared.stopSharingLocation()
                            } else {
                                _ = deepLinkManager.handleURL(url)
                            }
                        }
                        .onAppear {
                            // アプリ起動時にバッジをクリア
                            UIApplication.shared.applicationIconBadgeNumber = 0
                        }
                } else {
                    // 初回起動時、またはフラグがリセットされた場合はオンボーディング画面を表示
                    OnboardingView()
                        .environmentObject(authManager)
                        .environmentObject(notificationManager)
                }
            }
            .task {
                // セッション復元のチェックのみ行う（自動サインインはしない）
                if let currentUser = Auth.auth().currentUser {
                }
            }
        }
    }
}
