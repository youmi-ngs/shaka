//
//  PostVisibility.swift
//  Shaka
//
//  Created by Assistant on 2025/01/13.
//

import Foundation

// 投稿の公開範囲
enum PostVisibility: String, Codable, CaseIterable {
    case everyone = "everyone"       // 全員に公開
    case followers = "followers"     // フォロワーのみ
    case mutual = "mutual"          // 相互フォローのみ
    case privateOnly = "private"    // 自分のみ
    
    var displayName: String {
        switch self {
        case .everyone:
            return "Everyone"
        case .followers:
            return "Followers Only"
        case .mutual:
            return "Mutual Followers"
        case .privateOnly:
            return "Private"
        }
    }
    
    var icon: String {
        switch self {
        case .everyone:
            return "globe"
        case .followers:
            return "person.2.fill"
        case .mutual:
            return "person.2.circle.fill"
        case .privateOnly:
            return "lock.fill"
        }
    }
}

// プライバシー設定
struct PrivacySettings: Codable {
    var defaultPostVisibility: PostVisibility = .everyone
    var allowComments: Bool = true
    var allowMessages: Bool = true
    var showLocation: Bool = true
    var showStats: Bool = true
}