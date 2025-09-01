//
//  WorkDetailView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/05.
//

import SwiftUI

struct WorkDetailView: View {
    let post: WorkPost
    @ObservedObject var viewModel: WorkPostViewModel
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    @State private var showAuthorProfile = false
    @State private var showSearchForTag: String?
    @State private var showReportSheet = false
    @StateObject private var likeManager: LikeManager
    @StateObject private var bookmarkManager: BookmarkManager
    
    init(post: WorkPost, viewModel: WorkPostViewModel) {
        self.post = post
        self.viewModel = viewModel
        self._likeManager = StateObject(wrappedValue: LikeManager(postId: post.id, postType: .work))
        self._bookmarkManager = StateObject(wrappedValue: BookmarkManager(postId: post.id, postType: .work))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image
                if let url = post.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
//                                .cornerRadius(12)
                        case .failure(_):
                            Rectangle()
                                .fill(Color(UIColor.tertiarySystemFill))
                                .frame(height: 300)
                                .cornerRadius(12)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                        Text("Failed to load image")
                                            .foregroundColor(.gray)
                                    }
                                )
                        case .empty:
                            Rectangle()
                                .fill(Color(UIColor.quaternarySystemFill))
                                .frame(height: 300)
//                                .cornerRadius(12)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(1.5)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color(UIColor.quaternarySystemFill))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            Text("No image")
                                .foregroundColor(.gray)
                        )
                }
                
                // Title
                Text(post.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Tags
                if !post.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(post.tags, id: \.self) { tag in
                                                TagChip(tag: tag, isClickable: true) {
                                    showSearchForTag = tag
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Author and Date
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            showAuthorProfile = true
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.indigo)
                                Text(post.displayName)
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                            Text(post.createdAt.formatted(date: .long, time: .shortened))
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        // Like button
                        VStack {
                            Button(action: {
                                likeManager.toggleLike()
                            }) {
                                Image(systemName: likeManager.isLiked ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(likeManager.isLiked ? .red : .gray)
                                    .scaleEffect(likeManager.isProcessing ? 0.8 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: likeManager.isProcessing)
                            }
                            .disabled(likeManager.isProcessing || authManager.userID == nil)
                            
                            if likeManager.likesCount > 0 {
                                Text("\(likeManager.likesCount)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Bookmark button
                        Button(action: {
                            bookmarkManager.toggleBookmark()
                        }) {
                            Image(systemName: bookmarkManager.isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.title2)
                                .foregroundColor(bookmarkManager.isBookmarked ? .blue : .gray)
                                .scaleEffect(bookmarkManager.isProcessing ? 0.8 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: bookmarkManager.isProcessing)
                        }
                        .disabled(bookmarkManager.isProcessing || authManager.userID == nil)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Description (if exists)
                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .padding(.horizontal)
                }
                
                // Detail (if exists)
                if let detail = post.detail, !detail.isEmpty {
                    Divider()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    Text("Details")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    
                    Text(detail)
                        .font(.body)
                        .padding(.horizontal)
                }
                
                // Comments section
                CommentView(
                    postID: post.id,
                    postType: .work,
                    postUserID: post.userID
                )
                .padding()
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
        .navigationTitle("Work Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // 自分の投稿の場合のみ編集・削除ボタンを表示
                    if post.canEdit(currentUserID: authManager.userID) {
                        Button(action: {
                            showEditSheet = true
                        }) {
                            Image(systemName: "pencil")
                        }
                        
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .disabled(isDeleting)
                    } else {
                        // 他人の投稿の場合は通報ボタンを表示
                        Button(action: {
                            showReportSheet = true
                        }) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            PostWorkView(viewModel: viewModel, editingPost: post)
        }
        .sheet(isPresented: $showAuthorProfile) {
            NavigationView {
                PublicProfileView(authorUid: post.userID)
            }
        }
        .sheet(item: Binding<IdentifiableString?>(
            get: { showSearchForTag.map { IdentifiableString(id: $0) } },
            set: { showSearchForTag = $0?.value }
        )) { item in
            SearchView(initialSearchText: item.value, initialSearchType: .tag)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportView(
                targetId: post.id,
                targetType: .work,
                targetUserId: post.userID,
                targetTitle: post.title
            )
        }
        .alert("Delete Post", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
    }
    
    private func deletePost() {
        isDeleting = true
        viewModel.deletePost(post) { success in
            if success {
                dismiss()
            } else {
                isDeleting = false
            }
        }
    }
}

#Preview {
    NavigationView {
        WorkDetailView(
            post: WorkPost(
                id: "sample-id",
                title: "Sample Work",
                description: "This is a sample description for the work post. It can be quite long and contain multiple lines of text to show how the layout handles longer content.",
                detail: "Date: Jan 5, 2025\nLocation: Tokyo, Japan\nSettings: f/2.8, 1/200s, ISO 400, 50mm",
                imageURL: URL(string: "https://picsum.photos/400/300"),
                createdAt: Date(),
                userID: "sample-user-id",
                displayName: "Sample User",
                location: nil,
                locationName: nil,
                isActive: true
            ),
            viewModel: WorkPostViewModel()
        )
        .environmentObject(AuthManager.shared)
    }
}
