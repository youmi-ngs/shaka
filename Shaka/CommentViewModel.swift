//
//  CommentViewModel.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/13.
//

import Foundation
import FirebaseFirestore

class CommentViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    deinit {
        listener?.remove()
    }
    
    // コメントをリアルタイムで取得
    func fetchComments(for postID: String, postType: Comment.PostType) {
        listener?.remove()
        
        let collection = postType == .work ? "works" : "questions"
        
        listener = db.collection(collection)
            .document(postID)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching comments: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                self.comments = snapshot.documents.compactMap { doc in
                    let data = doc.data()
                    let id = doc.documentID
                    let text = data["text"] as? String ?? ""
                    let userID = data["userID"] as? String ?? "unknown"
                    let displayName = data["displayName"] as? String ?? "User_\(String(userID.prefix(6)))"
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let isPrivate = data["isPrivate"] as? Bool ?? (postType == .question)
                    
                    // プライベートコメントの場合、投稿者または自分のコメントのみ表示
                    if isPrivate {
                        let currentUserID = AuthManager.shared.getCurrentUserID()
                        // 投稿者IDを取得する必要がある
                        if let postUserID = data["postUserID"] as? String {
                            if userID != currentUserID && postUserID != currentUserID {
                                return nil // 表示しない
                            }
                        }
                    }
                    
                    return Comment(
                        id: id,
                        postID: postID,
                        postType: postType,
                        text: text,
                        userID: userID,
                        displayName: displayName,
                        createdAt: createdAt,
                        isPrivate: isPrivate
                    )
                }
            }
    }
    
    // コメントを追加
    func addComment(to postID: String, postType: Comment.PostType, postUserID: String, text: String) {
        let userID = AuthManager.shared.getCurrentUserID() ?? "anonymous"
        let displayName = AuthManager.shared.getDisplayName()
        let collection = postType == .work ? "works" : "questions"
        let isPrivate = postType == .question
        
        let data: [String: Any] = [
            "text": text,
            "userID": userID,
            "displayName": displayName,
            "createdAt": Timestamp(date: Date()),
            "isPrivate": isPrivate,
            "postUserID": postUserID // 投稿者IDを保存（プライベートコメントの表示制御用）
        ]
        
        db.collection(collection)
            .document(postID)
            .collection("comments")
            .addDocument(data: data) { error in
                if let error = error {
                    print("❌ Failed to add comment: \(error)")
                } else {
                    print("✅ Comment added successfully")
                }
            }
    }
    
    // コメントを削除
    func deleteComment(_ comment: Comment) {
        let collection = comment.postType == .work ? "works" : "questions"
        
        db.collection(collection)
            .document(comment.postID)
            .collection("comments")
            .document(comment.id)
            .delete { error in
                if let error = error {
                    print("❌ Failed to delete comment: \(error)")
                } else {
                    print("✅ Comment deleted successfully")
                }
            }
    }
}