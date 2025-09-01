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
    @State private var showAddFriendConfirmation = false
    @State private var pendingFriendToAdd: (uid: String, displayName: String)?
    @State private var showProfileView = false
    @State private var profileToShow: String?
    @State private var hasRequestedNotifications = false
    @State private var selectedTab = 0
    
    var tabAccentColor: Color {
        switch selectedTab {
        case 0: return .mint //DiscoverView
        case 1: return .indigo  // SeeWorksView
        case 2: return .purple  // AskView
        case 3: return .cyan //SearchView
        default: return .teal //ProfileView
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                DiscoverView()
            }
            .tabItem {
                Label("Discover", systemImage: "globe")
            }
            .tag(0)
            
            NavigationView {
                SeeWorksView()
            }
            .tabItem {
                Label("Works", systemImage: "eyeglasses")
            }
            .tag(1)
            
            NavigationView {
                AskView()
            }
            .tabItem {
                Label("Ask", systemImage: "questionmark.bubble")
            }
            .tag(2)
            
            NavigationView {
                SearchView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(3)
            
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(4)
        }
        .accentColor(tabAccentColor)
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
                break
            case .failure(let error):
                break
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
