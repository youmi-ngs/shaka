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
                
                // Date
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text(post.createdAt.formatted(date: .long, time: .shortened))
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Body
                Text(post.body)
                    .font(.body)
                    .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
        .navigationTitle("Question Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
                createdAt: Date()
            ),
            viewModel: QuestionPostViewModel()
        )
    }
}