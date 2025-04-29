//
//  SeeWorksView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI

struct SeeWorksView: View {
    @State private var showPostWork = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Text("See Works Page")
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showPostWork = true
                        }) {
                            Image(systemName: "plus")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding()
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding()
                        .sheet(isPresented: $showPostWork) {
                            PostWorkView()
                        }
                    }
                }
            }
            .navigationTitle("See Works")
        }
    }
}

#Preview {
    SeeWorksView()
}
