//
//  FriendsViewModel.swift
//  Shaka
//
//  Created by Assistant on 2025/01/13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - フレンド追加
    func addFriend(targetUid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "FriendsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "ログインが必要です"])))
            return
        }
        
        print("🔍 Debug - Adding friend:")
        print("  Current UID: \(currentUid)")
        print("  Target UID: \(targetUid)")
        
        // 自分自身は追加できない
        guard currentUid != targetUid else {
            completion(.failure(NSError(domain: "FriendsViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "自分自身を友達に追加することはできません"])))
            return
        }
        
        let friendRef = db.collection("friends").document(currentUid).collection("list").document(targetUid)
        
        // 既に友達かチェック
        friendRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if snapshot?.exists == true {
                // 既に友達（no-op）
                completion(.success(()))
                return
            }
            
            // 友達として追加
            let data = [
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            print("🔍 Debug - Setting data at path: friends/\(currentUid)/list/\(targetUid)")
            print("  Data: \(data)")
            
            friendRef.setData(data) { error in
                if let error = error {
                    print("❌ Error adding friend: \(error.localizedDescription)")
                    print("  Error code: \((error as NSError).code)")
                    print("  Error domain: \((error as NSError).domain)")
                    completion(.failure(error))
                } else {
                    print("✅ Friend added: \(targetUid)")
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - フレンドリスト取得
    func fetchFriends() {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "ログインが必要です"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("friends").document(currentUid).collection("list")
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "フレンドリストの取得に失敗しました: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.friends = []
                    return
                }
                
                // フレンドのUIDリスト
                let friendUids = documents.map { $0.documentID }
                
                if friendUids.isEmpty {
                    self.friends = []
                    return
                }
                
                // バッチでユーザー情報を取得
                self.fetchUserProfiles(uids: friendUids, friendDocs: documents)
            }
    }
    
    // MARK: - リアルタイム監視
    func startListening() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        listener = db.collection("friends").document(currentUid).collection("list")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "リアルタイム更新エラー: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.friends = []
                    return
                }
                
                let friendUids = documents.map { $0.documentID }
                
                if friendUids.isEmpty {
                    self.friends = []
                    return
                }
                
                self.fetchUserProfiles(uids: friendUids, friendDocs: documents)
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - ユーザープロフィール取得
    private func fetchUserProfiles(uids: [String], friendDocs: [DocumentSnapshot]) {
        // 10件ずつバッチ処理（Firestore制限）
        let chunks = uids.chunked(into: 10)
        var allFriends: [Friend] = []
        let group = DispatchGroup()
        
        for chunk in chunks {
            group.enter()
            
            db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error fetching user profiles: \(error)")
                        return
                    }
                    
                    guard let userDocs = snapshot?.documents else { return }
                    
                    // ユーザー情報をマッピング
                    let userMap = userDocs.reduce(into: [String: [String: Any]]()) { result, doc in
                        result[doc.documentID] = doc.data()
                    }
                    
                    // Friendオブジェクトを作成
                    for friendDoc in friendDocs where chunk.contains(friendDoc.documentID) {
                        var friend = Friend(from: friendDoc)
                        
                        if let userData = userMap[friend.id],
                           let publicData = userData["public"] as? [String: Any] {
                            friend.displayName = publicData["displayName"] as? String
                            friend.photoURL = publicData["photoURL"] as? String
                            friend.bio = publicData["bio"] as? String
                        }
                        
                        allFriends.append(friend)
                    }
                }
        }
        
        group.notify(queue: .main) { [weak self] in
            // createdAtでソート
            self?.friends = allFriends.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // MARK: - フレンド削除
    func removeFriend(targetUid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "FriendsViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "ログインが必要です"])))
            return
        }
        
        db.collection("friends").document(currentUid).collection("list").document(targetUid)
            .delete { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    print("✅ Friend removed: \(targetUid)")
                    completion(.success(()))
                }
            }
    }
    
    // MARK: - フレンド状態チェック
    func isFriend(targetUid: String, completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        db.collection("friends").document(currentUid).collection("list").document(targetUid)
            .getDocument { snapshot, _ in
                completion(snapshot?.exists == true)
            }
    }
}

// MARK: - Helper Extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}