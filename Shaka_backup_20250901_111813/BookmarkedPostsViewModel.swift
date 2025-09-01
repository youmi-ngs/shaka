//
//  BookmarkedPostsViewModel.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class BookmarkedPostsViewModel: ObservableObject {
    @Published var bookmarkedWorks: [WorkPost] = []
    @Published var bookmarkedQuestions: [QuestionPost] = []
    @Published var isLoadingWorks = false
    @Published var isLoadingQuestions = false
    
    private var db = Firestore.firestore()
    
    func fetchBookmarkedPosts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        fetchBookmarkedWorks(uid: uid)
        fetchBookmarkedQuestions(uid: uid)
    }
    
    private func fetchBookmarkedWorks(uid: String) {
        isLoadingWorks = true
        
        // ユーザーのブックマークコレクションから投稿IDを取得
        db.collection("users")
            .document(uid)
            .collection("bookmarkedWorks")
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching bookmarked works: \(error)")
                    self.isLoadingWorks = false
                    return
                }
                
                let postIds = snapshot?.documents.map { $0.documentID } ?? []
                
                if postIds.isEmpty {
                    self.bookmarkedWorks = []
                    self.isLoadingWorks = false
                    return
                }
                
                // 投稿の詳細を取得
                self.fetchWorkDetails(postIds: postIds)
            }
    }
    
    private func fetchWorkDetails(postIds: [String]) {
        let group = DispatchGroup()
        var works: [WorkPost] = []
        
        for postId in postIds {
            group.enter()
            
            db.collection("works")
                .document(postId)
                .getDocument { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error fetching work \(postId): \(error)")
                        return
                    }
                    
                    guard let data = snapshot?.data(),
                          let post = self.createWorkPost(from: data, id: postId) else {
                        return
                    }
                    
                    works.append(post)
                }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.bookmarkedWorks = works.sorted { $0.createdAt > $1.createdAt }
            self?.isLoadingWorks = false
        }
    }
    
    private func fetchBookmarkedQuestions(uid: String) {
        isLoadingQuestions = true
        
        db.collection("users")
            .document(uid)
            .collection("bookmarkedQuestions")
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching bookmarked questions: \(error)")
                    self.isLoadingQuestions = false
                    return
                }
                
                let postIds = snapshot?.documents.map { $0.documentID } ?? []
                
                if postIds.isEmpty {
                    self.bookmarkedQuestions = []
                    self.isLoadingQuestions = false
                    return
                }
                
                // 投稿の詳細を取得
                self.fetchQuestionDetails(postIds: postIds)
            }
    }
    
    private func fetchQuestionDetails(postIds: [String]) {
        let group = DispatchGroup()
        var questions: [QuestionPost] = []
        
        for postId in postIds {
            group.enter()
            
            db.collection("questions")
                .document(postId)
                .getDocument { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error fetching question \(postId): \(error)")
                        return
                    }
                    
                    guard let data = snapshot?.data(),
                          let post = self.createQuestionPost(from: data, id: postId) else {
                        return
                    }
                    
                    questions.append(post)
                }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.bookmarkedQuestions = questions.sorted { $0.createdAt > $1.createdAt }
            self?.isLoadingQuestions = false
        }
    }
    
    private func createWorkPost(from data: [String: Any], id: String) -> WorkPost? {
        let title = data["title"] as? String ?? ""
        let description = data["description"] as? String
        let detail = data["detail"] as? String
        let imageURLString = data["imageURL"] as? String
        let imageURL: URL? = imageURLString != nil ? URL(string: imageURLString!) : nil
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let userID = data["userID"] as? String ?? "unknown"
        let displayName = data["displayName"] as? String ?? "User_\(String(userID.prefix(6)))"
        let location = data["location"] as? GeoPoint
        let locationName = data["locationName"] as? String
        let isActive = data["isActive"] as? Bool ?? true
        let tags = data["tags"] as? [String] ?? []
        
        return WorkPost(
            id: id,
            title: title,
            description: description,
            detail: detail,
            imageURL: imageURL,
            createdAt: createdAt,
            userID: userID,
            displayName: displayName,
            location: location,
            locationName: locationName,
            isActive: isActive,
            tags: tags
        )
    }
    
    private func createQuestionPost(from data: [String: Any], id: String) -> QuestionPost? {
        let title = data["title"] as? String ?? ""
        let body = data["body"] as? String ?? ""
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let userID = data["userID"] as? String ?? "unknown"
        let displayName = data["displayName"] as? String ?? "User_\(String(userID.prefix(6)))"
        let location = data["location"] as? GeoPoint
        let locationName = data["locationName"] as? String
        let isActive = data["isActive"] as? Bool ?? true
        let tags = data["tags"] as? [String] ?? []
        
        return QuestionPost(
            id: id,
            title: title,
            body: body,
            createdAt: createdAt,
            userID: userID,
            displayName: displayName,
            location: location,
            locationName: locationName,
            isActive: isActive,
            tags: tags
        )
    }
}