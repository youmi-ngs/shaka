//
//  UserAvatarView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct UserAvatarView: View {
    let uid: String
    let size: CGFloat
    @State private var photoURL: String?
    @State private var displayName: String = ""
    @State private var isLoading = true
    
    private let db = Firestore.firestore()
    
    var body: some View {
        Group {
            if let photoURL = photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_):
                        defaultAvatar
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    @unknown default:
                        defaultAvatar
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(width: size, height: size)
            } else {
                defaultAvatar
            }
        }
        .onAppear {
            fetchUserInfo()
        }
    }
    
    private var defaultAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: size, height: size)
            
            if !displayName.isEmpty {
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func fetchUserInfo() {
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching user info: \(error)")
                isLoading = false
                return
            }
            
            guard let data = snapshot?.data() else {
                isLoading = false
                return
            }
            
            // displayNameを取得
            if let publicData = data["public"] as? [String: Any],
               let name = publicData["displayName"] as? String {
                displayName = name
            }
            
            // photoURLを取得
            if let publicData = data["public"] as? [String: Any],
               let url = publicData["photoURL"] as? String {
                photoURL = url
            } else {
                // 古い形式のデータ構造をチェック
                if let url = data["photoURL"] as? String {
                    photoURL = url
                }
            }
            
            isLoading = false
        }
    }
}