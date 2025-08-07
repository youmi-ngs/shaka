//
//  AuthManager.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/07.
//

import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var userID: String?
    @Published var isLinkedWithApple = false
    
    // For Sign in with Apple
    private var currentNonce: String?
        
    private init() {
        // 認証状態の変化を監視
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isAuthenticated = user != nil
            self?.userID = user?.uid
            
            if let user = user {
                print("✅ Auth state changed - User authenticated")
                print("   UID: \(user.uid)")
                print("   Anonymous: \(user.isAnonymous)")
                self?.checkLinkedProviders()
            } else {
                print("❌ Auth state changed - No user authenticated")
                self?.isLinkedWithApple = false
            }
        }
    }
    
    /// 匿名ログインを実行
    func signInAnonymously() async throws {
        do {
            let authResult = try await Auth.auth().signInAnonymously()
            print("🔐 Anonymous sign-in successful!")
            print("🆔 User UID: \(authResult.user.uid)")
            print("📅 Account created: \(authResult.user.metadata.creationDate?.description ?? "Unknown")")
            print("🔄 Is new user: \(authResult.additionalUserInfo?.isNewUser ?? false)")
        } catch {
            print("❌ Anonymous sign-in failed: \(error.localizedDescription)")
            print("🔍 Error details: \(error)")
            if let errorCode = (error as NSError?)?.code {
                print("🔍 Error code: \(errorCode)")
            }
            throw error
        }
    }
    
    /// 現在のユーザーIDを取得
    func getCurrentUserID() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    /// ユーザーIDをシェア用のテキストとして取得
    func getShareableUserID() -> String {
        guard let uid = getCurrentUserID() else {
            return "No user ID available"
        }
        return "shaka://user/\(uid)"
    }
    
    /// サインアウト（デバッグ用）
    func signOut() {
        do {
            try Auth.auth().signOut()
            print("👋 User signed out successfully")
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Apple Sign In
    
    /// リンクされているプロバイダーを確認
    private func checkLinkedProviders() {
        guard let user = Auth.auth().currentUser else { return }
        
        isLinkedWithApple = user.providerData.contains { provider in
            provider.providerID == "apple.com"
        }
        
        print("🔗 Linked providers: \(user.providerData.map { $0.providerID })")
        print("🍎 Is linked with Apple: \(isLinkedWithApple)")
    }
    
    /// ランダムな文字列を生成（nonce用）
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    /// SHA256でハッシュ化
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    /// Apple IDとリンク
    func startAppleSignInFlow() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.email]
        request.nonce = sha256(nonce)
        
        return request
    }
    
    /// Apple IDでサインイン（既存ユーザー用）
    func signInWithAppleCredential(_ authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        
        // Firebase用のクレデンシャルを作成
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        do {
            // Apple IDでサインイン
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Signed in with Apple ID!")
            print("🆔 User: \(authResult.user.uid)")
            print("📧 Email: \(authResult.user.email ?? "No email")")
            
            checkLinkedProviders()
        } catch {
            print("❌ Failed to sign in with Apple: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Apple Sign Inの結果を処理してアカウントをリンク
    func linkWithAppleCredential(_ authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        
        // Firebase用のクレデンシャルを作成
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        guard let currentUser = Auth.auth().currentUser else {
            throw AuthError.noUser
        }
        
        do {
            // リンクを試みる
            let authResult = try await currentUser.link(with: credential)
            print("🔗 Successfully linked with Apple ID!")
            print("🍎 User: \(authResult.user.uid)")
            
            checkLinkedProviders()
        } catch let error as NSError {
            // エラーコードをチェック
            if error.code == 17025 { // FIRAuthErrorCodeProviderAlreadyLinked
                print("ℹ️ This credential is already associated with a different account")
                
                // 既存のApple IDユーザーにサインインして、匿名データを移行
                do {
                    // 現在の匿名ユーザーのUIDを保存
                    let anonymousUID = currentUser.uid
                    print("📝 Current anonymous UID: \(anonymousUID)")
                    
                    // Apple IDでサインイン
                    let authResult = try await Auth.auth().signIn(with: credential)
                    print("✅ Signed in with existing Apple ID")
                    print("🆔 New UID: \(authResult.user.uid)")
                    
                    // TODO: ここで必要に応じてデータ移行処理を実装
                    // 例: Firestoreの匿名ユーザーのデータを新しいユーザーに移行
                    
                    checkLinkedProviders()
                } catch {
                    print("❌ Failed to sign in with Apple: \(error.localizedDescription)")
                    throw AuthError.credentialAlreadyInUse
                }
            } else {
                print("❌ Failed to link with Apple: \(error.localizedDescription)")
                print("🔍 Error code: \(error.code)")
                throw error
            }
        }
    }
    
    /// エラー定義
    enum AuthError: LocalizedError {
        case invalidCredential
        case noUser
        case credentialAlreadyInUse
        
        var errorDescription: String? {
            switch self {
            case .invalidCredential:
                return "Invalid Apple ID credential"
            case .noUser:
                return "No user is currently signed in"
            case .credentialAlreadyInUse:
                return "This Apple ID is already linked to another account. Signed in with existing account instead."
            }
        }
    }
}
