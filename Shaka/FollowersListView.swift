//
//  FollowersListView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI

struct FollowersListView: View {
    @StateObject private var viewModel = FollowViewModel()
    @State private var showRemoveAlert = false
    @State private var followerToRemove: Friend?
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.followers.isEmpty {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.followers.isEmpty {
                emptyView
            } else {
                followersList
            }
        }
        .onAppear {
            viewModel.fetchFollowers()
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No followers yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Share your profile\nto get followers")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Followers List
    private var followersList: some View {
        List {
            ForEach(viewModel.followers) { follower in
                NavigationLink(destination: PublicProfileView(authorUid: follower.id)) {
                    followerRow(follower: follower)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            viewModel.fetchFollowers()
        }
    }
    
    // MARK: - Follower Row
    private func followerRow(follower: Friend) -> some View {
        HStack(spacing: 12) {
            // プロフィール画像
            if let photoURL = follower.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 4) {
                Text(follower.displayName ?? "Unknown User")
                    .font(.headline)
                
                if let bio = follower.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct FollowersListView_Previews: PreviewProvider {
    static var previews: some View {
        FollowersListView()
    }
}