//
//  FollowTabView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI

struct FollowTabView: View {
    @State private var selectedTab: Int
    @StateObject private var followViewModel = FollowViewModel()
    @Environment(\.dismiss) private var dismiss
    
    init(initialTab: Int = 0) {
        self._selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Following Tab
                FollowingListView()
                    .tag(0)
                    .tabItem {
                        Label("Following", systemImage: "person.2.fill")
                    }
                
                // Followers Tab
                FollowersListView()
                    .tag(1)
                    .tabItem {
                        Label("Followers", systemImage: "person.3.fill")
                    }
            }
            .navigationTitle(selectedTab == 0 ? "Following" : "Followers")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

// Following List View
struct FollowingListView: View {
    @StateObject private var viewModel = FollowViewModel()
    @State private var showRemoveAlert = false
    @State private var friendToRemove: Friend?
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.following.isEmpty {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.following.isEmpty {
                emptyFollowingView
            } else {
                followingList
            }
        }
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
    
    // MARK: - Empty View
    private var emptyFollowingView: some View {
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
    
    // MARK: - Following List
    private var followingList: some View {
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
                viewModel.fetchFollowing()
            case .failure(let error):
                print("❌ Failed to remove friend: \(error)")
            }
        }
    }
}

// Followers List View (using existing FollowersListView)
struct FollowersListContent: View {
    @StateObject private var viewModel = FollowViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.followers.isEmpty {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.followers.isEmpty {
                emptyFollowersView
            } else {
                followersList
            }
        }
        .onAppear {
            viewModel.fetchFollowers()
        }
    }
    
    // MARK: - Empty View
    private var emptyFollowersView: some View {
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
struct FollowTabView_Previews: PreviewProvider {
    static var previews: some View {
        FollowTabView()
    }
}