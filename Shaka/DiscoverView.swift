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
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), // 東京
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showUserLocation = false
    @State private var trackingMode: MapUserTrackingMode = .follow
    @State private var workPins: [WorkMapPin] = []
    @State private var selectedWork: WorkPost?
    
    var body: some View {
        NavigationView {
            ZStack {
                // 地図表示
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
                
                // UI オーバーレイ
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
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationManager.requestLocationPermission()
                loadPosts()
            }
            .sheet(item: $selectedWork) { work in
                NavigationView {
                    WorkDetailView(post: work, viewModel: workViewModel)
                }
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
                guard let coordinate = post.coordinate else { return nil }
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
        VStack(spacing: 0) {
            // ピンアイコン
            Image(systemName: "photo.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
                .background(Circle().fill(Color.white).frame(width: 36, height: 36))
                .shadow(radius: 2)
            
            // ピンの先端
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
                .rotationEffect(.degrees(180))
                .offset(y: -5)
        }
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
