//
//  LikeManager.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// いいね機能を管理するクラス
class LikeManager: ObservableObject {
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    @Published var isLiked = false
    @Published var isProcessing = false
    @Published var likesCount = 0
    
    private let postId: String
    private let postType: PostType
    
    enum PostType {
        case work
        case question
        
        var collectionName: String {
            switch self {
            case .work: return "works"
            case .question: return "questions"
            }
        }
    }
    
    init(postId: String, postType: PostType) {
        self.postId = postId
        self.postType = postType
        startListening()
    }
    
    deinit {
        listener?.remove()
    }
    
    /// いいねの状態を監視開始
    private func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLiked = false
            return
        }
        
        // 自分のいいね状態を監視
        let likeRef = db.collection(postType.collectionName)
            .document(postId)
            .collection("likes")
            .document(uid)
        
        listener = likeRef.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("❌ Error listening to like status: \(error)")
                return
            }
            
            self?.isLiked = snapshot?.exists ?? false
        }
        
        // いいね数を取得（オプション）
        fetchLikesCount()
    }
    
    /// いいね数を取得
    private func fetchLikesCount() {
        db.collection(postType.collectionName)
            .document(postId)
            .collection("likes")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching likes count: \(error)")
                    return
                }
                
                self?.likesCount = snapshot?.documents.count ?? 0
            }
    }
    
    /// いいねをトグル
    func toggleLike() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ User not authenticated")
            return
        }
        
        guard !isProcessing else { return } // 二重タップ防止
        isProcessing = true
        
        let likeRef = db.collection(postType.collectionName)
            .document(postId)
            .collection("likes")
            .document(uid)
        
        if isLiked {
            // いいねを削除
            removeLike(likeRef: likeRef)
        } else {
            // いいねを追加
            addLike(likeRef: likeRef)
        }
    }
    
    /// いいねを追加
    private func addLike(likeRef: DocumentReference) {
        likeRef.setData([
            "createdAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            self?.isProcessing = false
            
            if let error = error {
                print("❌ Failed to add like: \(error)")
                // 楽観的更新をリバート
                self?.isLiked = false
            } else {
                print("✅ Like added successfully")
                self?.likesCount += 1
            }
        }
        
        // 楽観的更新
        isLiked = true
    }
    
    /// いいねを削除
    private func removeLike(likeRef: DocumentReference) {
        likeRef.delete { [weak self] error in
            self?.isProcessing = false
            
            if let error = error {
                print("❌ Failed to remove like: \(error)")
                // 楽観的更新をリバート
                self?.isLiked = true
            } else {
                print("✅ Like removed successfully")
                self?.likesCount = max(0, (self?.likesCount ?? 1) - 1)
            }
        }
        
        // 楽観的更新
        isLiked = false
    }
}