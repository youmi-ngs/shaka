//
//  SeeWorksView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI

struct SeeWorksView: View {
    @StateObject private var viewModel = WorkPostViewModel()
    @State private var showPostWork = false
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            NavigationLink(destination: WorkDetailView(post: post, viewModel: viewModel)) {
                                WorkPostCard(post: post, viewModel: viewModel, refreshID: refreshID)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .id(post.id)
                            .zIndex(Double(viewModel.posts.count - index))
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    // プルトゥリフレッシュ
                    await refreshPosts()
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showPostWork = true
                        }) {
                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding()
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding()
                        .sheet(isPresented: $showPostWork) {
                            PostWorkView(viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("See Works")
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear {
                viewModel.fetchPosts()
            }
        }
    }
    
    // リフレッシュ処理
    private func refreshPosts() async {
        // 少し待機してからデータを再取得（UX向上のため）
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // メインスレッドでfetchを実行
        await MainActor.run {
            viewModel.fetchPosts()
            // 画像の再読み込みを強制
            refreshID = UUID()
        }
        
        print("✅ Posts refreshed - Total: \(viewModel.posts.count)")
        for post in viewModel.posts {
            print("📷 Post: \(post.title), URL: \(post.imageURL?.absoluteString ?? "No URL")")
        }
    }
}

struct WorkPostCard: View {
    let post: WorkPost
    @ObservedObject var viewModel: WorkPostViewModel
    var refreshID: UUID = UUID()
    @State private var showAuthorProfile = false
    @State private var showSearchForTag: String?
    @StateObject private var likeManager: LikeManager
    
    init(post: WorkPost, viewModel: WorkPostViewModel, refreshID: UUID = UUID()) {
        self.post = post
        self.viewModel = viewModel
        self.refreshID = refreshID
        self._likeManager = StateObject(wrappedValue: LikeManager(postId: post.id, postType: .work))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image
            if let url = post.imageURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                    case .failure(let error):
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "wifi.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(error.localizedDescription)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            )
                            .onTapGesture {
                                // タップで再読み込みを試みる
                                viewModel.fetchPosts()
                            }
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 200)
                            .overlay(
                                ProgressView()
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .id("\(post.id)_\(refreshID)")
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No image")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 8) {
                Text(post.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let description = post.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // タグ表示
                if !post.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(post.tags, id: \.self) { tag in
                                TagChip(tag: tag, isClickable: true) {
                                    showSearchForTag = tag
                                }
                            }
                        }
                    }
                }
                
                HStack {
                    // 作成者名（タップ可能）
                    Button(action: {
                        showAuthorProfile = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(post.displayName)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // 作成日時
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // いいねボタン
                    Button(action: {
                        likeManager.toggleLike()
                    }) {
                        Image(systemName: likeManager.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(likeManager.isLiked ? .red : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
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
    }
}

// NavigationLinkを含むカードビュー
struct WorkPostCardWithLink: View {
    let post: WorkPost
    let viewModel: WorkPostViewModel
    
    var body: some View {
        NavigationLink(destination: WorkDetailView(post: post, viewModel: viewModel)) {
            WorkPostCard(post: post, viewModel: viewModel, refreshID: UUID())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SeeWorksView()
}