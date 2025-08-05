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
    @State private var photoDate: Date?
    @State private var isPhotoDateEnabled = false
    @State private var location = ""
    @State private var cameraSettings = ""
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
                onCancel: { dismiss() },
                imageSection: {
                // Image picker section
                Section(header: HStack {
                    Text("Photo")
                    Text("(Required)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }) {
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
            },
            additionalContent: {
                // Photo details section (optional)
                Section(header: HStack {
                    Text("Photo Details")
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }) {
                    Toggle("Shooting Date", isOn: $isPhotoDateEnabled)
                    
                    if isPhotoDateEnabled {
                        DatePicker("", selection: Binding(
                            get: { photoDate ?? Date() },
                            set: { photoDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.compact)
                    }
                    
                    HStack {
                        Text("Location")
                        TextField("e.g., Tokyo, Japan", text: $location)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Camera Settings")
                            .font(.subheadline)
                            .padding(.top, 8)
                        TextEditor(text: $cameraSettings)
                            .frame(minHeight: 60)
                            .overlay(
                                Group {
                                    if cameraSettings.isEmpty {
                                        Text("e.g., f/2.8, 1/200s, ISO 400, 50mm")
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                }
            }
            )
            .navigationTitle("Post a Work")
        }
    }
    
    private var canSubmit: Bool {
        !title.isEmpty && selectedImage != nil
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
                    
                    // Combine photo details into a single string if any are provided
                    var detailComponents: [String] = []
                    
                    if isPhotoDateEnabled, let date = photoDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        detailComponents.append("Date: \(formatter.string(from: date))")
                    }
                    
                    if !location.isEmpty {
                        detailComponents.append("Location: \(location)")
                    }
                    
                    if !cameraSettings.isEmpty {
                        detailComponents.append("Settings: \(cameraSettings)")
                    }
                    
                    let detail = detailComponents.isEmpty ? nil : detailComponents.joined(separator: "\n")
                    
                    viewModel.addPost(title: title, description: description.isEmpty ? nil : description, detail: detail, imageURL: url)
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