//
//  FollowViewModel.swift
//  Shaka
//
//  Created by Assistant on 2025/01/13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class FollowViewModel: ObservableObject {
    @Published var following: [Friend] = [] // 一時的に既存のFriendモデルを使用
    @Published var followers: [Friend] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var followingListener: ListenerRegistration?
    private var followersListener: ListenerRegistration?
    
    deinit {
        followingListener?.remove()
        followersListener?.remove()
    }
    
    // MARK: - フォロー
    func followUser(targetUid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 認証状態の詳細ログ
        if let user = Auth.auth().currentUser {
            print("🔐 Auth Status:")
            print("  UID: \(user.uid)")
            print("  Is Anonymous: \(user.isAnonymous)")
            print("  Provider IDs: \(user.providerData.map { $0.providerID })")
        } else {
            print("❌ No authenticated user")
        }
        
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "FollowViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "ログインが必要です"])))
            return
        }
        
        // 自分自身はフォローできない
        guard currentUid != targetUid else {
            completion(.failure(NSError(domain: "FollowViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "自分自身をフォローすることはできません"])))
            return
        }
        
        let followingRef = db.collection("following").document(currentUid).collection("users").document(targetUid)
        
        print("🔍 Checking follow status at path: following/\(currentUid)/users/\(targetUid)")
        
        // 既にフォローしているかチェック
        followingRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error checking follow status: \(error.localizedDescription)")
                print("  Error code: \((error as NSError).code)")
                print("  Current UID: \(currentUid)")
                print("  Target UID: \(targetUid)")
                completion(.failure(error))
                return
            }
            
            if snapshot?.exists == true {
                // 既にフォロー済み
                completion(.success(()))
                return
            }
            
            // フォロー実行（シンプル版：まずfollowingのみ）
            print("🔍 Writing to path: following/\(currentUid)/users/\(targetUid)")
            print("  Current user: \(Auth.auth().currentUser?.uid ?? "nil")")
            
            followingRef.setData([
                "createdAt": FieldValue.serverTimestamp(),
                "uid": targetUid
            ]) { error in
                if let error = error {
                    print("❌ Error following user: \(error.localizedDescription)")
                    print("  Error code: \((error as NSError).code)")
                    print("  Error domain: \((error as NSError).domain)")
                    completion(.failure(error))
                } else {
                    print("✅ Followed user: \(targetUid)")
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - アンフォロー
    func unfollowUser(targetUid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "FollowViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Please sign in"])))
            return
        }
        
        // フォローリストから削除（シンプル版）
        let followingRef = db.collection("following").document(currentUid).collection("users").document(targetUid)
        followingRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ Unfollowed user: \(targetUid)")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - フォロー中のユーザー取得
    func fetchFollowing(for userId: String? = nil) {
        let uid = userId ?? Auth.auth().currentUser?.uid
        guard let uid = uid else { return }
        
        isLoading = true
        
        db.collection("following").document(uid).collection("users")
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "フォローリストの取得に失敗しました: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.following = []
                    return
                }
                
                // ユーザー情報を取得
                let userIds = documents.compactMap { $0.data()["uid"] as? String }
                self?.fetchUserProfiles(uids: userIds, isFollowing: true)
            }
    }
    
    // MARK: - フォロワー取得
    func fetchFollowers(for userId: String? = nil) {
        let uid = userId ?? Auth.auth().currentUser?.uid
        guard let uid = uid else { return }
        
        isLoading = true
        
        db.collection("followers").document(uid).collection("users")
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "フォロワーリストの取得に失敗しました: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.followers = []
                    return
                }
                
                // ユーザー情報を取得
                let userIds = documents.compactMap { $0.data()["uid"] as? String }
                self?.fetchUserProfiles(uids: userIds, isFollowing: false)
            }
    }
    
    // MARK: - ユーザープロフィール取得
    private func fetchUserProfiles(uids: [String], isFollowing: Bool) {
        guard !uids.isEmpty else {
            if isFollowing {
                self.following = []
            } else {
                self.followers = []
            }
            return
        }
        
        db.collection("users")
            .whereField(FieldPath.documentID(), in: uids)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching user profiles: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let users = documents.compactMap { doc -> Friend? in
                    let data = doc.data()
                    guard let publicData = data["public"] as? [String: Any] else { return nil }
                    
                    return Friend(
                        id: doc.documentID,
                        createdAt: Date(),
                        displayName: publicData["displayName"] as? String,
                        photoURL: publicData["photoURL"] as? String,
                        bio: publicData["bio"] as? String
                    )
                }
                
                DispatchQueue.main.async {
                    if isFollowing {
                        self?.following = users
                    } else {
                        self?.followers = users
                    }
                }
            }
    }
    
    // MARK: - フォロー状態チェック
    func isFollowing(targetUid: String, completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("following").document(currentUid).collection("users").document(targetUid)
            .getDocument { snapshot, _ in
                completion(snapshot?.exists == true)
            }
    }
}