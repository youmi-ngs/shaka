//
//  PostQuestionView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/29.
//

import SwiftUI

struct PostQuestionView: View {
    @ObservedObject var viewModel: QuestionPostViewModel
    @Environment(\.dismiss) var dismiss
    
    let editingPost: QuestionPost?
    
    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var isSubmitting: Bool = false
    
    init(viewModel: QuestionPostViewModel, editingPost: QuestionPost? = nil) {
        self.viewModel = viewModel
        self.editingPost = editingPost
    }
    
    var body: some View {
        NavigationView {
            ReusablePostFormView(
                title: $title,
                bodyText: $bodyText,
                isSubmitting: $isSubmitting,
                titlePlaceholder: "Enter your question title",
                bodyPlaceholder: "What would you like to ask?",
                bodyLabel: "Question Details",
                submitButtonText: editingPost != nil ? "Save Changes" : "Submit Question",
                submitButtonColor: .purple,
                errorMessage: nil,
                canSubmit: !title.isEmpty,
                onSubmit: submitQuestion,
                onCancel: { dismiss() }
            )
            .navigationTitle(editingPost != nil ? "Edit Question" : "Ask a Question")
            .onAppear {
                if let post = editingPost {
                    title = post.title
                    bodyText = post.body
                }
            }
        }
    }
    
    private func submitQuestion() {
        isSubmitting = true
        
        if let existingPost = editingPost {
            // Update existing question
            viewModel.updatePost(existingPost, title: title, body: bodyText)
        } else {
            // Add new question
            viewModel.addPost(title: title, body: bodyText)
        }
        
        // Close the view
        dismiss()
        
        print("Question submitted!")
    }
}

#Preview {
    PostQuestionView(viewModel: QuestionPostViewModel())
}
