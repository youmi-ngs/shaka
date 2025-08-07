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
                    // アプリ起動時に匿名ログイン
                    do {
                        try await authManager.signInAnonymously()
                    } catch {
                        print("❌ Failed to sign in anonymously: \(error)")
                    }
                }
        }
    }
}
