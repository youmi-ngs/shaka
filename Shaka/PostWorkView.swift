//
//  PostWorkView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/29.
//

import SwiftUI

struct PostWorkView: View {
    @ObservedObject var viewModel: WorkPostViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var imageURL: URL?

    var body: some View {
        NavigationView {

            if let url = imageURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(8)
                        .padding(.horizontal)
                } placeholder: {
                    ProgressView()
                        .frame(height: 200)
                }
            }
            
            Form {
                
                Section(header: Text("Title")) {
                    TextField("Enter the work title", text: $title)
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                }
                

                Button(action: {
                    viewModel.addPost(title: title, description: description, imageURL: imageURL)
                    dismiss()
                    print("Submit Work button tapped!")
                }) {
                    Text("Submit Work")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty || description.isEmpty ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(title.isEmpty || description.isEmpty)
                }
            }
            .navigationTitle("Post a Work")
        }
    }
}

#Preview {
    PostWorkView(viewModel: WorkPostViewModel())
}
