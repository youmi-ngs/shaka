//
//  UserProfile.swift
//  Shaka
//
//  User profile data model with public/private/stats separation
//

import Foundation
import FirebaseFirestore

// MARK: - User Profile Model
struct UserProfile: Codable {
    let uid: String
    var `public`: PublicProfile
    var `private`: PrivateProfile?
    var stats: UserStats
    
    struct PublicProfile: Codable {
        var displayName: String
        var photoURL: String?
        var bio: String?
        var links: ProfileLinks?
    }
    
    struct ProfileLinks: Codable {
        var website: String?
        var instagram: String?
        var github: String?
    }
    
    struct PrivateProfile: Codable {
        let joinedAt: Timestamp
        var email: String?
    }
    
    struct UserStats: Codable {
        var worksCount: Int
        var questionsCount: Int
    }
    
    // Computed properties for convenience
    var displayName: String {
        `public`.displayName
    }
    
    var photoURL: URL? {
        guard let urlString = `public`.photoURL else { return nil }
        return URL(string: urlString)
    }
    
    // Validation methods
    static func validateDisplayName(_ name: String) -> ValidationResult {
        if name.isEmpty {
            return .failure("Display name cannot be empty")
        }
        if name.count > 50 {
            return .failure("Display name must be 50 characters or less")
        }
        return .success
    }
    
    static func validateBio(_ bio: String?) -> ValidationResult {
        guard let bio = bio else { return .success }
        if bio.count > 300 {
            return .failure("Bio must be 300 characters or less")
        }
        return .success
    }
    
    static func validateURL(_ urlString: String?) -> ValidationResult {
        guard let urlString = urlString, !urlString.isEmpty else { return .success }
        
        let urlPattern = "^https?://.*"
        let regex = try? NSRegularExpression(pattern: urlPattern)
        let range = NSRange(location: 0, length: urlString.utf16.count)
        
        if regex?.firstMatch(in: urlString, options: [], range: range) == nil {
            return .failure("Invalid URL format")
        }
        return .success
    }
    
    enum ValidationResult {
        case success
        case failure(String)
        
        var isValid: Bool {
            switch self {
            case .success: return true
            case .failure: return false
            }
        }
        
        var errorMessage: String? {
            switch self {
            case .success: return nil
            case .failure(let message): return message
            }
        }
    }
    
    // Create default profile for new users
    static func createDefault(uid: String, displayName: String? = nil) -> UserProfile {
        UserProfile(
            uid: uid,
            public: PublicProfile(
                displayName: displayName ?? "User_\(uid.prefix(6))",
                photoURL: nil,
                bio: nil,
                links: nil
            ),
            private: PrivateProfile(
                joinedAt: Timestamp(date: Date()),
                email: nil
            ),
            stats: UserStats(
                worksCount: 0,
                questionsCount: 0
            )
        )
    }
    
    // Convert to Firestore data
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [:]
        
        // Public data
        var publicData: [String: Any] = [
            "displayName": `public`.displayName
        ]
        if let photoURL = `public`.photoURL {
            publicData["photoURL"] = photoURL
        }
        if let bio = `public`.bio {
            publicData["bio"] = bio
        }
        if let links = `public`.links {
            var linksData: [String: String] = [:]
            if let website = links.website { linksData["website"] = website }
            if let instagram = links.instagram { linksData["instagram"] = instagram }
            if let github = links.github { linksData["github"] = github }
            if !linksData.isEmpty {
                publicData["links"] = linksData
            }
        }
        data["public"] = publicData
        
        // Private data (only if available)
        if let privateData = `private` {
            var privateDict: [String: Any] = [
                "joinedAt": privateData.joinedAt
            ]
            if let email = privateData.email {
                privateDict["email"] = email
            }
            data["private"] = privateDict
        }
        
        // Stats data
        data["stats"] = [
            "worksCount": stats.worksCount,
            "questionsCount": stats.questionsCount
        ]
        
        return data
    }
    
    // Create from Firestore document
    static func from(document: DocumentSnapshot) -> UserProfile? {
        guard let data = document.data() else { return nil }
        
        // Parse public data
        guard let publicData = data["public"] as? [String: Any],
              let displayName = publicData["displayName"] as? String else { return nil }
        
        let photoURL = publicData["photoURL"] as? String
        let bio = publicData["bio"] as? String
        
        var links: ProfileLinks?
        if let linksData = publicData["links"] as? [String: String] {
            links = ProfileLinks(
                website: linksData["website"],
                instagram: linksData["instagram"],
                github: linksData["github"]
            )
        }
        
        let publicProfile = PublicProfile(
            displayName: displayName,
            photoURL: photoURL,
            bio: bio,
            links: links
        )
        
        // Parse private data (might not be available for other users)
        var privateProfile: PrivateProfile?
        if let privateData = data["private"] as? [String: Any],
           let joinedAt = privateData["joinedAt"] as? Timestamp {
            privateProfile = PrivateProfile(
                joinedAt: joinedAt,
                email: privateData["email"] as? String
            )
        }
        
        // Parse stats data
        let statsData = data["stats"] as? [String: Any] ?? [:]
        let stats = UserStats(
            worksCount: statsData["worksCount"] as? Int ?? 0,
            questionsCount: statsData["questionsCount"] as? Int ?? 0
        )
        
        return UserProfile(
            uid: document.documentID,
            public: publicProfile,
            private: privateProfile,
            stats: stats
        )
    }
}