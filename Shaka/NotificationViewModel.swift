//
//  NotificationViewModel.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

struct AppNotification: Identifiable {
    let id: String
    let type: String // like, follow, comment
    let actorUid: String
    let actorName: String
    let targetType: String? // work, question
    let targetId: String?
    let message: String
    let snippet: String?
    let createdAt: Date
    var read: Bool
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.type = data["type"] as? String ?? ""
        self.actorUid = data["actorUid"] as? String ?? ""
        self.actorName = data["actorName"] as? String ?? "Someone"
        self.targetType = data["targetType"] as? String
        self.targetId = data["targetId"] as? String
        self.message = data["message"] as? String ?? ""
        self.snippet = data["snippet"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.read = data["read"] as? Bool ?? false
    }
    
    var icon: String {
        switch type {
        case "like":
            return "heart.fill"
        case "follow":
            return "person.badge.plus.fill"
        case "comment":
            return "bubble.left.fill"
        default:
            return "bell.fill"
        }
    }
    
    var iconColor: String {
        switch type {
        case "like":
            return "red"
        case "follow":
            return "blue"
        case "comment":
            return "green"
        default:
            return "gray"
        }
    }
}

class NotificationViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupListener()
    }
    
    deinit {
        listener?.remove()
    }
    
    private func setupListener() {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        // 既存のリスナーを削除
        listener?.remove()
        
        // 新しいリスナーを設定
        listener = db.collection("notifications")
            .document(uid)
            .collection("items")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.notifications = []
                    self?.unreadCount = 0
                    return
                }
                
                // 通知を変換
                self?.notifications = documents.compactMap { doc in
                    AppNotification(id: doc.documentID, data: doc.data())
                }
                
                // 未読数を計算
                self?.unreadCount = self?.notifications.filter { !$0.read }.count ?? 0
                
            }
    }
    
    func markAsRead(_ notification: AppNotification) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("notifications")
            .document(uid)
            .collection("items")
            .document(notification.id)
            .updateData(["read": true]) { error in
                if let error = error {
                } else {
                }
            }
    }
    
    func markAllAsRead() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        let unreadNotifications = notifications.filter { !$0.read }
        
        for notification in unreadNotifications {
            let ref = db.collection("notifications")
                .document(uid)
                .collection("items")
                .document(notification.id)
            batch.updateData(["read": true], forDocument: ref)
        }
        
        batch.commit { error in
            if let error = error {
            } else {
            }
        }
    }
    
    func deleteNotification(_ notification: AppNotification) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("notifications")
            .document(uid)
            .collection("items")
            .document(notification.id)
            .delete { error in
                if let error = error {
                } else {
                }
            }
    }
    
    func refresh() {
        setupListener()
    }
}