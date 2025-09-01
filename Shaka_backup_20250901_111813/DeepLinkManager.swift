//
//  DeepLinkManager.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import SwiftUI

enum DeepLinkType {
    case addFriend(uid: String)
    case viewProfile(uid: String)
    case viewWork(id: String)
    case viewQuestion(id: String)
}

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    @Published var pendingDeepLink: DeepLinkType?
    @Published var showAddFriendAlert = false
    @Published var friendToAdd: (uid: String, displayName: String)?
    
    private init() {}
    
    // MARK: - URL生成
    func generateAddFriendURL(for uid: String) -> String {
        // Shakaアプリのカスタムスキーマ
        return "shaka://friend/add/\(uid)"
    }
    
    func generateUniversalLink(for uid: String) -> String {
        // 将来的にウェブサイトがある場合のUniversal Link
        return "https://shaka.app/friend/\(uid)"
    }
    
    func generateShareableURL(for uid: String) -> String {
        // 現在はカスタムスキーマを使用
        return generateAddFriendURL(for: uid)
    }
    
    // MARK: - URL処理
    func handleURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }
        
        // カスタムスキーマの処理
        if url.scheme == "shaka" {
            return handleCustomScheme(url: url)
        }
        
        // Universal Linkの処理（将来用）
        if let host = components.host, host == "shaka.app" {
            return handleUniversalLink(components: components)
        }
        
        return false
    }
    
    private func handleCustomScheme(url: URL) -> Bool {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        guard pathComponents.count >= 2 else { return false }
        
        switch pathComponents[0] {
        case "friend":
            if pathComponents.count >= 3 && pathComponents[1] == "add" {
                let uid = pathComponents[2]
                pendingDeepLink = .addFriend(uid: uid)
                processPendingDeepLink()
                return true
            } else if pathComponents.count >= 2 {
                let uid = pathComponents[1]
                pendingDeepLink = .viewProfile(uid: uid)
                processPendingDeepLink()
                return true
            }
            
        case "work":
            if pathComponents.count >= 2 {
                let id = pathComponents[1]
                pendingDeepLink = .viewWork(id: id)
                processPendingDeepLink()
                return true
            }
            
        case "question":
            if pathComponents.count >= 2 {
                let id = pathComponents[1]
                pendingDeepLink = .viewQuestion(id: id)
                processPendingDeepLink()
                return true
            }
            
        default:
            break
        }
        
        return false
    }
    
    private func handleUniversalLink(components: URLComponents) -> Bool {
        guard let path = components.path.components(separatedBy: "/").filter({ !$0.isEmpty }).first else {
            return false
        }
        
        switch path {
        case "friend":
            if let uid = components.path.components(separatedBy: "/").last {
                pendingDeepLink = .addFriend(uid: uid)
                processPendingDeepLink()
                return true
            }
        default:
            break
        }
        
        return false
    }
    
    // MARK: - DeepLink処理
    func processPendingDeepLink() {
        guard let deepLink = pendingDeepLink else { return }
        
        DispatchQueue.main.async { [weak self] in
            switch deepLink {
            case .addFriend(let uid):
                self?.processAddFriend(uid: uid)
                
            case .viewProfile(let uid):
                self?.processViewProfile(uid: uid)
                
            case .viewWork(let id):
                self?.processViewWork(id: id)
                
            case .viewQuestion(let id):
                self?.processViewQuestion(id: id)
            }
            
            self?.pendingDeepLink = nil
        }
    }
    
    private func processAddFriend(uid: String) {
        // まずユーザー情報を取得
        let viewModel = PublicProfileViewModel(authorUid: uid)
        viewModel.fetchProfile()
        
        // 少し待ってから表示（データ取得のため）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.friendToAdd = (uid: uid, displayName: viewModel.displayName)
            self?.showAddFriendAlert = true
        }
    }
    
    private func processViewProfile(uid: String) {
        // ProfileViewやメインビューでハンドリング
        NotificationCenter.default.post(
            name: Notification.Name("ShowProfile"),
            object: nil,
            userInfo: ["uid": uid]
        )
    }
    
    private func processViewWork(id: String) {
        NotificationCenter.default.post(
            name: Notification.Name("ShowWork"),
            object: nil,
            userInfo: ["id": id]
        )
    }
    
    private func processViewQuestion(id: String) {
        NotificationCenter.default.post(
            name: Notification.Name("ShowQuestion"),
            object: nil,
            userInfo: ["id": id]
        )
    }
}