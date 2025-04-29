//
//  PostQuestionView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/29.
//

import SwiftUI

struct PostQuestionView: View {
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
                    print("Submit buttion tapped!")
                }) {
                    Text("Submit")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .navigationTitle(Text("Ask a Question"))
    }
}

#Preview {
    PostQuestionView()
}
