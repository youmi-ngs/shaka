//
//  SeeWorksView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI

struct SeeWorksView: View {
    @StateObject private var viewModel = WorkPostViewModel()
    @State private var showPostWork = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List(viewModel.posts) { post in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.title)
                            .font(.headline)
                        Text(post.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let url = post.imageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .clipped()
                                        .cornerRadius(8)
                                case .failure(_):
                                    Color.gray
                                        .frame(height: 200)
                                        .overlay(Text("Failed to load image").foregroundColor(.white))
                                case .empty:
                                    ProgressView()
                                        .frame(height: 200)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }

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
                            showPostWork = true
                        }) {
                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding()
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding()
                        .sheet(isPresented: $showPostWork) {
                            PostWorkView(viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("See Works")
        }
    }
}

#Preview {
    SeeWorksView()
}
