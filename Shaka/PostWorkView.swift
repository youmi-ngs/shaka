//
//  PostWorkView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/29.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import CoreLocation

struct PostWorkView: View {
    @ObservedObject var viewModel: WorkPostViewModel
    @Environment(\.dismiss) var dismiss
    
    let editingPost: WorkPost?
    let presetLocation: CLLocationCoordinate2D?
    let presetLocationName: String?
    
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
    @State private var tags: [String] = []
    
    // 位置情報関連
    @State private var useCurrentLocation = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showLocationPicker = false
    @State private var hasInitializedLocation = false
    
    init(viewModel: WorkPostViewModel, editingPost: WorkPost? = nil, presetLocation: CLLocationCoordinate2D? = nil, presetLocationName: String? = nil) {
        self.viewModel = viewModel
        self.editingPost = editingPost
        self.presetLocation = presetLocation
        self.presetLocationName = presetLocationName
    }

    var body: some View {
        NavigationView {
            ReusablePostFormView(
                title: $title,
                bodyText: $description,
                isSubmitting: $isUploading,
                titlePlaceholder: "Enter the work title",
                bodyPlaceholder: "Enter the work description",
                bodyLabel: "Description",
                submitButtonText: editingPost != nil ? "Save Changes" : "Submit Work",
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
                        } else if let existingImageURL = editingPost?.imageURL {
                            AsyncImage(url: existingImageURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(8)
                                        .overlay(
                                            VStack {
                                                Spacer()
                                                Text("Tap to change photo")
                                                    .font(.caption)
                                                    .padding(8)
                                                    .background(Color.black.opacity(0.6))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                                    .padding()
                                            }
                                        )
                                case .failure(_):
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 200)
                                        .overlay(Text("Failed to load image"))
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 200)
                                        .overlay(ProgressView())
                                @unknown default:
                                    EmptyView()
                                }
                            }
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
                // Tags section
                Section(header: HStack {
                    Text("Tags")
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }) {
                    TagInputView(tags: $tags)
                }
                
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
                    
                    // 位置情報の設定
                    Toggle("Add Map Location", isOn: $useCurrentLocation)
                    
                    if useCurrentLocation {
                        Button(action: {
                            showLocationPicker = true
                        }) {
                            HStack {
                                Image(systemName: selectedCoordinate != nil ? "mappin.circle.fill" : "mappin.circle")
                                VStack(alignment: .leading) {
                                    Text(selectedCoordinate != nil ? "Location Set" : "Select Location on Map")
                                    if !location.isEmpty {
                                        Text(location)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .foregroundColor(selectedCoordinate != nil ? .green : .blue)
                        }
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
            .navigationTitle(editingPost != nil ? "Edit Work" : "Post a Work")
            .onAppear {
                if let post = editingPost {
                    loadPostData(post)
                } else if let presetCoord = presetLocation, !hasInitializedLocation {
                    // Use preset location only once for new posts from map
                    selectedCoordinate = presetCoord
                    location = presetLocationName ?? ""
                    useCurrentLocation = true
                    hasInitializedLocation = true
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    EnhancedLocationPickerView(
                        selectedCoordinate: $selectedCoordinate,
                        locationName: $location
                    )
                }
                .navigationViewStyle(StackNavigationViewStyle()) // Force stack style to avoid issues
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Consistent navigation style
    }
    
    private var canSubmit: Bool {
        !title.isEmpty && (selectedImage != nil || editingPost != nil)
    }
    
    private func submitWork() {
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                var imageURL: URL?
                
                // Handle image upload if there's a new image
                if let image = selectedImage {
                    
                    // Convert image to JPEG data
                    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                        throw UploadError.imageConversionFailed
                    }
                    
                    
                    // Create unique filename
                    let filename = "\(UUID().uuidString).jpg"
                    let storageRef = Storage.storage().reference().child("works/\(filename)")
                    
                    
                    // Upload image
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    
                    _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                    
                    // Get download URL
                    let downloadURL = try await storageRef.downloadURL()
                    imageURL = URL(string: downloadURL.absoluteString)
                    
                } else if let existingPost = editingPost {
                    // Use existing image URL if editing without changing image
                    imageURL = existingPost.imageURL
                }
                
                // Combine photo details into a single string if any are provided
                var detailComponents: [String] = []
                
                if isPhotoDateEnabled, let date = photoDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    detailComponents.append("Date: \(formatter.string(from: date))")
                }
                
                // Location は locationName フィールドで別管理するので detail には含めない
                
                if !cameraSettings.isEmpty {
                    detailComponents.append("Settings: \(cameraSettings)")
                }
                
                let detail = detailComponents.isEmpty ? nil : detailComponents.joined(separator: "\n")
                
                await MainActor.run {
                    let finalLocation = useCurrentLocation ? selectedCoordinate : nil
                    let finalLocationName = location.isEmpty ? nil : location
                    
                    if let existingPost = editingPost {
                        // Update existing post
                        viewModel.updatePost(
                            existingPost,
                            title: title,
                            description: description.isEmpty ? nil : description,
                            detail: detail,
                            imageURL: imageURL,
                            location: finalLocation,
                            locationName: finalLocationName,
                            tags: tags
                        )
                    } else {
                        // Add new post
                        viewModel.addPost(
                            title: title,
                            description: description.isEmpty ? nil : description,
                            detail: detail,
                            imageURL: imageURL,
                            location: finalLocation,
                            locationName: finalLocationName,
                            tags: tags
                        )
                    }
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    uploadError = "Failed to upload image: \(error.localizedDescription)"
                    isUploading = false
                }
            }
        }
    }
    
    private func loadPostData(_ post: WorkPost) {
        title = post.title
        description = post.description ?? ""
        tags = post.tags  // タグを読み込み
        
        // 位置情報を読み込み
        if let coordinate = post.coordinate {
            selectedCoordinate = coordinate
            useCurrentLocation = true
        }
        if let locationName = post.locationName {
            location = locationName
        }
        
        // Parse detail field
        if let detail = post.detail {
            let lines = detail.split(separator: "\n")
            for line in lines {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    switch key {
                    case "Date":
                        DispatchQueue.main.async {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            if let date = formatter.date(from: value) {
                                self.photoDate = date
                                self.isPhotoDateEnabled = true
                            }
                        }
                    case "Location":
                        break // Skip - location is now handled by locationName field
                    case "Settings":
                        cameraSettings = value
                    default:
                        break
                    }
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
