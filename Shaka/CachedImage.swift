//
//  CachedAsyncImage.swift
//  Shaka
//
//  Created by Assistant on 2025/09/03.
//

import SwiftUI

/// メモリとディスクキャッシュを備えた高速画像ローダー
struct CachedImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let scale: CGFloat
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty
    @StateObject private var loader = ImageCacheManager.shared
    
    init(url: URL?,
         scale: CGFloat = 1,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
                    .onAppear { loadImage() }
            case .success(let image):
                content(image)
            case .failure(_):
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            @unknown default:
                placeholder()
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }
        
        Task {
            phase = await loader.loadImage(from: url, scale: scale)
        }
    }
}

// MARK: - Image Cache Manager
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // メモリキャッシュの設定
        cache.countLimit = 100 // 最大100枚
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        
        // ディスクキャッシュディレクトリの設定
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        // ディレクトリ作成
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 古いキャッシュの削除（7日以上）
        cleanOldCache()
    }
    
    @MainActor
    func loadImage(from url: URL, scale: CGFloat) async -> AsyncImagePhase {
        // メモリキャッシュから取得
        if let cachedImage = cache.object(forKey: url as NSURL) {
            return .success(Image(uiImage: cachedImage))
        }
        
        // ディスクキャッシュから取得
        let diskCacheURL = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        if let diskImage = UIImage(contentsOfFile: diskCacheURL.path) {
            cache.setObject(diskImage, forKey: url as NSURL)
            return .success(Image(uiImage: diskImage))
        }
        
        // ネットワークから取得
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else {
                return .failure(URLError(.cannotDecodeContentData))
            }
            
            // 画像を圧縮してキャッシュ
            let compressedImage = compressImage(uiImage)
            
            // メモリキャッシュに保存
            cache.setObject(compressedImage, forKey: url as NSURL)
            
            // ディスクキャッシュに保存
            if let jpegData = compressedImage.jpegData(compressionQuality: 0.8) {
                try? jpegData.write(to: diskCacheURL)
            }
            
            return .success(Image(uiImage: compressedImage))
        } catch {
            return .failure(error)
        }
    }
    
    private func compressImage(_ image: UIImage) -> UIImage {
        let maxSize: CGFloat = 1024 // 最大1024px
        let size = image.size
        
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func cleanOldCache() {
        let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7日前
        
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < expirationDate {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Convenience Init
extension CachedImage {
    init(url: URL?,
         scale: CGFloat = 1,
         @ViewBuilder content: @escaping (Image) -> Content) where Placeholder == ProgressView<EmptyView, EmptyView> {
        self.init(url: url, scale: scale, content: content) {
            ProgressView()
        }
    }
}