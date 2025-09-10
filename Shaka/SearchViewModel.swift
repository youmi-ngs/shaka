//
//  SearchViewModel.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import Foundation
import FirebaseFirestore
import Combine

enum SearchType: String, CaseIterable {
    case title = "Title"
    case tag = "Tag"
    case user = "User"
    
    var icon: String {
        switch self {
        case .title:
            return "doc.text.magnifyingglass"
        case .tag:
            return "tag"
        case .user:
            return "person.magnifyingglass"
        }
    }
}

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchType: SearchType = .title
    @Published var workResults: [WorkPost] = []
    @Published var questionResults: [QuestionPost] = []
    @Published var userResults: [(uid: String, displayName: String, photoURL: String?)] = []
    @Published var isSearching = false
    
    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // デバウンス検索（入力が止まってから0.5秒後に検索）
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                if !text.isEmpty {
                    self?.performSearch()
                } else {
                    self?.clearResults()
                }
            }
            .store(in: &cancellables)
    }
    
    func performSearch() {
        guard !searchText.isEmpty else {
            clearResults()
            return
        }
        
        isSearching = true
        
        switch searchType {
        case .title:
            searchByTitle()
        case .tag:
            searchByTag()
        case .user:
            searchByUser()
        }
    }
    
    private func searchByTitle() {
        let searchLower = searchText.lowercased()
        
        // Works検索
        db.collection("works")
            .order(by: "title")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.isSearching = false
                    return
                }
                
                self.workResults = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    let title = data["title"] as? String ?? ""
                    
                    // 前方一致検索
                    if title.lowercased().hasPrefix(searchLower) {
                        return self.createWorkPost(from: doc)
                    }
                    return nil
                } ?? []
                
                self.isSearching = false
            }
        
        // Questions検索
        db.collection("questions")
            .order(by: "title")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    return
                }
                
                self.questionResults = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    let title = data["title"] as? String ?? ""
                    
                    // 前方一致検索
                    if title.lowercased().hasPrefix(searchLower) {
                        return self.createQuestionPost(from: doc)
                    }
                    return nil
                } ?? []
            }
    }
    
    private func searchByTag() {
        let searchLower = searchText.lowercased()
        
        // Works検索（タグ含む）
        db.collection("works")
            .whereField("tags", arrayContains: searchLower)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.isSearching = false
                    return
                }
                
                self.workResults = snapshot?.documents.compactMap { doc in
                    self.createWorkPost(from: doc)
                } ?? []
                
                self.isSearching = false
            }
        
        // Questions検索（タグ含む）
        db.collection("questions")
            .whereField("tags", arrayContains: searchLower)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    return
                }
                
                self.questionResults = snapshot?.documents.compactMap { doc in
                    self.createQuestionPost(from: doc)
                } ?? []
            }
    }
    
    private func searchByUser() {
        let searchLower = searchText.lowercased()
        
        // Users検索
        db.collection("users")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.isSearching = false
                    return
                }
                
                self.userResults = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    
                    // 削除されたユーザーを除外
                    if let isDeleted = data["isDeleted"] as? Bool, isDeleted {
                        return nil
                    }
                    
                    if let publicData = data["public"] as? [String: Any],
                       let displayName = publicData["displayName"] as? String {
                        // 前方一致検索
                        if displayName.lowercased().hasPrefix(searchLower) {
                            let photoURL = publicData["photoURL"] as? String
                            return (uid: doc.documentID, displayName: displayName, photoURL: photoURL)
                        }
                    }
                    return nil
                } ?? []
                
                self.isSearching = false
            }
    }
    
    func clearResults() {
        workResults = []
        questionResults = []
        userResults = []
    }
    
    private func createWorkPost(from document: QueryDocumentSnapshot) -> WorkPost? {
        let data = document.data()
        let id = document.documentID
        let title = data["title"] as? String ?? ""
        let description = data["description"] as? String
        let detail = data["detail"] as? String
        let imageURLString = data["imageURL"] as? String
        let imageURL: URL? = imageURLString != nil ? URL(string: imageURLString!) : nil
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let userID = data["userID"] as? String ?? "unknown"
        let displayName = data["displayName"] as? String ?? "User_\(String(userID.prefix(6)))"
        let location = data["location"] as? GeoPoint
        let locationName = data["locationName"] as? String
        let isActive = data["isActive"] as? Bool ?? true
        let tags = data["tags"] as? [String] ?? []
        
        return WorkPost(
            id: id,
            title: title,
            description: description,
            detail: detail,
            imageURL: imageURL,
            createdAt: createdAt,
            userID: userID,
            displayName: displayName,
            location: location,
            locationName: locationName,
            isActive: isActive,
            tags: tags
        )
    }
    
    private func createQuestionPost(from document: QueryDocumentSnapshot) -> QuestionPost? {
        let data = document.data()
        let id = document.documentID
        let title = data["title"] as? String ?? ""
        let body = data["body"] as? String ?? ""
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let userID = data["userID"] as? String ?? "unknown"
        let displayName = data["displayName"] as? String ?? "User_\(String(userID.prefix(6)))"
        let location = data["location"] as? GeoPoint
        let locationName = data["locationName"] as? String
        let isActive = data["isActive"] as? Bool ?? true
        let tags = data["tags"] as? [String] ?? []
        
        return QuestionPost(
            id: id,
            title: title,
            body: body,
            createdAt: createdAt,
            userID: userID,
            displayName: displayName,
            location: location,
            locationName: locationName,
            isActive: isActive,
            tags: tags
        )
    }
}