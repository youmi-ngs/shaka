//
//  AskView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI

struct AskView: View {
    @StateObject private var viewModel = QuestionPostViewModel()
    @State private var showPostQuestion = false
    @State private var selectedFilter: PostFilter = .all
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(PostFilter.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.systemImage)
                            .tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color(UIColor.systemBackground))
                .onChange(of: selectedFilter) { _ in
                    Task {
                        await viewModel.loadPosts(filter: selectedFilter)
                    }
                }
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(viewModel.posts) { post in
                            QuestionPostCardWithLink(post: post, viewModel: viewModel)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    // プルトゥリフレッシュ
                    await refreshQuestions()
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showPostQuestion = true
                        }) {
                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding()
                                .background(.purple)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding()
                        .sheet(isPresented: $showPostQuestion) {
                            PostQuestionView(viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("Ask Friends")
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear {
                viewModel.fetchPosts(filter: selectedFilter)
            }
        }
    }
    
    // リフレッシュ処理
    private func refreshQuestions() async {
        // 少し待機してからデータを再取得（UX向上のため）
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // メインスレッドでfetchを実行
        await MainActor.run {
            viewModel.fetchPosts(filter: selectedFilter)
        }
    }
}

struct QuestionPostCard: View {
    let post: QuestionPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(post.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Resolved badge
                    if post.isResolved {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                    }
                }
                
                Text(post.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                
                // タグ表示
                if !post.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(post.tags, id: \.self) { tag in
                                TagChip(tag: tag, isClickable: false)
                            }
                        }
                    }
                }
                
                HStack {
                    // 作成者名
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                        
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
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// NavigationLinkを含むカードビュー
struct QuestionPostCardWithLink: View {
    let post: QuestionPost
    let viewModel: QuestionPostViewModel
    
    var body: some View {
        NavigationLink(destination: QuestionDetailView(post: post, viewModel: viewModel)) {
            QuestionPostCard(post: post)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AskView()
}
