//
//  ContentView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        
        TabView {
            DiscoverView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Discover")
                }
            AskView()
                .tabItem {
                    Image(systemName: "hand.wave")
                    Text("Ask")
                }
            SeeWorksView()
                .tabItem {
                    Image(systemName: "eyeglasses")
                    Text("See Works")
                }
//            ChatView()
//                .tabItem {
//                    Image(systemName: "ellipsis.message")
//                    Text("Chat")
//                }
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
    }
}

#Preview {
    ContentView()
}
