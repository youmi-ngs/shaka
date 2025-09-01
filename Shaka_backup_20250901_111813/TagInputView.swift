//
//  TagInputView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI

struct TagInputView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    @FocusState private var isFocused: Bool
    
    let maxTags = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // タグ入力フィールド
            if tags.count < maxTags {
                HStack {
                    TextField("Add tag...", text: $newTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addTag()
                        }
                        .focused($isFocused)
                        .autocapitalization(.none)
                    
                    Button("Add") {
                        addTag()
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
            // タグリスト
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags.indices, id: \.self) { index in
                            TagChip(
                                tag: tags[index],
                                onDelete: {
                                    removeTag(at: index)
                                }
                            )
                        }
                    }
                }
            }
            
            // タグ数の表示
            HStack {
                Text("\(tags.count)/\(maxTags) tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if tags.count >= maxTags {
                    Text("Maximum tags reached")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "#", with: "") // #を除去
        
        if !trimmedTag.isEmpty && 
           !tags.contains(trimmedTag) && 
           tags.count < maxTags &&
           trimmedTag.count <= 30 { // タグの最大文字数
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func removeTag(at index: Int) {
        tags.remove(at: index)
    }
}

struct TagChip: View {
    let tag: String
    var onDelete: (() -> Void)? = nil
    var isClickable: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
                .foregroundColor(isClickable ? .blue : .primary)
            
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
        .onTapGesture {
            if isClickable {
                onTap?()
            }
        }
    }
}

#Preview {
    @State var tags = ["photography", "nature", "tokyo"]
    return TagInputView(tags: $tags)
        .padding()
}
