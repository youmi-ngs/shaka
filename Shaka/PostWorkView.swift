//
//  PostWorkView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/29.
//

import SwiftUI

struct PostWorkView: View {
    @State private var title = ""
    @State private var description = ""

    var body: some View {
        NavigationView {
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
                    print("Submit Work button tapped!")
                }) {
                    Text("Submit Work")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .navigationTitle("Post a Work")
        }
    }
}

#Preview {
    PostWorkView()
}
