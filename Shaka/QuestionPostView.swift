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
    
    func addPost(title: String, body: String, location: CLLocationCoordinate2D? = nil, locationName: String? = nil) {
        let docRef = db.collection("questions").document()
        let userID = AuthManager.shared.getCurrentUserID() ?? "anonymous"
        let displayName = AuthManager.shared.getDisplayName()
        print("📝 Creating question with userID: \(userID), displayName: \(displayName)")
        
        var data: [String: Any] = [
            "id": docRef.documentID,
            "title": title,
            "body": body,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "userID": userID,
            "displayName": displayName,
            "isActive": true
        ]
        
        // 位置情報を追加
        if let location = location {
            data["location"] = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        }
        
        if let locationName = locationName, !locationName.isEmpty {
            data["locationName"] = locationName
        }
        
        docRef.setData(data) { error in
            if let error = error {
                print("Error saving question to Firestore: \(error)")
            } else {
                print("Question successfully saved to Firestore!")
                // Add to local array after successful save
                let geoPoint = location != nil ? GeoPoint(latitude: location!.latitude, longitude: location!.longitude) : nil
                let newPost = QuestionPost(
                    id: docRef.documentID,
                    title: title,
                    body: body,
                    createdAt: Date(),
                    userID: userID,
                    displayName: displayName,
                    location: geoPoint,
                    locationName: locationName,
                    isActive: true
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
                    print("Error fetching questions: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                self.posts = snapshot.documents.compactMap { doc in
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
                    
                    return QuestionPost(
                        id: id,
                        title: title,
                        body: body,
                        createdAt: createdAt,
                        userID: userID,
                        displayName: displayName,
                        location: location,
                        locationName: locationName,
                        isActive: isActive
                    )
                }
            }
    }
    
    func deletePost(_ post: QuestionPost, completion: @escaping (Bool) -> Void) {
        db.collection("questions").document(post.id).delete { error in
            if let error = error {
                print("❌ Failed to delete question: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Question deleted successfully")
                // Remove from local array
                DispatchQueue.main.async {
                    self.posts.removeAll { $0.id == post.id }
                }
                completion(true)
            }
        }
    }
    
    func updatePost(_ post: QuestionPost, title: String, body: String, location: CLLocationCoordinate2D? = nil, locationName: String? = nil) {
        var data: [String: Any] = [
            "title": title,
            "body": body,
            "updatedAt": Timestamp(date: Date())
        ]
        
        // 位置情報を更新
        if let location = location {
            data["location"] = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        }
        
        if let locationName = locationName {
            data["locationName"] = locationName
        }
        
        db.collection("questions").document(post.id).updateData(data) { error in
            if let error = error {
                print("❌ Failed to update question: \(error.localizedDescription)")
            } else {
                print("✅ Question updated successfully")
                // Update local array
                DispatchQueue.main.async {
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        let geoPoint = location != nil ? GeoPoint(latitude: location!.latitude, longitude: location!.longitude) : post.location
                        self.posts[index] = QuestionPost(
                            id: post.id,
                            title: title,
                            body: body,
                            createdAt: post.createdAt,
                            userID: post.userID,
                            displayName: post.displayName,
                            location: geoPoint,
                            locationName: locationName ?? post.locationName,
                            isActive: post.isActive
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
                    print("Error fetching questions with location: \(error)")
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

                    return QuestionPost(
                        id: id,
                        title: title,
                        body: body,
                        createdAt: createdAt,
                        userID: userID,
                        displayName: displayName,
                        location: location,
                        locationName: locationName,
                        isActive: isActive
                    )
                }
                
                completion(posts)
            }
    }
}
