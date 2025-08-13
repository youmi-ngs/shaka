//
//  AppleSignInButton.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/07.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSigningIn = false
    
    var body: some View {
        Group {
            if authManager.isLinkedWithApple {
                // Appleサインイン済みの表示
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Protected with Apple ID")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if !authManager.isAuthenticated {
                // 匿名認証が完了していない場合
                VStack(alignment: .leading, spacing: 12) {
                    Text("Setting up account...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                .padding(.vertical, 8)
                .task {
                    // 匿名認証を試みる
                    if !authManager.isAuthenticated && !isSigningIn {
                        isSigningIn = true
                        do {
                            try await authManager.signInAnonymously()
                        } catch {
                            errorMessage = "Failed to create account: \(error.localizedDescription)"
                            showError = true
                        }
                        isSigningIn = false
                    }
                }
            } else {
                // Appleサインインボタン
                VStack(alignment: .leading, spacing: 12) {
                    Text("Protect your account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Continue with Apple to protect your data")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    SignInWithAppleButtonRepresentable(
                        buttonType: .continue,  // リンク用は"Continue with Apple"
                        onRequest: { request in
                            // AuthManagerからリクエストを設定
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
                }
                .padding(.vertical, 8)
            }
        }
        .alert("Link Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                do {
                    try await authManager.linkWithAppleCredential(authorization)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        case .failure(let error):
            // キャンセルの場合はエラーを表示しない
            if let authError = error as NSError?,
               authError.code == 1001 { // ASAuthorizationError.canceled
                print("User cancelled Apple Sign In")
                return
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// SwiftUIでネイティブのAppleサインインボタンを使用
struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    var buttonType: ASAuthorizationAppleIDButton.ButtonType = .signIn
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: buttonType,
            authorizationButtonStyle: .black
        )
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleAuthorizationAppleIDButtonPress),
            for: .touchUpInside
        )
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate {
        let parent: SignInWithAppleButtonRepresentable
        
        init(_ parent: SignInWithAppleButtonRepresentable) {
            self.parent = parent
        }
        
        @objc func handleAuthorizationAppleIDButtonPress() {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            parent.onRequest(request)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.performRequests()
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.onCompletion(.success(authorization))
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }
    }
}

#Preview {
    AppleSignInButton()
        .environmentObject(AuthManager.shared)
        .padding()
}