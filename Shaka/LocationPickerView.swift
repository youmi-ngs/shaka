//
//  LocationPickerView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/08/13.
//

import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6814, longitude: 139.7667), // 東京駅
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var tempCoordinate: CLLocationCoordinate2D?
    @State private var tempLocationName = ""
    
    var body: some View {
        ZStack {
            // 地図
            Map(
                coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: tempCoordinate != nil ? [TempPin(coordinate: tempCoordinate!)] : []
            ) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    VStack(spacing: 0) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                            .background(Circle().fill(Color(UIColor.systemBackground)).frame(width: 36, height: 36))
                            .shadow(radius: 2)
                        
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .rotationEffect(.degrees(180))
                            .offset(y: -5)
                    }
                }
            }
            .onTapGesture { _ in
                // 地図の中央位置を使用
                setTemporaryLocation(region.center)
            }
            
            // 中央のピン（選択用）
            Button(action: {
                setTemporaryLocation(region.center)
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                    .background(Circle().fill(Color(UIColor.systemBackground)))
                    .opacity(0.8)
            }
            
            // UI オーバーレイ
            VStack {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search for a place...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            searchLocation()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground).opacity(0.95))
                .cornerRadius(10)
                .padding()
                
                Spacer()
                
                // 位置情報表示と確定ボタン
                VStack(spacing: 12) {
                    if !tempLocationName.isEmpty {
                        Text(tempLocationName)
                            .font(.subheadline)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.systemBackground).opacity(0.95))
                            .cornerRadius(8)
                    }
                    
                    HStack(spacing: 16) {
                        // 確定ボタン
                        Button(action: {
                            confirmLocation()
                        }) {
                            Text("Set This Location")
                                .fontWeight(.semibold)
                                .foregroundColor(Color.primary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(25)
                                .shadow(radius: 3)
                        }
                        .disabled(false) // Always enable button since we can use region.center
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Select Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // locationManager.requestLocationPermission() // 位置情報許可を求めない
            
            // 既に選択されている場所がある場合は表示
            if let coord = selectedCoordinate {
                region.center = coord
                tempCoordinate = coord
                tempLocationName = locationName
            } else {
                // 初期状態では地図の中央位置を一時位置として設定
                setTemporaryLocation(region.center)
            }
        }
    }
    
    private func setTemporaryLocation(_ coordinate: CLLocationCoordinate2D) {
        tempCoordinate = coordinate
        
        // 逆ジオコーディング（座標から地名を取得）
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
                        if let country = placemark.country {
                            components.append(country)
                        }
                    }
                    
                    tempLocationName = components.isEmpty ? 
                        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude) :
                        components.joined(separator: ", ")
                } else {
                    tempLocationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                }
            }
        }
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        
        // MKLocalSearchを使用してより正確な検索
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // 日本周辺の検索領域を設定
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6814, longitude: 139.7667),
            latitudinalMeters: 1000000,
            longitudinalMeters: 1000000
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                // フォールバック：CLGeocoderを使用
                fallbackGeocodeSearch()
                return
            }
            
            guard let response = response, !response.mapItems.isEmpty else {
                fallbackGeocodeSearch()
                return
            }
            
            // 最初の結果を使用（MKLocalSearchは関連性順に結果を返す）
            let mapItem = response.mapItems[0]
            let coordinate = mapItem.placemark.coordinate
            
            DispatchQueue.main.async {
                withAnimation {
                    region.center = coordinate
                    setTemporaryLocation(coordinate)
                }
            }
        }
    }
    
    private func fallbackGeocodeSearch() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            if let location = placemarks?.first?.location {
                DispatchQueue.main.async {
                    withAnimation {
                        region.center = location.coordinate
                        setTemporaryLocation(location.coordinate)
                    }
                }
            }
        }
    }
    
    private func confirmLocation() {
        let finalCoordinate = tempCoordinate ?? region.center
        let finalLocationName = tempLocationName.isEmpty ? 
            (searchText.isEmpty ? "Selected Location" : searchText) : tempLocationName
        
        selectedCoordinate = finalCoordinate
        locationName = finalLocationName
        
        dismiss()
    }
}

// 一時的なピン
struct TempPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    NavigationView {
        LocationPickerView(
            selectedCoordinate: .constant(nil),
            locationName: .constant("")
        )
    }
}
