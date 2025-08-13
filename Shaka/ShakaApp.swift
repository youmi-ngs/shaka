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
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        FirebaseApp.configure()
        let db = Firestore.firestore()
        print("🔥 Firebase configured")
        print("📚 Firestore instance:", db)
        
        // 既存ユーザーのマイグレーション（アップデート後の初回起動対応）
        // 一度だけ実行するためのフラグ
        if !UserDefaults.standard.bool(forKey: "hasPerformedOnboardingMigration") {
            if Auth.auth().currentUser != nil {
                // 既にログイン済みのユーザーは自動的にオンボーディング完了とする
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                print("📱 Migrated existing user - skipping onboarding")
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
                        .onOpenURL { url in
                            print("📱 Received URL: \(url)")
                            _ = deepLinkManager.handleURL(url)
                        }
                } else {
                    // 初回起動時、またはフラグがリセットされた場合はオンボーディング画面を表示
                    OnboardingView()
                        .environmentObject(authManager)
                }
            }
            .task {
                // セッション復元のチェックのみ行う（自動サインインはしない）
                if let currentUser = Auth.auth().currentUser {
                    print("✅ Session restored for user: \(currentUser.uid)")
                    print("   Anonymous: \(currentUser.isAnonymous)")
                    print("   Providers: \(currentUser.providerData.map { $0.providerID })")
                }
            }
        }
    }
}
