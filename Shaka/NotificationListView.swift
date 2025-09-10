//
//  NotificationListView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI
import FirebaseFirestore

// Identifiable wrapper for String
struct IdentifiableString: Identifiable {
    let id: String
    var value: String { id }
}

struct NotificationListView: View {
    @StateObject private var viewModel = NotificationViewModel()
    @StateObject private var workViewModel = WorkPostViewModel()
    @StateObject private var questionViewModel = QuestionPostViewModel()
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedProfile: IdentifiableString?
    @State private var selectedWork: WorkPost?
    @State private var selectedQuestion: QuestionPost?
    @State private var postTitles: [String: String] = [:]  // postId: title のキャッシュ
    
    var body: some View {
        ZStack {
            if viewModel.notifications.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No notifications yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("When someone likes or comments on your posts, you'll see it here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.notifications) { notification in
                                VStack(spacing: 0) {
                                    HStack(alignment: .top, spacing: 12) {
                                        // ユーザーアバター（タップ可能）
                                        UserAvatarView(uid: notification.actorUid, size: 40)
                                            .onTapGesture {
                                                print("🔴 Avatar tapped for: \(notification.actorUid)")
                                                selectedProfile = IdentifiableString(id: notification.actorUid)
                                            }
                                        
                                        // コンテンツ（タップ可能）
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 4) {
                                                Text(formatNotificationMessage(notification, postTitle: postTitles[notification.targetId ?? ""]))
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)
                                                
                                                // タイプアイコン（小さく表示）
                                                Image(systemName: notification.icon)
                                                    .foregroundColor(Color(notification.iconColor))
                                                    .font(.system(size: 12))
                                            }
                                            
                                            if let snippet = notification.snippet {
                                                Text(snippet)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Text(RelativeDateTimeFormatter().localizedString(for: notification.createdAt, relativeTo: Date()))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            handleNotificationTap(notification)
                                        }
                                        
                                        Spacer()
                                        
                                        // 未読インジケーター
                                        if !notification.read {
                                            Circle()
                                                .fill(Color.teal)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                    .background(notification.read ? Color.clear : Color.teal.opacity(0.05))
                                    
                                    Divider()
                                }
                            }
                        }
                    }
                .refreshable {
                    viewModel.refresh()
                    // 少し待ってからタイトルを再取得
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        fetchPostTitles()
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.unreadCount > 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark All Read") {
                        viewModel.markAllAsRead()
                    }
                    .font(.caption)
                }
            }
        }
        .sheet(item: $selectedProfile) { item in
            NavigationView {
                PublicProfileView(authorUid: item.value)
            }
        }
        .sheet(item: $selectedWork) { work in
            NavigationView {
                WorkDetailView(post: work, viewModel: workViewModel)
            }
            .onAppear {
                print("📄 Work sheet opened for: \(work.title)")
            }
        }
        .sheet(item: $selectedQuestion) { question in
            NavigationView {
                QuestionDetailView(post: question, viewModel: questionViewModel)
            }
            .onAppear {
                print("📄 Question sheet opened for: \(question.title)")
            }
        }
        .onAppear {
            // 通知のタイトルを非同期で取得
            fetchPostTitles()
        }
    }
    
    private func fetchPostTitles() {
        Task {
            for notification in viewModel.notifications {
                if let targetId = notification.targetId,
                   postTitles[targetId] == nil {  // まだ取得していない場合のみ
                    
                    if notification.targetType == "work" {
                        if let work = await fetchWork(id: targetId) {
                            await MainActor.run {
                                postTitles[targetId] = work.title
                            }
                        }
                    } else if notification.targetType == "question" {
                        if let question = await fetchQuestion(id: targetId) {
                            await MainActor.run {
                                postTitles[targetId] = question.title
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func formatNotificationMessage(_ notification: AppNotification, postTitle: String? = nil) -> String {
        let formattedMessage: String
        // 現在の名前があればそれを使用、なければ通知作成時の名前を使用
        let displayName = notification.currentActorName ?? notification.actorName
        
        switch notification.type {
        case "like":
            // キャッシュされたタイトルがあればそれを使用
            if let title = postTitle, !title.isEmpty {
                formattedMessage = "\(displayName) liked your \(notification.targetType ?? "post") \"\(title)\""
            } else if let snippet = notification.snippet, !snippet.isEmpty {
                formattedMessage = "\(displayName) liked your \(notification.targetType ?? "post") \"\(snippet)\""
            } else {
                // targetTypeによってメッセージを変える
                if notification.targetType == "work" {
                    formattedMessage = "\(displayName) liked your work"
                } else if notification.targetType == "question" {
                    formattedMessage = "\(displayName) liked your question"
                } else {
                    formattedMessage = "\(displayName) liked your post"
                }
            }
        case "comment":
            if let title = postTitle, !title.isEmpty {
                formattedMessage = "\(displayName) commented on \"\(title)\""
            } else if let snippet = notification.snippet, !snippet.isEmpty {
                formattedMessage = "\(displayName) commented on \"\(snippet)\""
            } else {
                if notification.targetType == "work" {
                    formattedMessage = "\(displayName) commented on your work"
                } else if notification.targetType == "question" {
                    formattedMessage = "\(displayName) commented on your question"
                } else {
                    formattedMessage = "\(displayName) commented on your post"
                }
            }
        case "follow":
            formattedMessage = "\(displayName) started following you"
        default:
            formattedMessage = notification.message
        }
        
        return formattedMessage
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        // 既読にする
        if !notification.read {
            viewModel.markAsRead(notification)
        }
        
        // 適切な画面に遷移
        switch notification.type {
        case "like", "comment":
            if let targetType = notification.targetType,
               let targetId = notification.targetId {
                if targetType == "work" {
                    // 投稿詳細を取得して表示
                    Task {
                        if let work = await fetchWork(id: targetId) {
                            await MainActor.run {
                                selectedWork = work
                            }
                        }
                    }
                } else if targetType == "question" {
                    // 質問詳細を取得して表示
                    Task {
                        if let question = await fetchQuestion(id: targetId) {
                            await MainActor.run {
                                selectedQuestion = question
                            }
                        }
                    }
                }
            }
        case "follow":
            // フォロー通知の場合はプロフィールへ
            selectedProfile = IdentifiableString(id: notification.actorUid)
        default:
            break
        }
    }
    
    private func fetchWork(id: String) async -> WorkPost? {
        // Firestoreから投稿を取得 - worksコレクションから取得
        do {
            let snapshot = try await Firestore.firestore()
                .collection("works")
                .document(id)
                .getDocument()
            
            if let data = snapshot.data(),
               snapshot.exists {
                // 手動でデータをマッピング
                let id = snapshot.documentID
                let title = data["title"] as? String ?? ""
                let description = data["description"] as? String
                let detail = data["detail"] as? String
                let imageURLString = data["imageURL"] as? String
                let imageURL = imageURLString.flatMap { URL(string: $0) }
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let userID = data["userID"] as? String ?? ""
                let displayName = data["displayName"] as? String ?? ""
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
        } catch {
            print("Error fetching work: \(error)")
        }
        
        return nil
    }
    
    private func fetchQuestion(id: String) async -> QuestionPost? {
        // Firestoreから質問を取得
        do {
            let snapshot = try await Firestore.firestore()
                .collection("questions")
                .document(id)
                .getDocument()
            
            if let data = snapshot.data(),
               snapshot.exists {
                // 手動でデータをマッピング
                let id = snapshot.documentID
                let title = data["title"] as? String ?? ""
                let body = data["body"] as? String ?? ""
                let imageURLString = data["imageURL"] as? String
                let imageURL = imageURLString.flatMap { URL(string: $0) }
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let userID = data["userID"] as? String ?? ""
                let displayName = data["displayName"] as? String ?? ""
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
        } catch {
            print("Error fetching question: \(error)")
        }
        return nil
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onUserTap: () -> Void
    let onNotificationTap: () -> Void
    @State private var userPhotoURL: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // ユーザーアバター
            UserAvatarView(uid: notification.actorUid, size: 40)
            
            // コンテンツ
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(notification.message)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    // タイプアイコン（小さく表示）
                    Image(systemName: notification.icon)
                        .foregroundColor(Color(notification.iconColor))
                        .font(.system(size: 12))
                }
                
                if let snippet = notification.snippet {
                    Text(snippet)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(timeAgo(from: notification.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 未読インジケーター
            if !notification.read {
                Circle()
                    .fill(Color.teal)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NotificationListView()
        .environmentObject(DeepLinkManager.shared)
}
