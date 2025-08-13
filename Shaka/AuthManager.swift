//
//  AuthManager.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/07.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var userID: String?
    @Published var isLinkedWithApple = false
    @Published var displayName: String?
    @Published var photoURL: String?
    
    // For Sign in with Apple
    private var currentNonce: String?
    private let db = Firestore.firestore()
        
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
                self?.fetchUserProfile()
            } else {
                print("❌ Auth state changed - No user authenticated")
                self?.isLinkedWithApple = false
                self?.displayName = nil
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
    
    // MARK: - User Profile Management
    
    /// ユーザープロフィールを取得
    func fetchUserProfile() {
        guard let uid = userID else { return }
        
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Failed to fetch user profile: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                // 新しい構造から読み取り
                if let publicData = data["public"] as? [String: Any] {
                    self?.displayName = publicData["displayName"] as? String
                    self?.photoURL = publicData["photoURL"] as? String
                } else {
                    // 古い構造からのフォールバック
                    self?.displayName = data["displayName"] as? String
                    self?.photoURL = data["photoURL"] as? String
                }
                print("📝 User profile loaded: \(self?.displayName ?? "No name")")
                print("📸 Photo URL: \(self?.photoURL ?? "No photo")")
            } else {
                print("📝 No user profile found, creating default...")
                self?.createDefaultProfile()
            }
        }
    }
    
    /// デフォルトのユーザープロフィールを作成
    private func createDefaultProfile() {
        guard let uid = userID else { return }
        
        let defaultName = "User_\(String(uid.prefix(6)))"
        let data: [String: Any] = [
            "displayName": defaultName,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        db.collection("users").document(uid).setData(data) { [weak self] error in
            if let error = error {
                print("❌ Failed to create user profile: \(error.localizedDescription)")
            } else {
                self?.displayName = defaultName
                print("✅ Default user profile created")
            }
        }
    }
    
    /// 表示名を更新
    func updateDisplayName(_ newName: String) async throws {
        guard let uid = userID else { throw AuthError.noUser }
        
        // 新しい構造で更新
        let data: [String: Any] = [
            "public": [
                "displayName": newName
            ]
        ]
        
        try await db.collection("users").document(uid).setData(data, merge: true)
        
        // メインスレッドで @Published プロパティを更新
        await MainActor.run {
            self.displayName = newName
        }
        
        print("✅ Display name updated to: \(newName)")
    }
    
    /// 表示名を取得（nilの場合はデフォルト値を返す）
    func getDisplayName() -> String {
        if let displayName = displayName, !displayName.isEmpty {
            return displayName
        } else if let uid = userID {
            return "User_\(String(uid.prefix(6)))"
        } else {
            return "Anonymous"
        }
    }
    
    // MARK: - Account Management
    
    /// Apple ID連携を解除（匿名アカウントに戻す）
    func unlinkAppleID() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.noUser
        }
        
        // Apple IDプロバイダーを解除
        try await user.unlink(fromProvider: "apple.com")
        
        // 連携状態を再チェック
        checkLinkedProviders()
        
        print("✅ Apple ID unlinked successfully")
        print("🔗 Remaining providers: \(user.providerData.map { $0.providerID })")
    }
    
    /// アカウントを完全に削除
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.noUser
        }
        
        let uid = user.uid
        print("🗑️ Starting account deletion for user: \(uid)")
        
        // 1. ユーザーの投稿を削除
        print("📝 Deleting user's posts...")
        
        // Works削除（コメントも含む）
        let worksSnapshot = try await db.collection("works").whereField("userID", isEqualTo: uid).getDocuments()
        print("  Found \(worksSnapshot.documents.count) works to delete")
        for doc in worksSnapshot.documents {
            // まず投稿のコメントを削除
            let commentsSnapshot = try await doc.reference.collection("comments").getDocuments()
            for comment in commentsSnapshot.documents {
                try await comment.reference.delete()
            }
            // 投稿自体を削除
            try await doc.reference.delete()
        }
        
        // Questions削除（コメントも含む）
        let questionsSnapshot = try await db.collection("questions").whereField("userID", isEqualTo: uid).getDocuments()
        print("  Found \(questionsSnapshot.documents.count) questions to delete")
        for doc in questionsSnapshot.documents {
            // まず質問のコメントを削除
            let commentsSnapshot = try await doc.reference.collection("comments").getDocuments()
            for comment in commentsSnapshot.documents {
                try await comment.reference.delete()
            }
            // 質問自体を削除
            try await doc.reference.delete()
        }
        
        // 2. 他のユーザーの投稿に対するコメントを削除
        print("💬 Deleting user's comments on other posts...")
        
        // 全てのWorksから自分のコメントを探して削除
        let allWorksSnapshot = try await db.collection("works").getDocuments()
        for work in allWorksSnapshot.documents {
            let userCommentsSnapshot = try await work.reference.collection("comments")
                .whereField("userID", isEqualTo: uid)
                .getDocuments()
            for comment in userCommentsSnapshot.documents {
                try await comment.reference.delete()
            }
        }
        
        // 全てのQuestionsから自分のコメントを探して削除
        let allQuestionsSnapshot = try await db.collection("questions").getDocuments()
        for question in allQuestionsSnapshot.documents {
            let userCommentsSnapshot = try await question.reference.collection("comments")
                .whereField("userID", isEqualTo: uid)
                .getDocuments()
            for comment in userCommentsSnapshot.documents {
                try await comment.reference.delete()
            }
        }
        
        // 3. フォロー関係を削除
        print("👥 Removing follow relationships...")
        
        // フォロー中のユーザーから自分を削除
        let followingSnapshot = try await db.collection("following").document(uid).collection("users").getDocuments()
        print("  Unfollowing \(followingSnapshot.documents.count) users")
        for doc in followingSnapshot.documents {
            let followedUserId = doc.documentID
            // 相手のフォロワーリストから自分を削除
            try await db.collection("followers").document(followedUserId).collection("users").document(uid).delete()
            // 自分のフォローリストから削除
            try await doc.reference.delete()
        }
        
        // フォロワーから自分へのフォローを削除
        let followersSnapshot = try await db.collection("followers").document(uid).collection("users").getDocuments()
        print("  Removing \(followersSnapshot.documents.count) followers")
        for doc in followersSnapshot.documents {
            let followerUserId = doc.documentID
            // フォロワーのフォローリストから自分を削除
            try await db.collection("following").document(followerUserId).collection("users").document(uid).delete()
            // 自分のフォロワーリストから削除
            try await doc.reference.delete()
        }
        
        // フォロー関係のルートドキュメントを削除
        try? await db.collection("following").document(uid).delete()
        try? await db.collection("followers").document(uid).delete()
        
        // 4. ユーザープロフィールを削除
        print("👤 Deleting user profile...")
        try await db.collection("users").document(uid).delete()
        
        // 5. Firebase Authenticationからアカウントを削除
        print("🔐 Deleting authentication account...")
        try await user.delete()
        
        // 6. ローカルデータをクリア
        print("📱 Clearing local data...")
        await MainActor.run {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
        
        print("✅ Account and all associated data deleted successfully")
    }
}
