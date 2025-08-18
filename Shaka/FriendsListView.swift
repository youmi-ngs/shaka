//
//  FriendsListView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI

struct FriendsListView: View {
    @StateObject private var viewModel = FollowViewModel()
    @State private var showRemoveAlert = false
    @State private var friendToRemove: Friend?
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.following.isEmpty {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.following.isEmpty {
                    emptyView
                } else {
                    friendsList
                }
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.fetchFollowing()
            }
            .alert("Unfollow", isPresented: $showRemoveAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Unfollow", role: .destructive) {
                    if let friend = friendToRemove {
                        removeFriend(friend)
                    }
                }
            } message: {
                Text("Unfollow this user?")
            }
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No users followed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap on post authors\nto follow them")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Friends List
    private var friendsList: some View {
        List {
            ForEach(viewModel.following) { friend in
                NavigationLink(destination: PublicProfileView(authorUid: friend.id)) {
                    friendRow(friend: friend)
                }
            }
            .onDelete(perform: deleteFriend)
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            viewModel.fetchFollowing()
        }
    }
    
    // MARK: - Friend Row
    private func friendRow(friend: Friend) -> some View {
        HStack(spacing: 12) {
            // プロフィール画像
            if let photoURL = friend.photoURL, let url = URL(string: photoURL) {
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
                Text(friend.displayName ?? "Unknown User")
                    .font(.headline)
                
                if let bio = friend.bio, !bio.isEmpty {
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
    
    // MARK: - Delete Friend
    private func deleteFriend(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let friend = viewModel.following[index]
        friendToRemove = friend
        showRemoveAlert = true
    }
    
    private func removeFriend(_ friend: Friend) {
        viewModel.unfollowUser(targetUid: friend.id) { result in
            switch result {
            case .success:
                // リストから削除（リスナーが自動的に更新）
                print("✅ Friend removed successfully")
            case .failure(let error):
                print("❌ Failed to remove friend: \(error)")
            }
        }
    }
}

// MARK: - Preview
struct FriendsListView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsListView()
    }
}