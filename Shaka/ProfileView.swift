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
    @State private var showCopiedAlert = false
    @State private var showSignInView = false
    @State private var showEditNameSheet = false
    @State private var newDisplayName = ""
    
    var body: some View {
        NavigationView {
            List {
                // Display Name Section
                Section(header: Text("Display Name")) {
                    HStack {
                        Text(authManager.getDisplayName())
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button(action: {
                            newDisplayName = authManager.displayName ?? ""
                            showEditNameSheet = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
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
                            .foregroundColor(.blue)
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
                
                // Debug Section
                Section(header: Text("Info")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        if authManager.isAuthenticated {
                            if authManager.currentUser?.isAnonymous == true {
                                Text("Anonymous User")
                                    .foregroundColor(.orange)
                            } else if authManager.isLinkedWithApple {
                                Text("Apple ID User")
                                    .foregroundColor(.green)
                            } else {
                                Text("Signed In")
                                    .foregroundColor(.green)
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
                
                // Sign In Section for anonymous users
                if authManager.currentUser?.isAnonymous == true {
                    Section(header: Text("Have an account?")) {
                        Button(action: {
                            showSignInView = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.key")
                                Text("Sign In with Existing Account")
                                    .foregroundColor(.blue)
                            }
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
                }
                #endif
                
            }
            .navigationTitle("Profile")
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Saved to clipboard")
            }
            .sheet(isPresented: $showSignInView) {
                AppleSignInView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showEditNameSheet) {
                EditDisplayNameView(displayName: $newDisplayName) { newName in
                    Task {
                        do {
                            try await authManager.updateDisplayName(newName)
                            // プロフィールを再取得して表示を更新
                            authManager.fetchUserProfile()
                        } catch {
                            print("Failed to update display name: \(error)")
                        }
                    }
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