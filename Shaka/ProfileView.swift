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
    @State private var showLinkError = false
    @State private var linkErrorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
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
                        Text(authManager.isAuthenticated ? "Signed In" : "Not Signed In")
                            .foregroundColor(authManager.isAuthenticated ? .green : .red)
                    }
                    
                    HStack {
                        Text("Guest User")
                        Spacer()
                        Text(authManager.currentUser?.isAnonymous ?? false ? "Yes" : "No")
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
                    if authManager.isLinkedWithApple {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Protected with Apple ID")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Protect your account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Link with Apple ID to recover your account if you lose your device")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                // Apple Sign Inを開始
                                let request = authManager.startAppleSignInFlow()
                                let authorizationController = ASAuthorizationController(authorizationRequests: [request])
                                authorizationController.delegate = AppleSignInCoordinator(
                                    onSuccess: { authorization in
                                        Task {
                                            do {
                                                try await authManager.linkWithAppleCredential(authorization)
                                            } catch {
                                                linkErrorMessage = error.localizedDescription
                                                showLinkError = true
                                            }
                                        }
                                    },
                                    onError: { error in
                                        linkErrorMessage = error.localizedDescription
                                        showLinkError = true
                                    }
                                )
                                authorizationController.performRequests()
                            }) {
                                HStack {
                                    Image(systemName: "apple.logo")
                                    Text("Link with Apple")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
            }
            .navigationTitle("Profile")
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Saved to clipboard")
            }
            .alert("Link Failed", isPresented: $showLinkError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(linkErrorMessage)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}

// Apple Sign In Coordinator
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    let onSuccess: (ASAuthorization) -> Void
    let onError: (Error) -> Void
    
    init(onSuccess: @escaping (ASAuthorization) -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onSuccess(authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onError(error)
    }
}