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
    @State private var tempLocationName = ""
    
    var body: some View {
        ZStack {
            // 地図（ピンなしで表示）
            Map(
                coordinateRegion: $region,
                showsUserLocation: true
            )
            .onChange(of: region.center.latitude) { _ in
                updateLocationName(for: region.center)
            }
            .onChange(of: region.center.longitude) { _ in
                updateLocationName(for: region.center)
            }
            
            // 中央に固定されたピン（地図をドラッグして位置を調整）
            VStack(spacing: 0) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.indigo)
                    .background(Circle().fill(Color.white).frame(width: 40, height: 40))
                
                Image(systemName: "triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.indigo)
                    .rotationEffect(.degrees(180))
                    .offset(y: -5)
            }
            .allowsHitTesting(false) // タップを透過させる
            
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
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text(tempLocationName)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemBackground).opacity(0.95))
                        .cornerRadius(8)
                    }
                    
                    // 確定ボタン
                    Button(action: {
                        confirmLocation()
                    }) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Set Location")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(radius: 3)
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
            // 既に選択されている場所がある場合は表示
            if let coord = selectedCoordinate {
                region.center = coord
                tempLocationName = locationName
            } else {
                // 初期状態の地名を取得
                updateLocationName(for: region.center)
            }
        }
    }
    
    private func updateLocationName(for coordinate: CLLocationCoordinate2D) {
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
                    
                    self.tempLocationName = components.isEmpty ? 
                        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude) :
                        components.joined(separator: ", ")
                } else {
                    self.tempLocationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
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
                    self.region.center = coordinate
                    self.updateLocationName(for: coordinate)
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
                        self.region.center = location.coordinate
                        self.updateLocationName(for: location.coordinate)
                    }
                }
            }
        }
    }
    
    private func confirmLocation() {
        // 地図の中央位置を確定位置として使用
        let centerCoord = region.center
        selectedCoordinate = centerCoord
        
        // 地名を設定
        if tempLocationName.isEmpty {
            locationName = searchText.isEmpty ? 
                String(format: "%.4f, %.4f", centerCoord.latitude, centerCoord.longitude) : 
                searchText
        } else {
            locationName = tempLocationName
        }
        
        dismiss()
    }
}

#Preview {
    NavigationView {
        LocationPickerView(
            selectedCoordinate: .constant(nil),
            locationName: .constant("")
        )
    }
}
