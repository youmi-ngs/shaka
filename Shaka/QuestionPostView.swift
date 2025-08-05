//
//  QuestionPostView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/05/01.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

class QuestionPostViewModel: ObservableObject {
    @Published var posts: [QuestionPost] = []
    
    private let db = Firestore.firestore()
    
    func addPost(title: String, body: String) {
        let newPost =  QuestionPost(title: title, body: body, createdAt: Date())
        posts.insert(newPost, at: 0)
        
        let data: [String: Any] = ["title": newPost.title, "body": newPost.body, "createdAt": Timestamp(date: newPost.createdAt)]
        
        db.collection("questions").addDocument(data: data) { error in
            if let error = error {
                print("Error saving question to Firestore: \(error)")
            } else {
              print("Question successfully saved to Firestore!")
            }
        }
    }
}
