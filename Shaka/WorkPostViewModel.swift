//
//  WorkPostViewModel.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/05/01.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import CoreLocation
//import FirebaseFirestoreSwift

class WorkPostViewModel: ObservableObject {
    @Published var posts: [WorkPost] = []
    
//    func addPost(title: String, description: String, imageURL: URL?) {
//        let newPost = WorkPost(title: title, description: description, imageURL: imageURL, createdAt: Date())
//        posts.insert(newPost, at: 0)
//    }
    
    func addPost(title: String, description: String?, detail: String? = nil, imageURL: URL?, location: CLLocationCoordinate2D? = nil, locationName: String? = nil, tags: [String] = []) {
        let userID = AuthManager.shared.getCurrentUserID() ?? "anonymous"
        let displayName = AuthManager.shared.getDisplayName()
        
        var data: [String: Any] = [
            "title": title,
            "imageURL": imageURL?.absoluteString ?? "",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "userID": userID,
            "displayName": displayName,
            "isActive": true
        ]
        
        if let description = description, !description.isEmpty {
            data["description"] = description
        }
        
        if let detail = detail, !detail.isEmpty {
            data["detail"] = detail
        }
        
        // 位置情報を追加
        if let location = location {
            data["location"] = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        }
        
        if let locationName = locationName, !locationName.isEmpty {
            data["locationName"] = locationName
        }
        
        // タグを追加（最大5個）
        if !tags.isEmpty {
            data["tags"] = Array(tags.prefix(5))
        }

        let docRef = db.collection("works").document()
        data["id"] = docRef.documentID
        
        docRef.setData(data) { error in
            if let error = error {
            } else {
                // Add to local array after successful save
                let geoPoint = location != nil ? GeoPoint(latitude: location!.latitude, longitude: location!.longitude) : nil
                let newPost = WorkPost(
                    id: docRef.documentID,
                    title: title,
                    description: description,
                    detail: detail,
                    imageURL: imageURL,
                    createdAt: Date(),
                    userID: userID,
                    displayName: displayName,
                    location: geoPoint,
                    locationName: locationName,
                    isActive: true,
                    tags: tags
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
            }
    }
    
    func deletePost(_ post: WorkPost, completion: @escaping (Bool) -> Void) {
        db.collection("works").document(post.id).delete { error in
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
    
    func togglePostStatus(_ post: WorkPost) {
        let newStatus = !post.isActive
        db.collection("works").document(post.id).updateData([
            "isActive": newStatus,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
            } else {
                // Update local array
                DispatchQueue.main.async {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts[index] = WorkPost(
                            id: post.id,
                            title: post.title,
                            description: post.description,
                            detail: post.detail,
                            imageURL: post.imageURL,
                            createdAt: post.createdAt,
                            userID: post.userID,
                            displayName: post.displayName,
                            location: post.location,
                            locationName: post.locationName,
                            isActive: newStatus
                        )
                    }
                }
            }
        }
    }
    
    func updatePost(_ post: WorkPost, title: String, description: String?, detail: String?, imageURL: URL?, location: CLLocationCoordinate2D? = nil, locationName: String? = nil, tags: [String] = []) {
        var data: [String: Any] = [
            "title": title,
            "imageURL": imageURL?.absoluteString ?? "",
            "updatedAt": Timestamp(date: Date())
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
        
        // 位置情報を更新
        if let location = location {
            let geoPoint = GeoPoint(latitude: location.latitude, longitude: location.longitude)
            data["location"] = geoPoint
        } else if post.location != nil {
            // 既存の位置情報があるが新しい位置情報がnilの場合は削除
            data["location"] = FieldValue.delete()
        }
        
        if let locationName = locationName, !locationName.isEmpty {
            data["locationName"] = locationName
        } else if post.locationName != nil {
            // 既存の位置名があるが新しい位置名がnilまたは空の場合は削除
            data["locationName"] = FieldValue.delete()
        }
        
        // タグを更新
        if !tags.isEmpty {
            data["tags"] = Array(tags.prefix(5))
        } else {
            data["tags"] = []
        }
        
        // 更新時もuserIDとdisplayNameを保持（変更しない）
        db.collection("works").document(post.id).updateData(data) { error in
            if let error = error {
            } else {
                // Update local array
                DispatchQueue.main.async {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        let geoPoint = location != nil ? GeoPoint(latitude: location!.latitude, longitude: location!.longitude) : post.location
                        self.posts[index] = WorkPost(
                            id: post.id,
                            title: title,
                            description: description,
                            detail: detail,
                            imageURL: imageURL,
                            createdAt: post.createdAt,
                            userID: post.userID,
                            displayName: post.displayName,
                            location: geoPoint,
                            locationName: locationName ?? post.locationName,
                            isActive: post.isActive,
                            tags: tags
                        )
                    }
                    // Data updated - DiscoverView will refresh when sheet is dismissed
                }
            }
        }
    }
    
    // 位置情報付きの投稿を取得
    func fetchPostsWithLocation(completion: @escaping ([WorkPost]) -> Void) {
        // まず全てのアクティブな投稿を取得し、クライアント側でフィルタリング
        db.collection("works")
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
                

                let posts = snapshot.documents.compactMap { doc -> WorkPost? in
                    let data = doc.data()
                    let id = doc.documentID
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
                    
                    // locationがある投稿のみ返す（アクティブ/非アクティブ問わず地図に表示）
                    guard location != nil else { 
                        return nil 
                    }

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
                
                completion(posts)
            }
    }
}
