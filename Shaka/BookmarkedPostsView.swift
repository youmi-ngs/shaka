//
//  BookmarkedPostsView.swift
//  Shaka
//
//  Created by Assistant on 2025/01/17.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct BookmarkedPostsView: View {
    @StateObject private var viewModel = BookmarkedPostsViewModel()
    @StateObject private var workPostViewModel = WorkPostViewModel()
    @StateObject private var questionPostViewModel = QuestionPostViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            // Tab selector
            Picker("Type", selection: $selectedTab) {
                Text("Works").tag(0)
                Text("Questions").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            ScrollView {
                if selectedTab == 0 {
                    // Bookmarked Works
                    if viewModel.isLoadingWorks {
                        ProgressView()
                            .padding()
                    } else if viewModel.bookmarkedWorks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No bookmarked works")
                                .foregroundColor(.gray)
                            Text("Bookmark works to see them here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.bookmarkedWorks) { post in
                                NavigationLink(destination: WorkDetailView(post: post, viewModel: workPostViewModel)) {
                                    BookmarkedWorkCard(post: post)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                } else {
                    // Bookmarked Questions
                    if viewModel.isLoadingQuestions {
                        ProgressView()
                            .padding()
                    } else if viewModel.bookmarkedQuestions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No bookmarked questions")
                                .foregroundColor(.gray)
                            Text("Bookmark questions to see them here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.bookmarkedQuestions) { post in
                                NavigationLink(destination: QuestionDetailView(post: post, viewModel: questionPostViewModel)) {
                                    BookmarkedQuestionCard(post: post)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchBookmarkedPosts()
        }
    }
}

struct BookmarkedWorkCard: View {
    let post: WorkPost
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageURL = post.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                    case .failure(_), .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(post.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !post.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(post.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Text(post.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct BookmarkedQuestionCard: View {
    let post: QuestionPost
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.purple)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(post.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !post.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(post.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Text(post.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        BookmarkedPostsView()
    }
}