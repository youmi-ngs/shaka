//
//  ProfileView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/07.
//

import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showCopiedAlert = false
    @State private var showSignInView = false
    @State private var showFullProfileEdit = false
    @State private var showFriendsList = false
    @State private var selectedTab = 0
    @State private var showUnlinkAppleAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var isProcessing = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var showNotificationList = false
    @StateObject private var notificationViewModel = NotificationViewModel()
    
    var body: some View {
        List {
                // New Profile Section
                Section {
                    Button(action: {
                        showFullProfileEdit = true
                    }) {
                        HStack {
                            // プロフィール写真または既定アイコン
                            if let photoURLString = authManager.photoURL,
                               let photoURL = URL(string: photoURLString) {
                                AsyncImage(url: photoURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                    case .failure(_):
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.teal)
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 60, height: 60)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.teal)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(authManager.getDisplayName())
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Edit Profile")
                                    .font(.caption)
                                    .foregroundColor(.teal)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // My Content Section
                Section {
                    // My Posts
                    ZStack {
                        NavigationLink {
                            if let userId = authManager.userID {
                                UserPostsView(userId: userId, displayName: authManager.getDisplayName())
                            }
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)
                        
                        HStack {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(.teal)
                                .frame(width: 30, alignment: .center)
                            Text("My Posts")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Bookmarks
                    NavigationLink(destination: BookmarkedPostsView()) {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.teal)
                                .frame(width: 30, alignment: .center)
                            Text("Bookmarks")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Following/Followers Section
                Section {
                    // Following
                    Button(action: {
                        selectedTab = 0
                        showFriendsList = true
                    }) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.teal)
                                .frame(width: 30, alignment: .center)
                            Text("Following")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Followers
                    Button(action: {
                        selectedTab = 1
                        showFriendsList = true
                    }) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.teal)
                                .frame(width: 30, alignment: .center)
                            Text("Followers")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // User ID Section
                Section(header: Text("Your ID")) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let userID = authManager.userID {
                            Text(userID)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            
                            Button(action: {
                                UIPasteboard.general.string = userID
                                showCopiedAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("Not signed in")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Share Link Section (for future friend feature)
                Section(header: Text("Share Link")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Send to friends:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(authManager.getShareableUserID())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.teal)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Button(action: {
                            UIPasteboard.general.string = authManager.getShareableUserID()
                            showCopiedAlert = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Copy Link")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }
                
                
                // Legal Section
                Section(header: Text("Legal")) {
                    Button(action: {
                        showTermsOfService = true
                    }) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {
                        showPrivacyPolicy = true
                    }) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // Debug Section
                Section(header: Text("Info")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        if authManager.isAuthenticated {
                            if authManager.currentUser?.isAnonymous == true {
                                Text("Anonymous User")
                                    .foregroundColor(.yellow)
                            } else if authManager.isLinkedWithApple {
                                Text("Apple ID User")
                                    .foregroundColor(.green)
                            } else {
                                Text("Signed In")
                                    .foregroundColor(.pink)
                            }
                        } else {
                            Text("Not Signed In")
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text("Account Type")
                        Spacer()
                        Text(authManager.currentUser?.isAnonymous ?? false ? "Guest" : "Permanent")
                            .foregroundColor(.secondary)
                    }
                    
                    if let creationDate = authManager.currentUser?.metadata.creationDate {
                        HStack {
                            Text("Created")
                            Spacer()
                            Text(creationDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Account Protection Section
                Section(header: Text("Account Protection")) {
                    AppleSignInButton()
                }
                
                // Notifications Section (Debug only)
                #if DEBUG
                Section(header: Text("Notifications")) {
                    HStack {
                        Text("Push Notifications")
                        Spacer()
                        if notificationManager.isNotificationEnabled {
                            Text("Enabled")
                                .foregroundColor(.green)
                        } else {
                            Button("Enable") {
                                notificationManager.requestNotificationPermission()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    if let token = notificationManager.fcmToken {
                        HStack {
                            Text("FCM Token")
                            Spacer()
                            Text("Active")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    // トークンリフレッシュボタン
                    Button(action: {
                        notificationManager.refreshFCMToken()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Token")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // プッシュ通知設定状態
                    Button(action: {
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Check Setup Status")
                        }
                        .foregroundColor(.orange)
                    }
                }
                #endif
                
                // Sign In Section for anonymous users
                if authManager.currentUser?.isAnonymous == true {
                    Section(header: Text("Have an account?")) {
                        Button(action: {
                            showSignInView = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.key")
                                Text("Sign In with Existing Account")
                                    .foregroundColor(.teal)
                            }
                        }
                    }
                }
                
                // Account Management Section
                Section(header: Text("Account Management")) {
                    // Apple ID連携解除（Apple IDでサインインしている場合のみ）
                    if authManager.isLinkedWithApple {
                        Button(action: {
                            showUnlinkAppleAlert = true
                        }) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundColor(.orange)
                                Text("Unlink Apple ID")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    // アカウント削除
                    Button(action: {
                        showDeleteAccountAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Account")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Debug Section (開発時のみ)
                #if DEBUG
                Section(header: Text("Debug - Testing Only")) {
                    Button(action: {
                        Task {
                            // 完全にサインアウトして新規匿名ユーザーを作成
                            authManager.signOut()
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
                            try? await authManager.signInAnonymously()
                        }
                    }) {
                        Text("Create New Test User")
                            .foregroundColor(.orange)
                    }
                    .help("Creates a fresh anonymous user for testing")
                    
                    Button(action: {
                        // オンボーディングフラグをリセット
                        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                        authManager.signOut()
                        // アプリを再起動する必要があることを通知
                    }) {
                        Text("Reset Onboarding")
                            .foregroundColor(.red)
                    }
                    
                    // テスト専用：安全な削除テスト
                    if let uid = authManager.userID, uid.starts(with: "TEST_") {
                        Button(action: {
                            showDeleteAccountAlert = true
                        }) {
                            Text("⚠️ Delete TEST Account")
                                .foregroundColor(.red)
                                .bold()
                        }
                    }
                }
                #endif
                
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showNotificationList = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20))
                        
                        if notificationViewModel.unreadCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Text("\(min(notificationViewModel.unreadCount, 9))")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
        }
        .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Saved to clipboard")
            }
            .sheet(isPresented: $showSignInView) {
                AppleSignInView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showFullProfileEdit) {
                if let uid = authManager.userID {
                    UserProfileEditView(uid: uid)
                        .onDisappear {
                            // プロフィール編集画面が閉じた時に最新データを取得
                            authManager.fetchUserProfile()
                        }
                }
            }
            .sheet(isPresented: $showFriendsList) {
                FollowTabView(initialTab: selectedTab)
            }
            .sheet(isPresented: $showTermsOfService) {
                LegalView(type: .terms)
            }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalView(type: .privacy)
        }
        .sheet(isPresented: $showNotificationList) {
            NavigationView {
                NotificationListView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showNotificationList = false
                            }
                        }
                    }
            }
        }
        .alert("Unlink Apple ID", isPresented: $showUnlinkAppleAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Unlink", role: .destructive) {
                    handleUnlinkApple()
                }
            } message: {
                Text("Are you sure you want to unlink your Apple ID? Your account will become a guest account.")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    handleDeleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.")
            }
            .disabled(isProcessing)
            .overlay {
                if isProcessing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView("Processing...")
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                }
            }
    }
    
    // MARK: - Account Management Actions
    private func handleUnlinkApple() {
        isProcessing = true
        Task {
            do {
                try await authManager.unlinkAppleID()
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // エラー処理（必要に応じて別のアラートを表示）
                }
            }
        }
    }
    
    private func handleDeleteAccount() {
        isProcessing = true
        Task {
            do {
                try await authManager.deleteAccount()
                // アカウント削除成功後、アプリはAuthManagerによって自動的にサインアウト状態になる
                // OnboardingViewが表示される
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // エラー処理（必要に応じて別のアラートを表示）
                }
            }
        }
    }
}

// 表示名編集ビュー
struct EditDisplayNameView: View {
    @Binding var displayName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter your display name")) {
                    TextField("Display Name", text: $displayName)
                        .focused($isFocused)
                        .onAppear {
                            isFocused = true
                        }
                }
                
                Section {
                    Text("This name will be shown on your posts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Display Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(displayName.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
