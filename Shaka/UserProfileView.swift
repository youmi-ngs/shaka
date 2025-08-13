//
//  UserProfileView.swift
//  Shaka
//
//  Read-only view for user profile
//

import SwiftUI
import FirebaseAuth

struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var showEditView = false
    
    let uid: String
    
    private var isOwnProfile: Bool {
        Auth.auth().currentUser?.uid == uid
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 16) {
                    // Avatar
                    if let photoURL = viewModel.profile?.photoURL {
                        AsyncImage(url: photoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                            case .failure(_):
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.gray)
                            case .empty:
                                ProgressView()
                                    .frame(width: 120, height: 120)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.gray)
                    }
                    
                    // Display Name
                    Text(viewModel.profile?.displayName ?? "Loading...")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Bio
                    if let bio = viewModel.profile?.public.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    // Stats
                    HStack(spacing: 30) {
                        VStack {
                            Text("\(viewModel.profile?.stats.worksCount ?? 0)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Works")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("\(viewModel.profile?.stats.questionsCount ?? 0)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Questions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Links Section
                if let links = viewModel.profile?.public.links {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Links")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            if let website = links.website, !website.isEmpty {
                                LinkRow(
                                    icon: "globe",
                                    title: "Website",
                                    url: website
                                )
                            }
                            
                            if let instagram = links.instagram, !instagram.isEmpty {
                                LinkRow(
                                    icon: "camera",
                                    title: "Instagram",
                                    url: instagram
                                )
                            }
                            
                            if let github = links.github, !github.isEmpty {
                                LinkRow(
                                    icon: "chevron.left.forwardslash.chevron.right",
                                    title: "GitHub",
                                    url: github
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Private Information (only visible to owner)
                if isOwnProfile, let privateInfo = viewModel.profile?.private {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Private Information")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                Text("Member since")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(privateInfo.joinedAt.dateValue().formatted(date: .long, time: .omitted))
                            }
                            
                            if let email = privateInfo.email {
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    Text("Email")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(email)
                                }
                            }
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        Text("This information is only visible to you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                
                // Edit Button (only for own profile)
                if isOwnProfile {
                    Button(action: {
                        showEditView = true
                    }) {
                        Label("Edit Profile", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadProfile(uid: uid)
        }
        .sheet(isPresented: $showEditView) {
            UserProfileEditView(uid: uid)
                .onDisappear {
                    // Reload profile after editing
                    viewModel.loadProfile(uid: uid)
                }
        }
        .overlay(
            Group {
                if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        )
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// Link Row Component
struct LinkRow: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url) ?? URL(string: "https://")!) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward.square")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

// Preview
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UserProfileView(uid: "sample-uid")
        }
    }
}