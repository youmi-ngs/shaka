//
//  WorkPostViewModel.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/05/01.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
//import FirebaseFirestoreSwift

class WorkPostViewModel: ObservableObject {
    @Published var posts: [WorkPost] = []
    
//    func addPost(title: String, description: String, imageURL: URL?) {
//        let newPost = WorkPost(title: title, description: description, imageURL: imageURL, createdAt: Date())
//        posts.insert(newPost, at: 0)
//    }
    
    func addPost(title: String, description: String, imageURL: URL?) {
        let newPost = WorkPost(title: title, description: description, imageURL: imageURL, createdAt: Date())
        posts.insert(newPost, at: 0)

        let data: [String: Any] = [
            "title": newPost.title,
            "description": newPost.description,
            "imageURL": newPost.imageURL?.absoluteString ?? "",
            "createdAt": Timestamp(date: newPost.createdAt)
        ]

        db.collection("works").addDocument(data: data) { error in
            if let error = error {
                print("🔥 Firestore 書き込み失敗:", error.localizedDescription)
            } else {
                print("✅ Firestore に保存完了！")
            }
        }
    }
    
    private let db = Firestore.firestore()
    
    func fetchPosts() {
        db.collection("works")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching documents: \(error)")
                    return
                }

                guard let snapshot = snapshot else { return }

                self.posts = snapshot.documents.compactMap { doc in
                    let data = doc.data()
                    let title = data["title"] as? String ?? ""
                    let description = data["description"] as? String ?? ""
                    let imageURLString = data["imageURL"] as? String
                    let imageURL: URL? = imageURLString != nil ? URL(string: imageURLString!) : nil
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                    return WorkPost(title: title, description: description, imageURL: imageURL, createdAt: createdAt)
                }
            }
    }
}
