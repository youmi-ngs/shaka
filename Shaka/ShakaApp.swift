//
//  ShakaApp.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct ShakaApp: App {
    init() {
        FirebaseApp.configure()
        let db = Firestore.firestore()
        print("Firestore instance:", db)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
