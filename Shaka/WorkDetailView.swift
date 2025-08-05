//
//  WorkDetailView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/05.
//

import SwiftUI

struct WorkDetailView: View {
    let post: WorkPost
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image
                if let url = post.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        case .failure(_):
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 300)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                        Text("Failed to load image")
                                            .foregroundColor(.gray)
                                    }
                                )
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 300)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(1.5)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // No image placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Text("No image")
                                .foregroundColor(.gray)
                        )
                }
                
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
                
                // Description (if exists)
                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .padding(.horizontal)
                }
                
                // Detail (if exists)
                if let detail = post.detail, !detail.isEmpty {
                    Divider()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    Text("Details")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    
                    Text(detail)
                        .font(.body)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
        .navigationTitle("Work Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        WorkDetailView(
            post: WorkPost(
                title: "Sample Work",
                description: "This is a sample description for the work post. It can be quite long and contain multiple lines of text to show how the layout handles longer content.",
                detail: "Date: Jan 5, 2025\nLocation: Tokyo, Japan\nSettings: f/2.8, 1/200s, ISO 400, 50mm",
                imageURL: URL(string: "https://picsum.photos/400/300"),
                createdAt: Date()
            )
        )
    }
}