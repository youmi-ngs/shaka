//
//  PublicProfileView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI
import FirebaseAuth

struct PublicProfileView: View {
    let authorUid: String
    @StateObject private var viewModel: PublicProfileViewModel
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isAddingFriend = false
    @State private var showUnfollowAlert = false
    @State private var showAnonymousWarning = false
    @Environment(\.dismiss) private var dismiss
    
    init(authorUid: String) {
        self.authorUid = authorUid
        self._viewModel = StateObject(wrappedValue: PublicProfileViewModel(authorUid: authorUid))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // プロフィールヘッダー
                profileHeader
                
                // Bio
                if let bio = viewModel.bio, !bio.isEmpty {
                    bioSection(bio: bio)
                }
                
                // Links
                if !viewModel.links.isEmpty {
                    linksSection
                }
                
                // フレンド追加ボタン（自分以外の場合のみ）
                if !viewModel.isCurrentUser {
                    friendActionButton
                    shareProfileButton
                } else {
                    // 自分のプロフィールの場合は共有ボタンを表示
                    shareMyProfileButton
                }
                
                // 投稿グリッド
                postsGrid
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchProfile()
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Unfollow", isPresented: $showUnfollowAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Unfollow", role: .destructive) {
                handleUnfollow()
            }
        } message: {
            Text("Are you sure you want to unfollow \(viewModel.displayName)?")
        }
        .alert("Guest Account Warning", isPresented: $showAnonymousWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Continue Anyway") {
                performFollow()
            }
            Button("Protect My Account") {
                // ProfileViewに遷移してApple ID連携を促す
                dismiss()
            }
        } message: {
            Text("You're using a guest account. Your data might be lost if the app is deleted. Link Apple ID to save your account.")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // プロフィール画像
            if let photoURL = viewModel.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 40))
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 40))
                    )
            }
            
            // 名前
            Text(viewModel.displayName)
                .font(.title2)
                .fontWeight(.bold)
            
            // 自分のプロフィールの場合
            if viewModel.isCurrentUser {
                Text("(You)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Bio Section
    private func bioSection(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio")
                .font(.headline)
            Text(bio)
                .font(.body)
                .foregroundColor(.primary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Links Section
    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links")
                .font(.headline)
            
            ForEach(viewModel.links.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                if let url = URL(string: value) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: linkIcon(for: key))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(key.capitalized)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Friend Action Button
    private var friendActionButton: some View {
        Button(action: handleFriendAction) {
            HStack {
                Image(systemName: viewModel.isFriend ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(viewModel.isFriend ? "Following" : "Follow")
            }
            .font(.headline)
            .foregroundColor(viewModel.isFriend ? .primary : .white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isFriend ? Color(UIColor.secondarySystemFill) : Color.blue)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.isFriend ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .disabled(isAddingFriend)
    }
    
    // MARK: - Share Profile Button
    private var shareProfileButton: some View {
        Button(action: {
            shareProfile()
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Profile")
            }
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Posts Grid
    private var postsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Posts")
                    .font(.headline)
                Spacer()
                if viewModel.workPosts.count > 12 {
                    NavigationLink(destination: UserPostsView(userId: authorUid, displayName: viewModel.displayName)) {
                        Text("See All")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if viewModel.workPosts.isEmpty {
                Text("No posts yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                    ForEach(viewModel.workPosts.prefix(12)) { post in
                        NavigationLink(destination: WorkDetailView(post: post, viewModel: WorkPostViewModel())) {
                            if let imageURL = post.imageURL {
                                CachedImage(url: imageURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: (UIScreen.main.bounds.width - 36) / 3, height: (UIScreen.main.bounds.width - 36) / 3)
                                        .clipped()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color(UIColor.quaternarySystemFill))
                                        .frame(width: (UIScreen.main.bounds.width - 36) / 3, height: (UIScreen.main.bounds.width - 36) / 3)
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(0.5)
                                        )
                                }
                            } else {
                                Rectangle()
                                    .fill(Color(UIColor.tertiarySystemFill))
                                    .frame(width: (UIScreen.main.bounds.width - 36) / 3, height: (UIScreen.main.bounds.width - 36) / 3)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .cornerRadius(3)
            }
        }
    }
    
    // MARK: - Share My Profile Button
    private var shareMyProfileButton: some View {
        Button(action: {
            shareProfile()
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Follow Link")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    private func linkIcon(for key: String) -> String {
        switch key.lowercased() {
        case "website", "web":
            return "globe"
        case "instagram":
            return "camera.fill"
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        case "twitter", "x":
            return "bird.fill"
        default:
            return "link"
        }
    }
    
    private func handleFriendAction() {
        let currentUser = Auth.auth().currentUser
        
        // フォロー中の場合はアンフォロー確認
        if viewModel.isFriend {
            showUnfollowAlert = true
        } else {
            // 匿名ユーザーの場合は警告を表示
            if currentUser?.isAnonymous == true && !viewModel.isFriend {
                showAnonymousWarning = true
            } else {
                performFollow()
            }
        }
    }
    
    private func performFollow() {
        isAddingFriend = true
        viewModel.addFriend { result in
            isAddingFriend = false
            switch result {
            case .success:
                // 成功時は特に何もしない（UIは自動更新される）
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    private func handleUnfollow() {
        isAddingFriend = true
        viewModel.removeFriend { result in
            isAddingFriend = false
            switch result {
            case .success:
                // 成功時は特に何もしない（UIは自動更新される）
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    // MARK: - Share Helpers
    private func generateShareMessage() -> String {
        if viewModel.isCurrentUser {
            return "Follow me on Shaka!\n\(viewModel.displayName)"
        } else {
            return "\(viewModel.displayName)'s Profile"
        }
    }
    
    private func generateShareURL() -> URL {
        let urlString = DeepLinkManager.shared.generateShareableURL(for: authorUid)
        return URL(string: urlString) ?? URL(string: "https://shaka.app")!
    }
    
    private func shareProfile() {
        let items: [Any] = [generateShareMessage(), generateShareURL()]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // iPad対応
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // completionハンドラーを追加してナビゲーションの問題を防ぐ
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            // Share完了後は何もしない（ナビゲーションをそのままにする）
        }
        
        // 現在のViewController取得して表示
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(activityVC, animated: true)
        }
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
struct PublicProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PublicProfileView(authorUid: "test-uid")
        }
    }
}
