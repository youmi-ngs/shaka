//
//  NotificationListView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI

// Identifiable wrapper for String
struct IdentifiableString: Identifiable {
    let id: String
    var value: String { id }
}

struct NotificationListView: View {
    @StateObject private var viewModel = NotificationViewModel()
    @State private var selectedProfile: IdentifiableString?
    @State private var showWorkDetail = false
    @State private var showQuestionDetail = false
    @State private var selectedPostId: String?
    
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
                List {
                    ForEach(viewModel.notifications) { notification in
                        NotificationRow(notification: notification)
                            .onTapGesture {
                                handleNotificationTap(notification)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteNotification(notification)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(
                                notification.read ? Color.clear : Color.teal.opacity(0.05)
                            )
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    viewModel.refresh()
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
                selectedPostId = targetId
                if targetType == "work" {
                    // 投稿詳細画面への遷移は現時点では無効化
                    // TODO: WorkDetailViewにpostIdだけで初期化できるイニシャライザを追加
                } else if targetType == "question" {
                    // 質問詳細画面への遷移は現時点では無効化
                    // TODO: QuestionDetailViewにpostIdだけで初期化できるイニシャライザを追加
                }
            }
        case "follow":
            selectedProfile = IdentifiableString(id: notification.actorUid)
        default:
            break
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
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
}
