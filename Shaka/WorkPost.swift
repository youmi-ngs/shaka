//
//  WorkPost.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/30.
//

import Foundation

struct WorkPost: Identifiable {
    let id = UUID()
    let title: String
    let description: String?
    let detail: String?
    let imageURL: URL?
    let createdAt: Date
}
