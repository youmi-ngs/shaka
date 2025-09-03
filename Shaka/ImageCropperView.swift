//
//  ImageCropperView.swift
//  Shaka
//
//  Created by Assistant on 2025/09/03.
//

import SwiftUI

struct ImageCropperView: View {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    
    private let cropSize: CGFloat = 300
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                // メインコンテンツ
                ZStack {
                            // Image to crop (下層に配置)
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            
                                            // Minimum scale to ensure image fills crop area
                                            let minScale = imageSize.width > 0 && imageSize.height > 0 ? 
                                                max(cropSize / imageSize.width, cropSize / imageSize.height) : 0.5
                                            scale = min(max(minScale, scale * delta), 5.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            validateImagePosition()
                                        }
                                )
                                .simultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                            validateImagePosition()
                                        }
                                )
                            
                            // グレーアウトのオーバーレイ（円形の穴付き）
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .mask(
                                    ZStack {
                                        Rectangle()
                                            .fill(Color.white)
                                        
                                        Circle()
                                            .fill(Color.black)
                                            .frame(width: cropSize, height: cropSize)
                                    }
                                    .compositingGroup()
                                    .luminanceToAlpha()
                                )
                                .allowsHitTesting(false)
                            
                            // 円形の境界線
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: cropSize, height: cropSize)
                                .allowsHitTesting(false)
                }
                
                // NavigationBarスタイルのボタン
                VStack {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .font(.body)
                        .padding()
                        
                        Spacer()
                        
                        Button("Choose") {
                            cropImage()
                        }
                        .foregroundColor(.white)
                        .font(.body.weight(.semibold))
                        .padding()
                    }
                    .padding(.top, 50) // ステータスバー分の余白
                    
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            setupInitialScale()
        }
    }
    
    private func setupInitialScale() {
        // 画像を画面幅100%で表示（フィット表示）
        // 画像のサイズを取得
        let imageAspect = image.size.width / image.size.height
        
        // 画面サイズを仮定（実際の画面幅を使用）
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let screenAspect = screenWidth / screenHeight
        
        if imageAspect > screenAspect {
            // 画像の方が横長 - 幅に合わせる
            imageSize = CGSize(
                width: screenWidth,
                height: screenWidth / imageAspect
            )
        } else {
            // 画像の方が縦長 - 高さに合わせる
            imageSize = CGSize(
                width: screenHeight * imageAspect,
                height: screenHeight
            )
        }
        
        // 初期スケールを設定して円をカバーするかチェック
        let minScale = max(cropSize / imageSize.width, cropSize / imageSize.height)
        if minScale > 1.0 {
            scale = minScale
        }
    }
    
    private func validateImagePosition() {
        guard imageSize.width > 0 && imageSize.height > 0 else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            // Ensure minimum scale - 円を完全にカバーする最小スケール
            let minScale = max(cropSize / imageSize.width, cropSize / imageSize.height)
            if scale < minScale {
                scale = minScale
            }
            
            // Calculate bounds for offset to keep crop area covered
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            
            // 画像の端が円の外に出ないようにオフセットを制限
            let maxOffsetX = max(0, (scaledWidth - cropSize) / 2)
            let maxOffsetY = max(0, (scaledHeight - cropSize) / 2)
            
            if abs(offset.width) > maxOffsetX {
                offset.width = offset.width > 0 ? maxOffsetX : -maxOffsetX
            }
            
            if abs(offset.height) > maxOffsetY {
                offset.height = offset.height > 0 ? maxOffsetY : -maxOffsetY
            }
            
            lastOffset = offset
        }
    }
    
    private func cropImage() {
        guard imageSize.width > 0 && imageSize.height > 0 else { return }
        
        // 画像の実際のサイズに対する表示サイズの比率を計算
        let displayScale = imageSize.width / image.size.width
        
        // クロップ領域の中心からのオフセットを考慮
        let cropSizeInImageCoords = cropSize / (displayScale * scale)
        let offsetInImageCoords = CGSize(
            width: -offset.width / (displayScale * scale),
            height: -offset.height / (displayScale * scale)
        )
        
        let cropRect = CGRect(
            x: (image.size.width - cropSizeInImageCoords) / 2 + offsetInImageCoords.width,
            y: (image.size.height - cropSizeInImageCoords) / 2 + offsetInImageCoords.height,
            width: cropSizeInImageCoords,
            height: cropSizeInImageCoords
        )
        
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            dismiss()
            return
        }
        
        let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        
        // Create circular cropped image
        let screenScale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(CGSize(width: cropSize, height: cropSize), false, screenScale)
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
        path.addClip()
        croppedUIImage.draw(in: CGRect(x: 0, y: 0, width: cropSize, height: cropSize))
        
        if let circularImage = UIGraphicsGetImageFromCurrentImageContext() {
            croppedImage = circularImage
        }
        UIGraphicsEndImageContext()
        
        dismiss()
    }
}

struct ImageCropperView_Previews: PreviewProvider {
    static var previews: some View {
        ImageCropperView(
            image: UIImage(systemName: "person.fill")!,
            croppedImage: .constant(nil)
        )
    }
}