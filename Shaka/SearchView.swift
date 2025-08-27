//
//  SearchView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @StateObject private var workViewModel = WorkPostViewModel()
    @StateObject private var questionViewModel = QuestionPostViewModel()
    @State private var showingUserProfile: String?
    
    let initialSearchText: String?
    let initialSearchType: SearchType?
    
    init(initialSearchText: String? = nil, initialSearchType: SearchType? = nil) {
        self.initialSearchText = initialSearchText
        self.initialSearchType = initialSearchType
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 検索タイプ選択
                Picker("Search Type", selection: $viewModel.searchType) {
                    ForEach(SearchType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: viewModel.searchType) { _ in
                    viewModel.performSearch()
                }
            }
            .padding(.vertical)
            .background(Color(UIColor.systemBackground))
            
            // 検索結果
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else if viewModel.searchText.isEmpty {
                        EmptySearchView()
                            .padding(.top, 50)
                    } else {
                        // Works結果
                        if !viewModel.workResults.isEmpty {
                            Section(header: Text("Works")
                                .font(.headline)
                                .padding(.horizontal)) {
                                ForEach(viewModel.workResults) { post in
                                    NavigationLink(destination: WorkDetailView(post: post, viewModel: workViewModel)) {
                                        SearchResultCard(
                                            title: post.title,
                                            subtitle: post.displayName,
                                            imageURL: post.imageURL,
                                            tags: post.tags
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // Questions結果
                        if !viewModel.questionResults.isEmpty {
                            Section(header: Text("Questions")
                                .font(.headline)
                                .padding(.horizontal)) {
                                ForEach(viewModel.questionResults) { post in
                                    NavigationLink(destination: QuestionDetailView(post: post, viewModel: questionViewModel)) {
                                        SearchResultCard(
                                            title: post.title,
                                            subtitle: post.displayName,
                                            imageURL: nil,
                                            tags: post.tags
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // Users結果
                        if !viewModel.userResults.isEmpty {
                            Section(header: Text("Users")
                                .font(.headline)
                                .padding(.horizontal)) {
                                ForEach(viewModel.userResults, id: \.uid) { user in
                                    Button(action: {
                                        showingUserProfile = user.uid
                                    }) {
                                        HStack(spacing: 12) {
                                            // ユーザーアバター
                                            UserAvatarView(uid: user.uid, size: 50)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(user.displayName)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Text("@\(user.uid.prefix(8))...")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // 結果なし
                        if viewModel.workResults.isEmpty && 
                           viewModel.questionResults.isEmpty && 
                           viewModel.userResults.isEmpty &&
                           !viewModel.searchText.isEmpty {
                            NoResultsView(searchText: viewModel.searchText, searchType: viewModel.searchType)
                                .padding(.top, 50)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding<IdentifiableString?>(
            get: { showingUserProfile.map { IdentifiableString(id: $0) } },
            set: { showingUserProfile = $0?.value }
        )) { item in
            NavigationView {
                PublicProfileView(authorUid: item.value)
            }
        }
        .onAppear {
            if let initialText = initialSearchText {
                viewModel.searchText = initialText
            }
            if let initialType = initialSearchType {
                viewModel.searchType = initialType
            }
        }
    }
}

struct SearchResultCard: View {
    let title: String
    let subtitle: String
    let imageURL: URL?
    let tags: [String]
    
    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            if let imageURL = imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                    case .failure(_), .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.cyan)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Start Searching")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Search for posts by title, tags, or users")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NoResultsView: View {
    let searchText: String
    let searchType: SearchType
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Results")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("No \(searchType.rawValue.lowercased())s found for \"\(searchText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SearchView()
}
