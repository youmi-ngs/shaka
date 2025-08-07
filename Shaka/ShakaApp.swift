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
    
    init() {
        FirebaseApp.configure()
        let db = Firestore.firestore()
        print("🔥 Firebase configured")
        print("📚 Firestore instance:", db)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .task {
                    // アプリ起動時に認証状態をチェック
                    // Firebase Authは自動的にセッションを復元する
                    if let currentUser = Auth.auth().currentUser {
                        print("✅ Session restored for user: \(currentUser.uid)")
                        print("   Anonymous: \(currentUser.isAnonymous)")
                        print("   Providers: \(currentUser.providerData.map { $0.providerID })")
                    } else {
                        // セッションがない場合のみ匿名ログイン
                        print("📱 No existing session, creating anonymous user")
                        do {
                            try await authManager.signInAnonymously()
                        } catch {
                            print("❌ Failed to sign in anonymously: \(error)")
                        }
                    }
                }
        }
    }
}
