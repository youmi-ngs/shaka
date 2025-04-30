//
//  AskView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI

struct AskView: View {
    @StateObject private var ViewModel = QuestionPostViewModel()
    @State private var showPostQuestion = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List(ViewModel.posts) { post in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.title)
                            .font(.headline)
                        Text(post.body)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showPostQuestion = true
                        }) {
                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding()
                                .background(Color.purple)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding()
                        .sheet(isPresented: $showPostQuestion) {
                            PostQuestionView(viewModel: ViewModel)
                        }
                    }
                }
            }
            .navigationTitle("Ask Friends")
        }
    }
}

#Preview {
    AskView()
}
