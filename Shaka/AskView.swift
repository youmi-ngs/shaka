//
//  AskView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI

struct AskView: View {
    @State private var showPostQuestion = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Text("Ask Page")
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showPostQuestion = true
                        }) {
                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding()
                                .background(Color.purple)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding()
                        .sheet(isPresented: $showPostQuestion) {
                            PostQuestionView()
                        }
                    }
                }
            }
            .navigationTitle("Ask Friends")
        }
    }
}

#Preview {
    AskView()
}
