//
//  MasonryLayout.swift
//  Shaka
//
//  Pinterest-style Masonry Layout for iPad
//

import SwiftUI

struct MasonryVGrid<Content: View, T: Identifiable>: View where T: Hashable {
    let columns: Int
    let spacing: CGFloat
    let items: [T]
    let content: (T) -> Content
    
    init(
        columns: Int = 2,
        spacing: CGFloat = 8,
        items: [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.columns = columns  // 呼び出し側で指定された列数を使用
        self.spacing = spacing
        self.items = items
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { columnIndex in
                        VStack(spacing: spacing) {
                            ForEach(itemsForColumn(columnIndex), id: \.self) { item in
                                content(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, spacing)
                .padding(.top, 8)
            }
        }
    }
    
    func itemsForColumn(_ column: Int) -> [T] {
        var result = [T]()
        for (index, item) in items.enumerated() {
            if index % columns == column {
                result.append(item)
            }
        }
        return result
    }
}

// Height-based distribution for better balance
struct SmartMasonryVGrid<Content: View, T: Identifiable>: View where T: Hashable {
    let columns: Int
    let spacing: CGFloat
    let items: [T]
    let content: (T) -> Content
    @State private var columnHeights: [CGFloat]
    
    init(
        columns: Int = 2,
        spacing: CGFloat = 8,
        items: [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.items = items
        self.content = content
        self._columnHeights = State(initialValue: Array(repeating: 0, count: columns))
    }
    
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columns, id: \.self) { columnIndex in
                    VStack(spacing: spacing) {
                        ForEach(itemsForColumn(columnIndex), id: \.self) { item in
                            content(item)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: HeightPreferenceKey.self,
                                            value: geo.size.height
                                        )
                                    }
                                )
                                .onPreferenceChange(HeightPreferenceKey.self) { height in
                                    // Track heights for smart distribution
                                    columnHeights[columnIndex] += height + spacing
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, spacing)
        }
    }
    
    func itemsForColumn(_ column: Int) -> [T] {
        var result = [T]()
        var tempHeights = Array(repeating: CGFloat(0), count: columns)
        
        for item in items {
            // Find the shortest column
            let shortestColumn = tempHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            
            if shortestColumn == column {
                result.append(item)
            }
            
            // Simulate adding height (approximate)
            tempHeights[shortestColumn] += 250 // Approximate height
        }
        
        return result
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}