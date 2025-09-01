//
//  PostQuestionView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/29.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct PostQuestionView: View {
    @ObservedObject var viewModel: QuestionPostViewModel
    @Environment(\.dismiss) var dismiss
    
    let editingPost: QuestionPost?
    
    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var tags: [String] = []
    
    // 画像選択関連
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var uploadedImageURL: URL?
    
    init(viewModel: QuestionPostViewModel, editingPost: QuestionPost? = nil) {
        self.viewModel = viewModel
        self.editingPost = editingPost
    }
    
    var body: some View {
        NavigationView {
            ReusablePostFormView(
                title: $title,
                bodyText: $bodyText,
                isSubmitting: $isSubmitting,
                titlePlaceholder: "Enter your question title",
                bodyPlaceholder: "What would you like to ask?",
                bodyLabel: "Question Details",
                bodyRequired: true,
                submitButtonText: editingPost != nil ? "Save Changes" : "Submit Question",
                submitButtonColor: .purple,
                errorMessage: nil,
                canSubmit: !title.isEmpty && !bodyText.isEmpty && !isUploadingImage,
                onSubmit: submitQuestion,
                onCancel: { dismiss() },
                imageSection: {
                    // Image picker section
                    Section(header: HStack {
                        Text("Photo")
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }) {
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(8)
                            } else if let existingImageURL = editingPost?.imageURL ?? uploadedImageURL {
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
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("Add a photo (optional)")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .onChange(of: photoPickerItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImage = image
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
                }
            )
            .navigationTitle(editingPost != nil ? "Edit Question" : "Ask a Question")
            .onAppear {
                if let post = editingPost {
                    title = post.title
                    bodyText = post.body
                    tags = post.tags
                    uploadedImageURL = post.imageURL
                }
            }
        }
    }
    
    private func submitQuestion() {
        isSubmitting = true
        
        // 画像のアップロード処理
        if let image = selectedImage {
            isUploadingImage = true
            uploadImage(image) { url in
                DispatchQueue.main.async {
                    self.uploadedImageURL = url
                    self.isUploadingImage = false
                    self.saveQuestion()
                }
            }
        } else {
            saveQuestion()
        }
    }
    
    private func saveQuestion() {
        if let existingPost = editingPost {
            // Update existing question
            // 新しい画像がアップロードされた場合はそれを使い、そうでなければ既存の画像URLを保持
            let finalImageURL = uploadedImageURL ?? editingPost?.imageURL
            viewModel.updatePost(
                existingPost,
                title: title,
                body: bodyText,
                imageURL: finalImageURL,
                tags: tags
            )
        } else {
            // Add new question
            viewModel.addPost(
                title: title,
                body: bodyText,
                imageURL: uploadedImageURL,
                tags: tags
            )
        }
        
        // 非同期でビューを閉じる
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    private func uploadImage(_ image: UIImage, completion: @escaping (URL?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        // 認証状態を確認
        guard AuthManager.shared.getCurrentUserID() != nil else {
            completion(nil)
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imageName = UUID().uuidString + ".jpg"
        let imageRef = storageRef.child("question_images/\(imageName)")
        
        // メタデータを設定
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(nil)
                return
            }
            
            imageRef.downloadURL { url, error in
                if error != nil {
                    completion(nil)
                } else if let url = url {
                    completion(url)
                } else {
                    completion(nil)
                }
            }
        }
    }
}

#Preview {
    PostQuestionView(viewModel: QuestionPostViewModel())
}
