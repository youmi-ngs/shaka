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
    @StateObject private var locationSharing = LocationSharingManager.shared
    @EnvironmentObject var authManager: AuthManager
    
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
    @State private var showLocationSharingSheet = false
    @State private var showPostWorkSheet = false
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var longPressLocationName: String = ""
    
    @ViewBuilder
    private var mapView: some View {
        if #available(iOS 17.0, *) {
            modernMapView
        } else {
            legacyMapView
        }
    }
    
    @available(iOS 17.0, *)
    @ViewBuilder
    private var modernMapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                mapAnnotations
            }
            .mapStyle(.standard(elevation: .flat))
            .edgesIgnoringSafeArea(.bottom)
            .onLongPressGesture(minimumDuration: 0.5) { location in
                handleLongPress(location: location, proxy: proxy)
            }
        }
    }
    
    @ViewBuilder
    private var legacyMapView: some View {
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
    
    @available(iOS 17.0, *)
    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        // Show current user location if sharing
        if locationSharing.isSharing,
           let location = locationSharing.currentLocation {
            Annotation("Me", coordinate: location.coordinate) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
        }
        
        // Show mutual followers' locations
        ForEach(locationSharing.mutualFollowersLocations) { userLocation in
            Annotation(userLocation.displayName, coordinate: userLocation.location) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(String(userLocation.displayName.prefix(1)))
                                .foregroundColor(.white)
                                .font(.caption.bold())
                        )
                    
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                        .offset(y: -5)
                }
            }
        }
        
        // Work posts pins
        ForEach(workPins) { pin in
            Annotation(pin.post.title, coordinate: pin.coordinate) {
                PinView(pinType: .work)
                    .onTapGesture {
                        selectedWork = pin.post
                    }
            }
        }
    }
    
    @available(iOS 17.0, *)
    private func handleLongPress(location: CGPoint, proxy: MapProxy) {
        if let coordinate = proxy.convert(location, from: .local) {
            longPressLocation = coordinate
            reverseGeocodeLocation(coordinate)
            showPostWorkSheet = true
        }
    }
    
    var body: some View {
        ZStack {
            mapView
                
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.userID != nil {
                        Button(action: {
                            if locationSharing.isSharing {
                                locationSharing.stopSharingLocation()
                            } else {
                                showLocationSharingSheet = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: locationSharing.isSharing ? "location.fill" : "location")
                                    .foregroundColor(locationSharing.isSharing ? .green : .primary)
                                if locationSharing.isSharing {
                                    Text(timeRemaining())
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                locationSharing.checkSharingStatus()
                locationSharing.startListeningToMutualLocations()
                loadPosts()
            }
            .onDisappear {
                locationSharing.stopListeningToMutualLocations()
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
            .sheet(isPresented: $showLocationSharingSheet) {
                LocationSharingSheet(
                    isPresented: $showLocationSharingSheet,
                    locationSharing: locationSharing
                )
            }
            .sheet(isPresented: $showPostWorkSheet) {
                if let location = longPressLocation {
                    PostWorkViewWithLocation(
                        viewModel: workViewModel,
                        presetLocation: location,
                        presetLocationName: longPressLocationName
                    )
                }
            }
    }
    
    private func timeRemaining() -> String {
        guard let expiresAt = locationSharing.sharingExpiresAt else { return "" }
        let remaining = expiresAt.timeIntervalSinceNow
        if remaining <= 0 { return "Expired" }
        
        let minutes = Int(remaining / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
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
    
    private func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    var components: [String] = []
                    
                    if let name = placemark.name {
                        components.append(name)
                    } else {
                        if let locality = placemark.locality {
                            components.append(locality)
                        }
                        if let administrativeArea = placemark.administrativeArea {
                            components.append(administrativeArea)
                        }
                    }
                    
                    self.longPressLocationName = components.isEmpty ? 
                        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude) :
                        components.joined(separator: ", ")
                } else {
                    self.longPressLocationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                }
            }
        }
    }
    
}

// PostWorkView wrapper with preset location
struct PostWorkViewWithLocation: View {
    @ObservedObject var viewModel: WorkPostViewModel
    let presetLocation: CLLocationCoordinate2D
    let presetLocationName: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        PostWorkView(
            viewModel: viewModel, 
            presetLocation: presetLocation,
            presetLocationName: presetLocationName
        )
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

// Location Sharing Sheet
struct LocationSharingSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var locationSharing: LocationSharingManager
    @State private var selectedDuration = 60.0 // Default 1 hour
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Share Location with Mutual Followers")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("Only people you follow who also follow you can see your location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Duration selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Duration")
                        .font(.headline)
                    
                    Picker("Duration", selection: $selectedDuration) {
                        Text("15 minutes").tag(15.0)
                        Text("30 minutes").tag(30.0)
                        Text("1 hour").tag(60.0)
                        Text("2 hours").tag(120.0)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                // Permission check
                if locationSharing.authorizationStatus == .notDetermined {
                    Button(action: {
                        locationSharing.requestLocationPermission()
                    }) {
                        Label("Enable Location Services", systemImage: "location")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                } else if locationSharing.authorizationStatus == .denied || 
                         locationSharing.authorizationStatus == .restricted {
                    VStack(spacing: 10) {
                        Label("Location Services Disabled", systemImage: "location.slash")
                            .foregroundColor(.red)
                        
                        Text("Please enable location services in Settings to share your location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Start sharing button
                    Button(action: {
                        locationSharing.startSharingLocation(duration: selectedDuration * 60)
                        isPresented = false
                    }) {
                        Label("Start Sharing", systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Privacy note
                VStack(spacing: 8) {
                    Label("Your Privacy", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• Location sharing automatically stops after the selected duration\n• You can stop sharing anytime\n• Only mutual followers can see your location")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .navigationTitle("Location Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
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
