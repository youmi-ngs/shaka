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
    
    func addPost(title: String, description: String?, detail: String? = nil, imageURL: URL?) {
        var data: [String: Any] = [
            "title": title,
            "imageURL": imageURL?.absoluteString ?? "",
            "createdAt": Timestamp(date: Date())
        ]
        
        if let description = description, !description.isEmpty {
            data["description"] = description
        }
        
        if let detail = detail, !detail.isEmpty {
            data["detail"] = detail
        }

        let docRef = db.collection("works").document()
        data["id"] = docRef.documentID
        
        docRef.setData(data) { error in
            if let error = error {
                print("🔥 Firestore 書き込み失敗:", error.localizedDescription)
            } else {
                print("✅ Firestore に保存完了！")
                // Add to local array after successful save
                let newPost = WorkPost(
                    id: docRef.documentID,
                    title: title,
                    description: description,
                    detail: detail,
                    imageURL: imageURL,
                    createdAt: Date()
                )
                DispatchQueue.main.async {
                    self.posts.insert(newPost, at: 0)
                }
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
                    let id = doc.documentID
                    let title = data["title"] as? String ?? ""
                    let description = data["description"] as? String
                    let detail = data["detail"] as? String
                    let imageURLString = data["imageURL"] as? String
                    let imageURL: URL? = imageURLString != nil ? URL(string: imageURLString!) : nil
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                    return WorkPost(id: id, title: title, description: description, detail: detail, imageURL: imageURL, createdAt: createdAt)
                }
            }
    }
    
    func deletePost(_ post: WorkPost, completion: @escaping (Bool) -> Void) {
        db.collection("works").document(post.id).delete { error in
            if let error = error {
                print("❌ Failed to delete post: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Post deleted successfully")
                // Remove from local array
                DispatchQueue.main.async {
                    self.posts.removeAll { $0.id == post.id }
                }
                completion(true)
            }
        }
    }
    
    func updatePost(_ post: WorkPost, title: String, description: String?, detail: String?, imageURL: URL?) {
        var data: [String: Any] = [
            "title": title,
            "imageURL": imageURL?.absoluteString ?? ""
        ]
        
        if let description = description, !description.isEmpty {
            data["description"] = description
        } else {
            data["description"] = FieldValue.delete()
        }
        
        if let detail = detail, !detail.isEmpty {
            data["detail"] = detail
        } else {
            data["detail"] = FieldValue.delete()
        }
        
        db.collection("works").document(post.id).updateData(data) { error in
            if let error = error {
                print("❌ Failed to update post: \(error.localizedDescription)")
            } else {
                print("✅ Post updated successfully")
                // Update local array
                DispatchQueue.main.async {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts[index] = WorkPost(
                            id: post.id,
                            title: title,
                            description: description,
                            detail: detail,
                            imageURL: imageURL,
                            createdAt: post.createdAt
                        )
                    }
                }
            }
        }
    }
}
