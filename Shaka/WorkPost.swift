//
//  WorkPost.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/30.
//

import Foundation

struct WorkPost: Identifiable {
    let id: String
    let title: String
    let description: String?
    let detail: String?
    let imageURL: URL?
    let createdAt: Date
    let userID: String
    let displayName: String
    
    // 編集・削除権限のチェック
    func canEdit(currentUserID: String?) -> Bool {
        guard let currentUserID = currentUserID else { return false }
        return userID == currentUserID
    }
}
