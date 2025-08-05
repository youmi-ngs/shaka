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
    
    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        NavigationView {
            ReusablePostFormView(
                title: $title,
                bodyText: $bodyText,
                isSubmitting: $isSubmitting,
                titlePlaceholder: "Enter your question title",
                bodyPlaceholder: "What would you like to ask?",
                bodyLabel: "Question Details",
                submitButtonText: "Submit Question",
                submitButtonColor: .purple,
                errorMessage: nil,
                canSubmit: !title.isEmpty,
                onSubmit: submitQuestion,
                onCancel: { dismiss() }
            )
            .navigationTitle("Ask a Question")
        }
    }
    
    private func submitQuestion() {
        isSubmitting = true
        
        // Add the question
        viewModel.addPost(title: title, body: bodyText)
        
        // Close the view
        dismiss()
        
        print("Question submitted!")
    }
}

#Preview {
    PostQuestionView(viewModel: QuestionPostViewModel())
}
