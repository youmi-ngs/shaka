//
//  PostWorkView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/29.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct PostWorkView: View {
    @ObservedObject var viewModel: WorkPostViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        NavigationView {
            ReusablePostFormView(
                title: $title,
                bodyText: $description,
                isSubmitting: $isUploading,
                titlePlaceholder: "Enter the work title",
                bodyPlaceholder: "Enter the work description",
                bodyLabel: "Description",
                submitButtonText: "Submit Work",
                submitButtonColor: .orange,
                errorMessage: uploadError,
                canSubmit: canSubmit,
                onSubmit: submitWork,
                onCancel: { dismiss() }
            ) {
                // Image picker section
                Section(header: Text("Photo (Required)")) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .cornerRadius(8)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 200)
                                
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Select a photo")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let newItem = newItem {
                                if let data = try? await newItem.loadTransferable(type: Data.self) {
                                    selectedImage = UIImage(data: data)
                                }
                            }
                        }
                    }
                }
                
                // Warning message when no image selected
                if selectedImage == nil {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Please select a photo to continue")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Post a Work")
        }
    }
    
    private var canSubmit: Bool {
        !title.isEmpty && !description.isEmpty && selectedImage != nil
    }
    
    private func submitWork() {
        guard let image = selectedImage else { return }
        
        print("📸 Starting image upload to Firebase Storage...")
        
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                // Convert image to JPEG data
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw UploadError.imageConversionFailed
                }
                
                print("📸 Image data size: \(imageData.count / 1024)KB")
                
                // Create unique filename
                let filename = "\(UUID().uuidString).jpg"
                let storageRef = Storage.storage().reference().child("works/\(filename)")
                
                print("📸 Uploading to: works/\(filename)")
                
                // Upload image
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                print("✅ Upload successful!")
                
                // Get download URL
                let downloadURL = try await storageRef.downloadURL()
                let urlString = downloadURL.absoluteString
                
                print("✅ Got download URL: \(urlString)")
                
                // Add post with image URL
                await MainActor.run {
                    let url = URL(string: urlString)
                    viewModel.addPost(title: title, description: description, imageURL: url)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    print("❌ Upload error: \(error)")
                    uploadError = "Failed to upload image: \(error.localizedDescription)"
                    isUploading = false
                }
            }
        }
    }
}

enum UploadError: LocalizedError {
    case imageConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image"
        }
    }
}

#Preview {
    PostWorkView(viewModel: WorkPostViewModel())
}