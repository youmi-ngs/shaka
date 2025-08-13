//
//  PublicProfileView.swift
//  Shaka
//
//  Created by Assistant on 2025/01/13.
//

import SwiftUI
import FirebaseAuth

struct PublicProfileView: View {
    let authorUid: String
    @StateObject private var viewModel: PublicProfileViewModel
    @State private var showSignInAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isAddingFriend = false
    @State private var showShareSheet = false
    @State private var showUnfollowAlert = false
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
                
                // Stats
                statsSection
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
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("👁 PublicProfileView appeared for UID: \(authorUid)")
            print("  Current displayName: \(viewModel.displayName)")
            print("  Is loading: \(viewModel.isLoading)")
            viewModel.fetchProfile()
        }
        .alert("Sign In Required", isPresented: $showSignInAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign In") {
                // AuthManagerのサインイン画面を表示 
                // 実際にはサインイン画面を表示する処理が必要
                // ここでは仮に匿名サインインを実行
                Task {
                    do {
                        try await AuthManager.shared.signInAnonymously()
                    } catch {
                        print("Sign in failed: \(error)")
                    }
                }
            }
        } message: {
            Text("Please sign in to follow")
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
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 40) {
            VStack {
                Text("\(viewModel.worksCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Works")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("\(viewModel.questionsCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Questions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
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
            showShareSheet = true
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [generateShareMessage(), generateShareURL()])
        }
    }
    
    // MARK: - Share My Profile Button
    private var shareMyProfileButton: some View {
        Button(action: {
            showShareSheet = true
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [generateShareMessage(), generateShareURL()])
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
        // 未ログインチェック
        guard Auth.auth().currentUser != nil else {
            showSignInAlert = true
            return
        }
        
        // フォロー中の場合はアンフォロー確認
        if viewModel.isFriend {
            showUnfollowAlert = true
        } else {
            // フォローする
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
