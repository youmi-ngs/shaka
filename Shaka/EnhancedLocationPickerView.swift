//
//  EnhancedLocationPickerView.swift
//  Shaka
//
//  Created by Assistant on 2025/09/03.
//

import SwiftUI
import MapKit
import CoreLocation

struct EnhancedLocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchCompleter = LocationSearchCompleter()
    
    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var tempLocationName: String
    @State private var showingCustomNameAlert = false
    @State private var customLocationName: String
    @State private var isFromMapDrag = false
    
    init(selectedCoordinate: Binding<CLLocationCoordinate2D?>, locationName: Binding<String>) {
        self._selectedCoordinate = selectedCoordinate
        self._locationName = locationName
        
        
        let initialCenter = selectedCoordinate.wrappedValue ?? CLLocationCoordinate2D(latitude: 35.6814, longitude: 139.7667)
        self._region = State(initialValue: MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
        self._tempLocationName = State(initialValue: locationName.wrappedValue)
        self._customLocationName = State(initialValue: "")
    }
    
    var body: some View {
        ZStack {
            // 地図
            Map(coordinateRegion: $region, showsUserLocation: true)
                .onChange(of: region.center.latitude) { _ in
                    if !showingSearch {
                        updateLocationName(for: region.center)
                    }
                }
                .onChange(of: region.center.longitude) { _ in
                    if !showingSearch {
                        updateLocationName(for: region.center)
                    }
                }
            
            // 中央に固定されたピン
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
            .allowsHitTesting(false)
            
            // UI オーバーレイ
            VStack {
                // 検索バーと予測候補
                VStack(spacing: 0) {
                    // 検索バー
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search for a place...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: searchText) { newValue in
                                searchCompleter.searchQuery = newValue
                                showingSearch = !newValue.isEmpty
                            }
                            .onSubmit {
                                if let firstResult = searchCompleter.searchResults.first {
                                    selectSearchResult(firstResult)
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { 
                                searchText = ""
                                showingSearch = false
                                searchCompleter.searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10, corners: showingSearch ? [.topLeft, .topRight] : .allCorners)
                    
                    // 検索候補
                    if showingSearch && !searchCompleter.searchResults.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(searchCompleter.searchResults, id: \.self) { result in
                                    Button(action: {
                                        selectSearchResult(result)
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.title)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if result != searchCompleter.searchResults.last {
                                        Divider()
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Spacer()
                
                // 位置情報表示とアクションボタン
                VStack(spacing: 12) {
                    if !tempLocationName.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                    Text(customLocationName.isEmpty ? tempLocationName : customLocationName)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                }
                                
                                if !customLocationName.isEmpty && customLocationName != tempLocationName {
                                    Text("Original: \(tempLocationName)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // カスタム名前編集ボタン
                            Button(action: {
                                showingCustomNameAlert = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.95))
                        .cornerRadius(12)
                    }
                    
                    // 確定ボタン
                    Button(action: {
                        confirmLocation()
                    }) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Set This Location")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
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
        .alert("Custom Location Name", isPresented: $showingCustomNameAlert) {
            TextField("Enter custom name", text: $customLocationName)
            Button("Set") {
                // カスタム名が設定される
            }
            Button("Cancel", role: .cancel) {
                customLocationName = ""
            }
        } message: {
            Text("Enter a custom name for this location")
        }
        .onAppear {
            // Request location permission if needed
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestLocationPermission()
            }
            
            // Update location name if we don't have one
            if tempLocationName.isEmpty && selectedCoordinate == nil {
                updateLocationName(for: region.center)
            }
        }
    }
    
    private func moveToCurrentLocation() {
        locationManager.requestLocationPermission()
        if let location = locationManager.userLocation {
            withAnimation {
                region.center = location.coordinate
                updateLocationName(for: location.coordinate)
            }
        }
    }
    
    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        searchText = result.title
        showingSearch = false
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            
            DispatchQueue.main.async {
                withAnimation {
                    self.region.center = coordinate
                    self.tempLocationName = result.title
                    if !result.subtitle.isEmpty {
                        self.tempLocationName += ", " + result.subtitle
                    }
                    self.searchCompleter.searchResults = []
                }
            }
        }
    }
    
    private func updateLocationName(for coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    var components: [String] = []
                    
                    // より詳細な地名取得
                    if let name = placemark.name {
                        components.append(name)
                    }
                    if let locality = placemark.locality, !components.contains(locality) {
                        components.append(locality)
                    }
                    if let administrativeArea = placemark.administrativeArea, !components.contains(administrativeArea) {
                        components.append(administrativeArea)
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
    
    private func confirmLocation() {
        selectedCoordinate = region.center
        locationName = customLocationName.isEmpty ? tempLocationName : customLocationName
        dismiss()
    }
}

// MARK: - Location Search Completer
class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    var searchQuery = "" {
        didSet {
            completer.queryFragment = searchQuery
        }
    }
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        // 日本優先の検索設定
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6814, longitude: 139.7667),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error)")
    }
}


#Preview {
    NavigationView {
        EnhancedLocationPickerView(
            selectedCoordinate: .constant(nil),
            locationName: .constant("")
        )
    }
}