//
//  NavigationPopModifier.swift
//  Shaka
//
//  Created by Assistant on 2025/09/03.
//

import SwiftUI

struct NavigationPopModifier: ViewModifier {
    let tabIndex: Int
    @State private var navigationId = UUID()
    
    func body(content: Content) -> some View {
        content
            .id(navigationId)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PopToRootView"))) { notification in
                guard let userInfo = notification.userInfo,
                      let tab = userInfo["tab"] as? Int,
                      tab == tabIndex else { return }
                
                // NavigationViewを強制的にリセット
                navigationId = UUID()
            }
    }
}

extension View {
    func popToRootOnTabReselect(tabIndex: Int) -> some View {
        self.modifier(NavigationPopModifier(tabIndex: tabIndex))
    }
}