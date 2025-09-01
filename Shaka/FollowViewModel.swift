//
//  FollowViewModel.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
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
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "FollowViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Please sign in to follow"])))
            return
        }
        
        // 自分自身はフォローできない
        guard currentUid != targetUid else {
            completion(.failure(NSError(domain: "FollowViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot follow yourself"])))
            return
        }
        
        let followingRef = db.collection("following").document(currentUid).collection("users").document(targetUid)
        let followersRef = db.collection("followers").document(targetUid).collection("users").document(currentUid)
        
        // 既にフォローしているかチェック
        followingRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if snapshot?.exists == true {
                // 既にフォロー済み
                completion(.success(()))
                return
            }
            
            // バッチ書き込みで両方同時に更新
            let batch = self?.db.batch()
            
            // 1. following コレクションに追加
            batch?.setData([
                "createdAt": FieldValue.serverTimestamp(),
                "uid": targetUid
            ], forDocument: followingRef)
            
            // 2. followers コレクションに追加
            batch?.setData([
                "createdAt": FieldValue.serverTimestamp(),
                "uid": currentUid
            ], forDocument: followersRef)
            
            // バッチコミット
            batch?.commit { error in
                if let error = error {
                    completion(.failure(error))
                } else {
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
        
        let followingRef = db.collection("following").document(currentUid).collection("users").document(targetUid)
        let followersRef = db.collection("followers").document(targetUid).collection("users").document(currentUid)
        
        // バッチ削除で両方同時に削除
        let batch = db.batch()
        
        // 1. following コレクションから削除
        batch.deleteDocument(followingRef)
        
        // 2. followers コレクションから削除
        batch.deleteDocument(followersRef)
        
        // バッチコミット
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
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