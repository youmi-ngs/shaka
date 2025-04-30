//
//  QuestionPost.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/30.
//

import Foundation

struct QuestionPost: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let createdAt: Date
}
