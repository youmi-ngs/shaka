//
//  QuestionPostView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/05/01.
//

import Foundation

class QuestionPostViewModel: ObservableObject {
    @Published var posts: [QuestionPost] = []
    
    func addPost(title: String, body: String) {
        let newPost =  QuestionPost(title: title, body: body, createdAt: Date())
        posts.insert(newPost, at: 0)
    }
}
