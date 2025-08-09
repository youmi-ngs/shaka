//
//  OptimizedImageView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/09.
//

import SwiftUI

struct OptimizedImageView: View {
    let url: URL?
    var maxHeight: CGFloat = 300
    
    @StateObject private var loader = ImageLoader()
    
    var body: some View {
        Group {
            if let url = url {
                GeometryReader { geometry in
                    ZStack {
                        // 背景
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                        
                        // 画像本体
                        if let image = loader.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width)
                                .frame(maxHeight: maxHeight)
                        } else if loader.isLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .frame(width: geometry.size.width, height: min(geometry.size.width * 0.6, maxHeight))
                        } else if loader.error != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                
                                Text("Failed to load image")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("Retry") {
                                    loader.retryCount = 0
                                    loader.load(from: url)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .frame(width: geometry.size.width, height: min(geometry.size.width * 0.6, maxHeight))
                        }
                    }
                }
                .aspectRatio(16/9, contentMode: .fit) // 一般的な写真の比率
                .frame(maxHeight: maxHeight)
                .onAppear {
                    loader.load(from: url)
                }
                .onDisappear {
                    loader.cancel()
                }
            } else {
                // URLがない場合
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxHeight: maxHeight)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No image")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
        .cornerRadius(12)
        .clipped()
    }
}

// カード用の最適化されたイメージビュー
struct CardImageView: View {
    let url: URL?
    
    @StateObject private var loader = ImageLoader()
    
    var body: some View {
        ZStack {
            // 背景（プレースホルダー）
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
            
            // 画像
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minHeight: 150, maxHeight: 250)
                    .clipped()
                    .cornerRadius(12)
            } else if loader.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if loader.error != nil {
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    
                    Button("Retry") {
                        loader.retryCount = 0
                        loader.load(from: url)
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            } else if url == nil {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No image")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .onAppear {
            if let url = url {
                loader.load(from: url)
            }
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

#Preview("OptimizedImageView") {
    VStack {
        OptimizedImageView(url: URL(string: "https://picsum.photos/400/300"))
            .padding()
        
        CardImageView(url: URL(string: "https://picsum.photos/400/300"))
            .padding()
    }
}