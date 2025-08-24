//
//  ContentView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var notificationManager: NotificationManager
    @StateObject private var notificationViewModel = NotificationViewModel()
    @State private var showAddFriendConfirmation = false
    @State private var pendingFriendToAdd: (uid: String, displayName: String)?
    @State private var showProfileView = false
    @State private var profileToShow: String?
    @State private var hasRequestedNotifications = false
    
    var body: some View {
        TabView {
            NavigationView {
                DiscoverView()
            }
            .tabItem {
                Image(systemName: "globe")
                Text("Discover")
            }
            
            NavigationView {
                SeeWorksView()
            }
            .tabItem {
                Image(systemName: "eyeglasses")
                Text("Works")
            }
            
            NavigationView {
                AskView()
            }
            .tabItem {
                Image(systemName: "hand.wave")
                Text("Ask")
            }
            
            NavigationView {
                SearchView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            
            NavigationView {
                NotificationListView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label {
                    Text("Notifications")
                } icon: {
                    ZStack {
                        Image(systemName: "bell")
                        if notificationViewModel.unreadCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Text("\(min(notificationViewModel.unreadCount, 9))")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
            
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Profile")
            }
        }
        .onChange(of: deepLinkManager.showAddFriendAlert) { newValue in
            if newValue, let friend = deepLinkManager.friendToAdd {
                pendingFriendToAdd = friend
                showAddFriendConfirmation = true
                deepLinkManager.showAddFriendAlert = false
            }
        }
        .alert("Follow", isPresented: $showAddFriendConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingFriendToAdd = nil
            }
            Button("Follow") {
                if let friend = pendingFriendToAdd {
                    addFriend(uid: friend.uid)
                }
            }
        } message: {
            if let friend = pendingFriendToAdd {
                Text("Follow \(friend.displayName)?")
            }
        }
        .sheet(isPresented: $showProfileView) {
            if let uid = profileToShow {
                NavigationView {
                    PublicProfileView(authorUid: uid)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowProfile"))) { notification in
            if let uid = notification.userInfo?["uid"] as? String {
                profileToShow = uid
                showProfileView = true
            }
        }
        .onAppear {
            // 通知許可をリクエスト（初回のみ）
            if !hasRequestedNotifications && authManager.isAuthenticated {
                hasRequestedNotifications = true
                // 少し遅延させて確実に表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    notificationManager.requestNotificationPermission()
                }
            }
        }
    }
    
    private func addFriend(uid: String) {
        // 認証チェック
        guard Auth.auth().currentUser != nil else {
            // サインインが必要
            return
        }
        
        let followViewModel = FollowViewModel()
        followViewModel.followUser(targetUid: uid) { result in
            switch result {
            case .success:
                print("✅ User followed via deep link")
            case .failure(let error):
                print("❌ Failed to follow user: \(error)")
            }
        }
        
        pendingFriendToAdd = nil
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(DeepLinkManager.shared)
}
