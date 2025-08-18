//
//  OnboardingView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Section with Logo/Title
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "camera.aperture")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.bottom, 10)
                
                Text("Welcome to Shaka!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Share your photography journey")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .frame(maxHeight: .infinity)
            .padding()
            
            // Bottom Section with Buttons
            VStack(spacing: 16) {
                // Guest Account Button
                Button(action: startAsGuest) {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "person")
                                .font(.title2)
                            Text("Use as Guest")
                                .font(.headline)
                        }
                        Text("Start with a temporary account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("You can save it later with Apple ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, 8)
                
                // Apple Sign In Button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        let appleRequest = authManager.startAppleSignInFlow()
                        request.requestedScopes = appleRequest.requestedScopes
                        request.nonce = appleRequest.nonce
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authResult):
                            handleAppleSignIn(authResult)
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
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)
                
                VStack(spacing: 4) {
                    Text("Sign in with Apple")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Continue with your existing account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Keep your data safe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
            .padding(.bottom, 20)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView("Setting up...")
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Guest Account
    private func startAsGuest() {
        isLoading = true
        Task {
            do {
                try await authManager.signInAnonymously()
                await MainActor.run {
                    hasCompletedOnboarding = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create guest account: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    private func handleAppleSignIn(_ authResult: ASAuthorization) {
        isLoading = true
        Task {
            do {
                try await authManager.signInWithAppleCredential(authResult)
                await MainActor.run {
                    hasCompletedOnboarding = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AuthManager.shared)
    }
}