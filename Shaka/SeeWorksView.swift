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
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            NavigationLink(destination: WorkDetailView(post: post, viewModel: viewModel)) {
                                WorkPostCard(post: post)
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
        }
        
        print("✅ Posts refreshed")
    }
}

struct WorkPostCard: View {
    let post: WorkPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image
            if let url = post.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            )
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
                
                HStack {
                    // 作成者名
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(post.displayName)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                    
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
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// NavigationLinkを含むカードビュー
struct WorkPostCardWithLink: View {
    let post: WorkPost
    let viewModel: WorkPostViewModel
    
    var body: some View {
        NavigationLink(destination: WorkDetailView(post: post, viewModel: viewModel)) {
            WorkPostCard(post: post)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SeeWorksView()
}