//
//  UserProfileEditView.swift
//  Shaka
//
//  Edit view for user profile with validation
//

import SwiftUI
import PhotosUI

struct UserProfileEditView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    @Environment(\.dismiss) var dismiss
    
    let uid: String
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Photo Section
                Section(header: Text("Profile Photo")) {
                    HStack {
                        Spacer()
                        
                        VStack {
                            if let photoURL = viewModel.profile?.photoURL {
                                AsyncImage(url: photoURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                    case .failure(_):
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 80))
                                            .foregroundColor(.gray)
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 100, height: 100)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                            }
                            
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Text(viewModel.profile?.photoURL != nil ? "Change Photo" : "Add Photo")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .disabled(viewModel.isUploading)
                            .onChange(of: selectedPhotoItem) { newItem in
                                Task {
                                    await viewModel.processPhotoSelection(newItem)
                                }
                            }
                            
                            if viewModel.isUploading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Public Information Section
                Section(header: Text("Public Information")) {
                    // Display Name (Required)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Display Name")
                            Text("*")
                                .foregroundColor(.red)
                        }
                        TextField("Enter your display name", text: Binding(
                            get: { viewModel.profile?.public.displayName ?? "" },
                            set: { viewModel.profile?.public.displayName = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("\(viewModel.profile?.public.displayName.count ?? 0)/50")
                            .font(.caption)
                            .foregroundColor(
                                (viewModel.profile?.public.displayName.count ?? 0) > 50 ? .red : .secondary
                            )
                    }
                    
                    // Bio (Optional)
                    VStack(alignment: .leading) {
                        Text("Bio (Optional)")
                        TextEditor(text: Binding(
                            get: { viewModel.profile?.public.bio ?? "" },
                            set: { viewModel.profile?.public.bio = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        
                        Text("\(viewModel.profile?.public.bio?.count ?? 0)/300")
                            .font(.caption)
                            .foregroundColor(
                                (viewModel.profile?.public.bio?.count ?? 0) > 300 ? .red : .secondary
                            )
                    }
                }
                
                // Links Section
                Section(header: Text("Links (Optional)")) {
                    VStack(alignment: .leading) {
                        Label("Website", systemImage: "globe")
                            .font(.caption)
                        TextField("https://example.com", text: Binding(
                            get: { viewModel.profile?.public.links?.website ?? "" },
                            set: { newValue in
                                if viewModel.profile?.public.links == nil {
                                    viewModel.profile?.public.links = UserProfile.ProfileLinks()
                                }
                                viewModel.profile?.public.links?.website = newValue.isEmpty ? nil : newValue
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    }
                    
                    VStack(alignment: .leading) {
                        Label("Instagram", systemImage: "camera")
                            .font(.caption)
                        TextField("https://instagram.com/username", text: Binding(
                            get: { viewModel.profile?.public.links?.instagram ?? "" },
                            set: { newValue in
                                if viewModel.profile?.public.links == nil {
                                    viewModel.profile?.public.links = UserProfile.ProfileLinks()
                                }
                                viewModel.profile?.public.links?.instagram = newValue.isEmpty ? nil : newValue
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    }
                    
                    VStack(alignment: .leading) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                        TextField("https://github.com/username", text: Binding(
                            get: { viewModel.profile?.public.links?.github ?? "" },
                            set: { newValue in
                                if viewModel.profile?.public.links == nil {
                                    viewModel.profile?.public.links = UserProfile.ProfileLinks()
                                }
                                viewModel.profile?.public.links?.github = newValue.isEmpty ? nil : newValue
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    }
                }
                
                // Private Information Section (Read-only)
                if let privateInfo = viewModel.profile?.private {
                    Section(header: Text("Private Information")) {
                        HStack {
                            Text("Member Since")
                            Spacer()
                            Text(privateInfo.joinedAt.dateValue().formatted(date: .long, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                        
                        if let email = privateInfo.email {
                            HStack {
                                Text("Email")
                                Spacer()
                                Text(email)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Statistics Section (Read-only)
                if let stats = viewModel.profile?.stats {
                    Section(header: Text("Statistics")) {
                        HStack {
                            Label("Works", systemImage: "photo")
                            Spacer()
                            Text("\(stats.worksCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Questions", systemImage: "questionmark.circle")
                            Spacer()
                            Text("\(stats.questionsCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Messages Section
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                if let successMessage = viewModel.successMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMessage)
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveProfile()
                    }
                    .disabled(viewModel.isLoading || 
                             viewModel.profile?.public.displayName.isEmpty == true ||
                             (viewModel.profile?.public.displayName.count ?? 0) > 50)
                }
            }
            .onAppear {
                viewModel.loadProfile(uid: uid)
            }
            .onChange(of: viewModel.profileSaved) { saved in
                if saved {
                    // 保存成功時に画面を閉じる
                    dismiss()
                }
            }
            .disabled(viewModel.isLoading)
            .overlay(
                Group {
                    if viewModel.isLoading && viewModel.profile == nil {
                        ProgressView("Loading profile...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.3))
                    }
                }
            )
        }
    }
}