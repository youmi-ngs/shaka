//
//  ImageLoader.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/09.
//

import SwiftUI
import Combine

// MARK: - カスタム画像ローダー
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: ImageLoadError?
    
    private var cancellable: AnyCancellable?
    var retryCount = 0
    private let maxRetries = 3
    private let cache = ImageCache.shared
    
    enum ImageLoadError: LocalizedError {
        case invalidURL
        case downloadFailed(String)
        case decodingFailed
        case timeout
        case tooLarge
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid image URL"
            case .downloadFailed(let message):
                return "Download failed: \(message)"
            case .decodingFailed:
                return "Failed to decode image"
            case .timeout:
                return "Request timed out"
            case .tooLarge:
                return "Image too large"
            }
        }
    }
    
    func load(from url: URL?) {
        guard let url = url else {
            self.error = .invalidURL
            print("🖼❌ ImageLoader: Invalid URL")
            return
        }
        
        let urlString = url.absoluteString
        print("🖼 ImageLoader: Loading from \(urlString)")
        
        // キャッシュチェック
        if let cachedImage = cache.get(forKey: urlString) {
            print("🖼✅ ImageLoader: Cache hit")
            self.image = cachedImage
            return
        }
        
        loadWithRetry(from: url)
    }
    
    private func loadWithRetry(from url: URL) {
        isLoading = true
        error = nil
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30 // 30秒タイムアウト
        request.cachePolicy = .returnCacheDataElseLoad
        
        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ImageLoadError.downloadFailed("Invalid response")
                }
                
                print("🖼 HTTP Status: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw ImageLoadError.downloadFailed("HTTP \(httpResponse.statusCode)")
                }
                
                // サイズチェック（10MB制限）
                if data.count > 10 * 1024 * 1024 {
                    print("🖼⚠️ Image too large: \(data.count / 1024 / 1024)MB")
                    throw ImageLoadError.tooLarge
                }
                
                print("🖼 Downloaded: \(data.count / 1024)KB")
                return data
            }
            .tryMap { data -> UIImage in
                guard let image = UIImage(data: data) else {
                    throw ImageLoadError.decodingFailed
                }
                return image
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    switch completion {
                    case .finished:
                        print("🖼✅ Image loaded successfully")
                    case .failure(let error):
                        print("🖼❌ Load failed: \(error.localizedDescription)")
                        
                        // リトライロジック
                        if let self = self, self.retryCount < self.maxRetries {
                            self.retryCount += 1
                            print("🖼🔄 Retrying... (\(self.retryCount)/\(self.maxRetries))")
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(self.retryCount)) {
                                self.loadWithRetry(from: url)
                            }
                        } else {
                            if let imageError = error as? ImageLoadError {
                                self?.error = imageError
                            } else if (error as NSError).code == NSURLErrorTimedOut {
                                self?.error = .timeout
                            } else {
                                self?.error = .downloadFailed(error.localizedDescription)
                            }
                        }
                    }
                },
                receiveValue: { [weak self] image in
                    self?.image = image
                    // キャッシュに保存
                    ImageCache.shared.set(image, forKey: url.absoluteString)
                }
            )
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}

// MARK: - シンプルなメモリキャッシュ
class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString, cost: image.pngData()?.count ?? 0)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - カスタム画像ビュー
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: Placeholder
    
    @StateObject private var loader = ImageLoader()
    
    init(url: URL?,
         @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }
    
    init(url: URL?) where Placeholder == ProgressView<EmptyView, EmptyView> {
        self.url = url
        self.placeholder = ProgressView()
    }
    
    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if loader.isLoading {
                placeholder
            } else if let error = loader.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        loader.retryCount = 0
                        loader.load(from: url)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                placeholder
            }
        }
        .onAppear {
            loader.load(from: url)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}