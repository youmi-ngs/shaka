//
//  QuestionPostView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/05/01.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

class QuestionPostViewModel: ObservableObject {
    @Published var posts: [QuestionPost] = []
    
    private let db = Firestore.firestore()
    
    func addPost(title: String, body: String, imageURL: URL? = nil, location: CLLocationCoordinate2D? = nil, locationName: String? = nil, tags: [String] = []) {
        let docRef = db.collection("questions").document()
        let userID = AuthManager.shared.getCurrentUserID() ?? "anonymous"
        let displayName = AuthManager.shared.getDisplayName()
        
        var data: [String: Any] = [
            "id": docRef.documentID,
            "title": title,
            "body": body,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "userID": userID,
            "displayName": displayName,
            "isActive": true,
            "isResolved": false,
            "tags": tags
        ]
        
        // 画像URLを追加
        if let imageURL = imageURL {
            data["imageURL"] = imageURL.absoluteString
        }
        
        // 位置情報を追加
        if let location = location {
            data["location"] = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        }
        
        if let locationName = locationName, !locationName.isEmpty {
            data["locationName"] = locationName
        }
        
        docRef.setData(data) { error in
            if let error = error {
                // Handle error silently
            } else {
                // Add to local array after successful save
                let geoPoint = location != nil ? GeoPoint(latitude: location!.latitude, longitude: location!.longitude) : nil
                let newPost = QuestionPost(
                    id: docRef.documentID,
                    title: title,
                    body: body,
                    imageURL: imageURL,
                    createdAt: Date(),
                    userID: userID,
                    displayName: displayName,
                    location: geoPoint,
                    locationName: locationName,
                    isActive: true,
                    isResolved: false,
                    tags: tags
                )
                DispatchQueue.main.async {
                    self.posts.insert(newPost, at: 0)
                }
            }
        }
    }
    
    func fetchPosts() {
        db.collection("questions")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                self.posts = snapshot.documents.compactMap { doc in
                    let data = doc.data()
                    let id = doc.documentID
                    let title = data["title"] as? String ?? ""
                    let body = data["body"] as? String ?? ""
                    let imageURLString = data["imageURL"] as? String
                    let imageURL = imageURLString != nil ? URL(string: imageURLString!) : nil
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let userID = data["userID"] as? String ?? "unknown"
                    let displayName = data["displayName"] as? String ?? "User_\(String(userID.prefix(6)))"
                    let location = data["location"] as? GeoPoint
                    let locationName = data["locationName"] as? String
                    let isActive = data["isActive"] as? Bool ?? true
                    let isResolved = data["isResolved"] as? Bool ?? false
                    let tags = data["tags"] as? [String] ?? []
                    
                    return QuestionPost(
                        id: id,
                        title: title,
                        body: body,
                        imageURL: imageURL,
                        createdAt: createdAt,
                        userID: userID,
                        displayName: displayName,
                        location: location,
                        locationName: locationName,
                        isActive: isActive,
                        isResolved: isResolved,
                        tags: tags
                    )
                }
            }
    }
    
    func deletePost(_ post: QuestionPost, completion: @escaping (Bool) -> Void) {
        db.collection("questions").document(post.id).delete { error in
            if let error = error {
                completion(false)
            } else {
                // Remove from local array
                DispatchQueue.main.async {
                    self.posts.removeAll { $0.id == post.id }
                }
                completion(true)
            }
        }
    }
    
    func togglePostStatus(_ post: QuestionPost) {
        let newStatus = !post.isActive
        db.collection("questions").document(post.id).updateData([
            "isActive": newStatus,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                // Handle error silently
            } else {
                // Update local array
                DispatchQueue.main.async {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts[index] = QuestionPost(
                            id: post.id,
                            title: post.title,
                            body: post.body,
                            imageURL: post.imageURL,
                            createdAt: post.createdAt,
                            userID: post.userID,
                            displayName: post.displayName,
                            location: post.location,
                            locationName: post.locationName,
                            isActive: newStatus,
                            isResolved: post.isResolved,
                            tags: post.tags
                        )
                    }
                }
            }
        }
    }
    
    func updatePost(_ post: QuestionPost, title: String, body: String, imageURL: URL? = nil, location: CLLocationCoordinate2D? = nil, locationName: String? = nil, tags: [String] = []) {
        var data: [String: Any] = [
            "title": title,
            "body": body,
            "updatedAt": Timestamp(date: Date()),
            "tags": tags
        ]
        
        // 画像URLを更新
        if let imageURL = imageURL {
            data["imageURL"] = imageURL.absoluteString
        } else if post.imageURL != nil {
            // 既存の画像URLを保持
            data["imageURL"] = post.imageURL!.absoluteString
        }
        
        // 位置情報を更新
        if let location = location {
            data["location"] = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        }
        
        if let locationName = locationName {
            data["locationName"] = locationName
        }
        
        db.collection("questions").document(post.id).updateData(data) { error in
            if let error = error {
                // Handle error silently
            } else {
                // Update local array
                DispatchQueue.main.async {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        let geoPoint = location != nil ? GeoPoint(latitude: location!.latitude, longitude: location!.longitude) : post.location
                        let finalImageURL = imageURL ?? post.imageURL
                        self.posts[index] = QuestionPost(
                            id: post.id,
                            title: title,
                            body: body,
                            imageURL: finalImageURL,
                            createdAt: post.createdAt,
                            userID: post.userID,
                            displayName: post.displayName,
                            location: geoPoint,
                            locationName: locationName ?? post.locationName,
                            isActive: post.isActive,
                            isResolved: post.isResolved,
                            tags: tags
                        )
                    }
                }
            }
        }
    }
    
    // 位置情報付きの質問を取得
    func fetchPostsWithLocation(completion: @escaping ([QuestionPost]) -> Void) {
        db.collection("questions")
            .whereField("location", isNotEqualTo: NSNull())
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion([])
                    return
                }

                guard let snapshot = snapshot else {
                    completion([])
                    return
                }

                let posts = snapshot.documents.compactMap { doc in
                    let data = doc.data()
                    let id = doc.documentID
                    let title = data["title"] as? String ?? ""
                    let body = data["body"] as? String ?? ""
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let userID = data["userID"] as? String ?? "unknown"
                    let displayName = data["displayName"] as? String ?? "User_\(String(userID.prefix(6)))"
                    let location = data["location"] as? GeoPoint
                    let locationName = data["locationName"] as? String
                    let isActive = data["isActive"] as? Bool ?? true
                    let isResolved = data["isResolved"] as? Bool ?? false

                    return QuestionPost(
                        id: id,
                        title: title,
                        body: body,
                        imageURL: nil,
                        createdAt: createdAt,
                        userID: userID,
                        displayName: displayName,
                        location: location,
                        locationName: locationName,
                        isActive: isActive,
                        isResolved: isResolved,
                        tags: []
                    )
                }
                
                completion(posts)
            }
    }
    
    // 解決済みステータスをトグル
    func toggleResolvedStatus(_ post: QuestionPost) {
        let newStatus = !post.isResolved
        db.collection("questions").document(post.id).updateData([
            "isResolved": newStatus,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
            } else {
                // Update local array
                DispatchQueue.main.async {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts[index] = QuestionPost(
                            id: post.id,
                            title: post.title,
                            body: post.body,
                            imageURL: post.imageURL,
                            createdAt: post.createdAt,
                            userID: post.userID,
                            displayName: post.displayName,
                            location: post.location,
                            locationName: post.locationName,
                            isActive: post.isActive,
                            isResolved: newStatus,
                            tags: post.tags
                        )
                    }
                }
            }
        }
    }
}
