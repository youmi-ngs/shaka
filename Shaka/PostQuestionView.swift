//
//  PostQuestionView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/29.
//

import SwiftUI

struct PostQuestionView: View {
    
    @ObservedObject var viewModel: QuestionPostViewModel
    @Environment(\.dismiss)	var dismiss
    
    @State private var title: String = ""
    @State private var bodyText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Enter your question title", text: $title)
                }
                
                Section(header: Text("Question Details")) {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 208)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                }
                Button(action: {
                    viewModel.addPost(title: title, body: bodyText)
                    dismiss()
                    print("Submit buttion tapped!")
                }) {
                    Text("Submit")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty || bodyText.isEmpty ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(title.isEmpty || bodyText.isEmpty)
                }
            }
        }
        .navigationTitle(Text("Ask a Question"))
    }
}

#Preview {
    PostQuestionView(viewModel: QuestionPostViewModel())
}
