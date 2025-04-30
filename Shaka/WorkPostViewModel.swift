//
//  WorkPostViewModel.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/05/01.
//

import Foundation

class WorkPostViewModel: ObservableObject {
    @Published var posts: [WorkPost] = []
    
    func addPost(title: String, description: String, imageURL: URL?) {
        let newPost = WorkPost(title: title, description: description, imageURL: imageURL, createdAt: Date())
        posts.insert(newPost, at: 0)
    }
}
