//
//  PublicProfileViewModel.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class PublicProfileViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var photoURL: String?
    @Published var bio: String?
    @Published var links: [String: String] = [:]
    @Published var worksCount: Int = 0
    @Published var questionsCount: Int = 0
    @Published var isFriend: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var workPosts: [WorkPost] = []
    
    private let db = Firestore.firestore()
    private let followViewModel = FollowViewModel()
    
    let authorUid: String
    var isCurrentUser: Bool {
        return Auth.auth().currentUser?.uid == authorUid
    }
    
    init(authorUid: String) {
        self.authorUid = authorUid
        print("🚀 PublicProfileViewModel init with UID: \(authorUid)")
    }
    
    // MARK: - プロフィール取得
    func fetchProfile() {
        isLoading = true
        errorMessage = nil
        
        print("🔍 Fetching profile for UID: \(authorUid)")
        
        db.collection("users").document(authorUid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Error fetching profile: \(error.localizedDescription)")
                    self.errorMessage = "プロフィールの取得に失敗しました: \(error.localizedDescription)"
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("❌ No data found for user: \(self.authorUid)")
                    self.errorMessage = "ユーザーが見つかりません"
                    return
                }
                
                print("📝 User data: \(data)")
                
                // public データ
                if let publicData = data["public"] as? [String: Any] {
                    self.displayName = publicData["displayName"] as? String ?? "Unknown User"
                    self.photoURL = publicData["photoURL"] as? String
                    self.bio = publicData["bio"] as? String
                    self.links = publicData["links"] as? [String: String] ?? [:]
                    print("✅ Public data loaded: displayName=\(self.displayName)")
                } else {
                    print("⚠️ No public data found")
                    self.displayName = "Unknown User"
                }
                
                // stats データ
                if let statsData = data["stats"] as? [String: Any] {
                    self.worksCount = statsData["worksCount"] as? Int ?? 0
                    self.questionsCount = statsData["questionsCount"] as? Int ?? 0
                    print("✅ Stats loaded: works=\(self.worksCount), questions=\(self.questionsCount)")
                } else {
                    print("⚠️ No stats data found")
                }
                
                // フレンド状態をチェック
                self.checkFriendStatus()
                // 投稿を取得
                self.fetchUserPosts()
            }
        }
    }
    
    // MARK: - フレンド状態チェック
    private func checkFriendStatus() {
        guard !isCurrentUser else {
            isFriend = false
            return
        }
        
        followViewModel.isFollowing(targetUid: authorUid) { [weak self] isFollowing in
            DispatchQueue.main.async {
                self?.isFriend = isFollowing
            }
        }
    }
    
    // MARK: - フォロー
    func addFriend(completion: @escaping (Result<Void, Error>) -> Void) {
        // 未ログインチェック
        guard Auth.auth().currentUser != nil else {
            completion(.failure(NSError(domain: "PublicProfileViewModel", code: 401, 
                                       userInfo: [NSLocalizedDescriptionKey: "Please sign in to follow"])))
            return
        }
        
        followViewModel.followUser(targetUid: authorUid) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.isFriend = true
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - アンフォロー
    func removeFriend(completion: @escaping (Result<Void, Error>) -> Void) {
        followViewModel.unfollowUser(targetUid: authorUid) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.isFriend = false
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 投稿取得
    func fetchUserPosts() {
        print("🔍 Fetching posts for user: \(authorUid)")
        // 一時的にシンプルなクエリでテスト
        db.collection("works")
            .whereField("userID", isEqualTo: authorUid)
            // .order(by: "createdAt", descending: true)
            .limit(to: 12)  // 最初は12個まで表示
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching user posts: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { 
                    print("⚠️ No documents found")
                    return 
                }
                
                print("📚 Found \(documents.count) posts for user")
                
                DispatchQueue.main.async {
                    self.workPosts = documents.compactMap { doc in
                        let data = doc.data()
                        let id = doc.documentID
                        let title = data["title"] as? String ?? ""
                        let description = data["description"] as? String
                        let detail = data["detail"] as? String
                        let imageURLString = data["imageURL"] as? String
                        let imageURL = imageURLString != nil ? URL(string: imageURLString!) : nil
                        
                        print("📷 Post: \(title), Image URL: \(imageURLString ?? "no image")")
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        let userID = data["userID"] as? String ?? ""
                        let displayName = data["displayName"] as? String ?? ""
                        let isActive = data["isActive"] as? Bool ?? true
                        let tags = data["tags"] as? [String] ?? []
                        let location = data["location"] as? GeoPoint
                        let locationName = data["locationName"] as? String
                        
                        return WorkPost(
                            id: id,
                            title: title,
                            description: description,
                            detail: detail,
                            imageURL: imageURL,
                            createdAt: createdAt,
                            userID: userID,
                            displayName: displayName,
                            location: location,
                            locationName: locationName,
                            isActive: isActive,
                            tags: tags
                        )
                    }
                    print("✅ Total posts loaded: \(self.workPosts.count)")
                }
            }
    }
}