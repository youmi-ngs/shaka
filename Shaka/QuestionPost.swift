//
//  QuestionPost.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/30.
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct QuestionPost: Identifiable {
    let id: String
    let title: String
    let body: String
    let imageURL: URL?  // 任意の画像
    let createdAt: Date
    let userID: String
    let displayName: String
    
    // 位置情報関連
    let location: GeoPoint?
    let locationName: String?
    
    // ステータス関連
    let isActive: Bool
    
    // タグ（最大5個）
    let tags: [String]
    
    // 編集・削除権限のチェック
    func canEdit(currentUserID: String?) -> Bool {
        guard let currentUserID = currentUserID else { return false }
        return userID == currentUserID
    }
    
    // CLLocationCoordinate2Dへの変換
    var coordinate: CLLocationCoordinate2D? {
        guard let location = location else { return nil }
        return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
    
    // デフォルトイニシャライザ（既存のコード互換性のため）
    init(id: String, title: String, body: String, imageURL: URL? = nil, createdAt: Date, 
         userID: String, displayName: String,
         location: GeoPoint? = nil, locationName: String? = nil, isActive: Bool = true,
         tags: [String] = []) {
        self.id = id
        self.title = title
        self.body = body
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.userID = userID
        self.displayName = displayName
        self.location = location
        self.locationName = locationName
        self.isActive = isActive
        self.tags = tags
    }
}
