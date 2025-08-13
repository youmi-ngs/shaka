//
//  CommentView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/13.
//

import SwiftUI

struct CommentView: View {
    let postID: String
    let postType: Comment.PostType
    let postUserID: String
    @StateObject private var viewModel = CommentViewModel()
    @State private var newCommentText = ""
    @State private var showDeleteAlert = false
    @State private var commentToDelete: Comment?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Comments", systemImage: "bubble.left.fill")
                    .font(.headline)
                    .foregroundColor(postType == .question ? .purple : .orange)
                
                Spacer()
            }
            
            // Comment input
            HStack {
                TextField("Add a comment...", text: $newCommentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: submitComment) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(newCommentText.isEmpty ? .gray : (postType == .question ? .purple : .orange))
                }
                .disabled(newCommentText.isEmpty)
            }
            
            // Comments list
            if viewModel.comments.isEmpty {
                Text("No comments yet")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.comments) { comment in
                    CommentRow(
                        comment: comment,
                        isOwnComment: comment.userID == AuthManager.shared.getCurrentUserID(),
                        onDelete: {
                            commentToDelete = comment
                            showDeleteAlert = true
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            viewModel.fetchComments(for: postID, postType: postType)
        }
        .alert("Delete Comment", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let comment = commentToDelete {
                    viewModel.deleteComment(comment)
                }
            }
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }
    
    private func submitComment() {
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        viewModel.addComment(
            to: postID,
            postType: postType,
            postUserID: postUserID,
            text: trimmedText
        )
        newCommentText = ""
    }
}

struct CommentRow: View {
    let comment: Comment
    let isOwnComment: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isOwnComment ? .blue : .primary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(timeAgoString(from: comment.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isOwnComment {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Text(comment.text)
                .font(.subheadline)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isOwnComment ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            if days == 1 {
                return "yesterday"
            } else if days < 30 {
                return "\(days)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
        }
    }
}

#Preview {
    CommentView(
        postID: "sample-id",
        postType: .work,
        postUserID: "user123"
    )
}