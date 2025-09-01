//
//  DiscoverView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/04/28.
//

import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

struct DiscoverView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var workViewModel = WorkPostViewModel()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6814, longitude: 139.7667), // 東京駅
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showUserLocation = false
    @State private var trackingMode: MapUserTrackingMode = .follow
    @State private var workPins: [WorkMapPin] = []
    @State private var selectedWork: WorkPost?
    @State private var mapType: MKMapType = .standard
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6814, longitude: 139.7667),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    
    var body: some View {
        ZStack {
            // 地図表示（iOS 17以降の新API）
            if #available(iOS 17.0, *) {
                    Map(position: $cameraPosition) {
                        // ユーザー位置は表示しない（プライバシー対応）
                        // UserAnnotation()
                        
                        // ピン表示
                        ForEach(workPins) { pin in
                            Annotation(pin.post.title, coordinate: pin.coordinate) {
                                PinView(pinType: .work)
                                    .onTapGesture {
                                        selectedWork = pin.post
                                    }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .flat))
                    .edgesIgnoringSafeArea(.bottom)
                } else {
                    // iOS 16以前のフォールバック
                    Map(
                        coordinateRegion: $region,
                        showsUserLocation: true,
                        userTrackingMode: $trackingMode,
                        annotationItems: workPins
                    ) { pin in
                        MapAnnotation(coordinate: pin.coordinate) {
                            PinView(pinType: .work)
                                .onTapGesture {
                                    selectedWork = pin.post
                                }
                        }
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
                
                // UI オーバーレイ（iOS 16以前のみ現在地ボタンを表示）
                if #unavailable(iOS 17.0) {
                    VStack {
                        Spacer()
                        
                        // 現在地ボタン
                        HStack {
                            Spacer()
                            Button(action: {
                                centerOnUserLocation()
                            }) {
                                Image(systemName: "location.fill")
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            .padding()
                        }
                    }
                }
        }
        .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // locationManager.requestLocationPermission() // 位置情報許可を求めない
                loadPosts()
            }
            .refreshable {
                loadPosts()
            }
            .sheet(item: $selectedWork) { work in
                NavigationView {
                    WorkDetailView(post: work, viewModel: workViewModel)
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .onDisappear {
                    // WorkDetailViewから戻ってきた時にデータを再読み込み
                    loadPosts()
                }
            }
    }
    
    private func centerOnUserLocation() {
        if let location = locationManager.userLocation {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                trackingMode = .follow
            }
        }
    }
    
    private func loadPosts() {
        // 作品投稿を取得
        workViewModel.fetchPostsWithLocation { posts in
            self.workPins = posts.compactMap { post in
                guard let coordinate = post.coordinate else { 
                    return nil 
                }
                return WorkMapPin(post: post, coordinate: coordinate)
            }
        }
    }
    
}

// マップピンのプロトコル
protocol MapPinProtocol: Identifiable {
    var id: String { get }
    var coordinate: CLLocationCoordinate2D { get }
    var title: String { get }
    var pinType: PinType { get }
}

enum PinType {
    case work
    case question
}

// 作品投稿用のマップピン
struct WorkMapPin: MapPinProtocol {
    let post: WorkPost
    let coordinate: CLLocationCoordinate2D
    
    var id: String { post.id }
    var title: String { post.title }
    var pinType: PinType { .work }
}

// ピンビュー
struct PinView: View {
    let pinType: PinType
    
    var body: some View {
        // 標準的な地図ピン
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 35))
            .foregroundColor(.mint)
            .background(
                Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
            )
    }
}

// 位置情報管理クラス
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

#Preview {
    DiscoverView()
}
