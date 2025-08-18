//
//  BookmarkManager.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum BookmarkType {
    case work
    case question
}

class BookmarkManager: ObservableObject {
    @Published var isBookmarked = false
    @Published var isProcessing = false
    
    private let postId: String
    private let postType: BookmarkType
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init(postId: String, postType: BookmarkType) {
        self.postId = postId
        self.postType = postType
        setupListener()
    }
    
    deinit {
        listener?.remove()
    }
    
    private func setupListener() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let collection = postType == .work ? "works" : "questions"
        
        listener = db.collection(collection)
            .document(postId)
            .collection("bookmarks")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening to bookmark: \(error)")
                    return
                }
                
                self?.isBookmarked = snapshot?.exists ?? false
            }
    }
    
    func toggleBookmark() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard !isProcessing else { return }
        
        isProcessing = true
        let collection = postType == .work ? "works" : "questions"
        let bookmarkRef = db.collection(collection)
            .document(postId)
            .collection("bookmarks")
            .document(uid)
        
        if isBookmarked {
            // Remove bookmark
            bookmarkRef.delete { [weak self] error in
                self?.isProcessing = false
                if let error = error {
                    print("❌ Error removing bookmark: \(error)")
                } else {
                    print("✅ Bookmark removed")
                    self?.saveToUserBookmarks(uid: uid, remove: true)
                }
            }
        } else {
            // Add bookmark
            let data: [String: Any] = [
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            bookmarkRef.setData(data) { [weak self] error in
                self?.isProcessing = false
                if let error = error {
                    print("❌ Error adding bookmark: \(error)")
                } else {
                    print("✅ Bookmark added")
                    self?.saveToUserBookmarks(uid: uid, remove: false)
                }
            }
        }
    }
    
    private func saveToUserBookmarks(uid: String, remove: Bool) {
        let collection = postType == .work ? "bookmarkedWorks" : "bookmarkedQuestions"
        let userBookmarkRef = db.collection("users")
            .document(uid)
            .collection(collection)
            .document(postId)
        
        if remove {
            userBookmarkRef.delete { error in
                if let error = error {
                    print("❌ Error removing from user bookmarks: \(error)")
                }
            }
        } else {
            let data: [String: Any] = [
                "postId": postId,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            userBookmarkRef.setData(data) { error in
                if let error = error {
                    print("❌ Error adding to user bookmarks: \(error)")
                }
            }
        }
    }
}