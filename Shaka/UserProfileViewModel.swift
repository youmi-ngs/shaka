//
//  UserProfileViewModel.swift
//  Shaka
//
//  ViewModel for managing user profile data
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import PhotosUI

class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isUploading = false
    @Published var profileSaved = false
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Profile Management
    
    /// Load profile for a specific user
    func loadProfile(uid: String) {
        isLoading = true
        errorMessage = nil
        
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    return
                }
                
                if let snapshot = snapshot, snapshot.exists {
                    self?.profile = UserProfile.from(document: snapshot)
                } else {
                    // Create default profile if not exists
                    let displayName = Auth.auth().currentUser?.displayName
                    self?.profile = UserProfile.createDefault(uid: uid, displayName: displayName)
                }
            }
        }
    }
    
    /// Save profile updates
    func saveProfile() {
        guard let profile = profile else { return }
        
        // Validate all fields
        let validations = [
            UserProfile.validateDisplayName(profile.public.displayName),
            UserProfile.validateBio(profile.public.bio),
            UserProfile.validateURL(profile.public.links?.website),
            UserProfile.validateURL(profile.public.links?.instagram),
            UserProfile.validateURL(profile.public.links?.github)
        ]
        
        for validation in validations {
            if case .failure(let message) = validation {
                errorMessage = message
                return
            }
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // Only update public fields (as per security rules)
        var updateData: [String: Any] = [:]
        
        // Build public data
        var publicData: [String: Any] = [
            "displayName": profile.public.displayName
        ]
        
        if let photoURL = profile.public.photoURL {
            publicData["photoURL"] = photoURL
        } else {
            publicData["photoURL"] = FieldValue.delete()
        }
        
        if let bio = profile.public.bio, !bio.isEmpty {
            publicData["bio"] = bio
        } else {
            publicData["bio"] = FieldValue.delete()
        }
        
        // Handle links
        if let links = profile.public.links {
            var linksData: [String: Any] = [:]
            
            if let website = links.website, !website.isEmpty {
                linksData["website"] = website
            }
            if let instagram = links.instagram, !instagram.isEmpty {
                linksData["instagram"] = instagram
            }
            if let github = links.github, !github.isEmpty {
                linksData["github"] = github
            }
            
            if !linksData.isEmpty {
                publicData["links"] = linksData
            } else {
                publicData["links"] = FieldValue.delete()
            }
        } else {
            publicData["links"] = FieldValue.delete()
        }
        
        updateData["public"] = publicData
        
        // Include private and stats if creating new document
        if profile.private == nil {
            updateData["private"] = [
                "joinedAt": FieldValue.serverTimestamp(), // サーバー時刻を使用
                "email": Auth.auth().currentUser?.email as Any? ?? NSNull()
            ]
            updateData["stats"] = [
                "worksCount": 0,
                "questionsCount": 0
            ]
        }
        
        db.collection("users").document(profile.uid).setData(updateData, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to save profile: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Profile saved successfully"
                    self?.profileSaved = true  // 保存成功を通知
                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.successMessage = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Avatar Upload
    
    /// Upload avatar image
    func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ProfileError.notAuthenticated
        }
        
        // Resize and compress image
        let processedImage = resizeImage(image, maxDimension: 1280)
        guard let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
            throw ProfileError.imageProcessingFailed
        }
        
        // Check size (5MB limit)
        if imageData.count > 5 * 1024 * 1024 {
            throw ProfileError.imageTooLarge
        }
        
        // Upload to Storage
        let storageRef = storage.reference().child("avatars/\(uid)/avatar.jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    /// Process selected photo item
    func processPhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        await MainActor.run {
            isUploading = true
            errorMessage = nil
        }
        
        do {
            // Load image data
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw ProfileError.imageLoadFailed
            }
            
            // Upload avatar
            let photoURL = try await uploadAvatar(image)
            
            // Update profile
            await MainActor.run {
                profile?.public.photoURL = photoURL
                saveProfile()
                isUploading = false
            }
            
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = "Failed to upload avatar: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(
                width: maxDimension,
                height: maxDimension * size.height / size.width
            )
        } else {
            newSize = CGSize(
                width: maxDimension * size.width / size.height,
                height: maxDimension
            )
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    // MARK: - Error Types
    
    enum ProfileError: LocalizedError {
        case notAuthenticated
        case imageProcessingFailed
        case imageTooLarge
        case imageLoadFailed
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "User not authenticated"
            case .imageProcessingFailed:
                return "Failed to process image"
            case .imageTooLarge:
                return "Image size exceeds 5MB limit"
            case .imageLoadFailed:
                return "Failed to load image"
            }
        }
    }
}