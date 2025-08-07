//
//  AppleSignInView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/07.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                // ロゴやアプリ名
                VStack(spacing: 16) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Shaka")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sign in to access your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // サインインオプション
                VStack(spacing: 20) {
                    // Apple Sign Inボタン
                    SignInWithAppleButtonRepresentable(
                        onRequest: { request in
                            let appleRequest = authManager.startAppleSignInFlow()
                            request.requestedScopes = appleRequest.requestedScopes
                            request.nonce = appleRequest.nonce
                        },
                        onCompletion: { result in
                            handleSignInResult(result)
                        }
                    )
                    .frame(height: 50)
                    .cornerRadius(8)
                    
                    // 匿名で続けるオプション
                    Button(action: {
                        Task {
                            do {
                                try await authManager.signInAnonymously()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }) {
                        Text("Continue as Guest")
                            .font(.callout)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 10)
                    
                    Text("Guest accounts may lose data if unlinked")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
            .alert("Sign In Failed", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                do {
                    try await authManager.signInWithAppleCredential(authorization)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    AppleSignInView()
        .environmentObject(AuthManager.shared)
}