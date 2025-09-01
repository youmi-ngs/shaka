//
//  Friend.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import FirebaseFirestore

struct Friend: Codable, Identifiable {
    let id: String // friendUid
    let createdAt: Date
    
    // Join用のユーザー情報（取得後に設定）
    var displayName: String?
    var photoURL: String?
    var bio: String?
    
    init(id: String, createdAt: Date, displayName: String? = nil, photoURL: String? = nil, bio: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.displayName = displayName
        self.photoURL = photoURL
        self.bio = bio
    }
    
    init(from document: DocumentSnapshot) {
        self.id = document.documentID
        let data = document.data() ?? [:]
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.displayName = nil
        self.photoURL = nil
        self.bio = nil
    }
}

// フレンドリクエスト（将来用）
struct FriendRequest: Codable, Identifiable {
    let id: String // fromUserId
    let createdAt: Date
    let message: String?
    
    // Join用のユーザー情報
    var displayName: String?
    var photoURL: String?
    
    init(id: String, createdAt: Date, message: String? = nil, displayName: String? = nil, photoURL: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.message = message
        self.displayName = displayName
        self.photoURL = photoURL
    }
}