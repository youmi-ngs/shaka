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
    @State private var imageURL: URL? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

    var body: some View {
        NavigationView {
            
            if let url = imageURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(8)
                        .padding(.horizontal)
                } placeholder: {
                    ProgressView()
                        .frame(height: 200)
                }
            }
            
            Form {
                
                Section(header: Text("Title")) {
                    TextField("Enter the work title", text: $title)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                }
                
                
                Section(header: Text("Photo")) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()) {
                            Text("Select photo")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                    
                    if let imageData = selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                }
                
                Button(action: {
                    Task {
                        var uploadedURL: URL? = nil

                        if let data = selectedImageData {
                            uploadedURL = await uploadImageToStorage(data: data)
                        }

                        viewModel.addPost(title: title, description: description, imageURL: uploadedURL)
                        dismiss()
                        print("Submit Work button tapped!")
                    }
                }) {
                    Text("Submit Work")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty || description.isEmpty ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(title.isEmpty || description.isEmpty)
            }
            .navigationTitle("Post a Work")
        }
    }
    
    func uploadImageToStorage(data: Data) async -> URL? {
        let filename = UUID().uuidString + ".jpg"
        let storageRef = Storage.storage().reference().child("images/\(filename)")

        do {
            let _ = try await storageRef.putDataAsync(data)
            let url = try await storageRef.downloadURL()
            return url
        } catch {
            print("Upload failed: \(error)")
            return nil
        }
    }
    
}

#Preview {
    PostWorkView(viewModel: WorkPostViewModel())
}
