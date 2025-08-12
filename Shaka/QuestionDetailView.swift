//
//  QuestionDetailView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/05.
//

import SwiftUI

struct QuestionDetailView: View {
    let post: QuestionPost
    @ObservedObject var viewModel: QuestionPostViewModel
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(post.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Author and Date
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                        Text(post.displayName)
                            .foregroundColor(.primary)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                        Text(post.createdAt.formatted(date: .long, time: .shortened))
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Body
                Text(post.body)
                    .font(.body)
                    .padding(.horizontal)
                
                // Comments section (temporarily disabled)
                // CommentView(
                //     postID: post.id,
                //     postType: .question,
                //     postUserID: post.userID
                // )
                // .padding()
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
        .navigationTitle("Question Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // 自分の投稿の場合のみ編集・削除ボタンを表示
                if post.canEdit(currentUserID: authManager.userID) {
                    HStack {
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
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            PostQuestionView(viewModel: viewModel, editingPost: post)
        }
        .alert("Delete Question", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Are you sure you want to delete this question? This action cannot be undone.")
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
        QuestionDetailView(
            post: QuestionPost(
                id: "sample-id",
                title: "Sample Question",
                body: "This is a sample question body with detailed information about what the user wants to know.",
                createdAt: Date(),
                userID: "sample-user-id",
                displayName: "Sample User",
                location: nil,
                locationName: nil,
                isActive: true
            ),
            viewModel: QuestionPostViewModel()
        )
        .environmentObject(AuthManager.shared)
    }
}