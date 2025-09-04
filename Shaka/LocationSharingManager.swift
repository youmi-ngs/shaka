//
//  LocationSharingManager.swift
//  Shaka
//
//  Created by Assistant on 2025/09/01.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import Combine

class LocationSharingManager: NSObject, ObservableObject {
    static let shared = LocationSharingManager()
    
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    
    @Published var isSharing = false
    @Published var currentLocation: CLLocation?
    @Published var sharingExpiresAt: Date?
    @Published var mutualFollowersLocations: [UserLocation] = []
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var locationUpdateTimer: Timer?
    private var expirationTimer: Timer?
    private var locationListener: ListenerRegistration?
    
    struct UserLocation: Identifiable {
        let id: String // userId
        let displayName: String
        let photoURL: String?
        let location: CLLocationCoordinate2D
        let updatedAt: Date
        let expiresAt: Date
    }
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update every 100 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Permission Handling
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Location Sharing
    
    func startSharingLocation(duration: TimeInterval = 3600) { // Default 1 hour
        guard let uid = Auth.auth().currentUser?.uid,
              let location = currentLocation else {
            print("Cannot share location: No user or location")
            return
        }
        
        let expiresAt = Date().addingTimeInterval(duration)
        
        // First fetch user's display name from Firestore
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            let displayName = snapshot?.data()?["public"] as? [String: Any]
            let userName = displayName?["displayName"] as? String ?? "Unknown"
            let photoURL = displayName?["photoURL"] as? String ?? ""
            
            // Save to Firestore with correct display name
            let locationData: [String: Any] = [
                "location": GeoPoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ),
                "updatedAt": FieldValue.serverTimestamp(),
                "expiresAt": Timestamp(date: expiresAt),
                "displayName": userName,
                "photoURL": photoURL
            ]
            
            self?.db.collection("user_locations").document(uid).setData(locationData) { [weak self] error in
                if let error = error {
                    print("Error sharing location: \(error)")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.isSharing = true
                    self?.sharingExpiresAt = expiresAt
                    self?.startLocationUpdates()
                    self?.setupExpirationTimer(expiresAt: expiresAt)
                    
                    // Start Live Activity
                    Task { @MainActor in
                        // 相互フォロワー数を取得してからLive Activityを開始
                        self?.fetchMutualFollowers { mutualFollowers in
                            Task {
                                await LocationActivityManager.shared.startActivity(
                                    duration: Int(duration),
                                    sharedWithCount: mutualFollowers.count
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    func stopSharingLocation() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Delete from Firestore
        db.collection("user_locations").document(uid).delete { [weak self] error in
            if let error = error {
                print("Error stopping location share: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.isSharing = false
                self?.sharingExpiresAt = nil
                self?.stopLocationUpdates()
                self?.expirationTimer?.invalidate()
                self?.expirationTimer = nil
                
                // End Live Activity
                Task {
                    await LocationActivityManager.shared.endActivity()
                }
            }
        }
    }
    
    // MARK: - Location Updates
    
    private func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        
        // Update location every 30 seconds
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateLocationInFirestore()
        }
    }
    
    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    private func updateLocationInFirestore() {
        guard let uid = Auth.auth().currentUser?.uid,
              let location = currentLocation,
              isSharing else { return }
        
        db.collection("user_locations").document(uid).updateData([
            "location": GeoPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Fetch Mutual Followers Locations
    
    func startListeningToMutualLocations() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // First, get mutual followers
        fetchMutualFollowers { [weak self] mutualFollowers in
            guard !mutualFollowers.isEmpty else {
                self?.mutualFollowersLocations = []
                return
            }
            
            // Listen to their locations
            print("Listening for locations of mutual followers: \(mutualFollowers)")
            self?.locationListener = self?.db.collection("user_locations")
                .whereField(FieldPath.documentID(), in: mutualFollowers)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error fetching locations: \(error)")
                        return
                    }
                    
                    print("Found \(snapshot?.documents.count ?? 0) location documents")
                    let locations = snapshot?.documents.compactMap { doc -> UserLocation? in
                        let data = doc.data()
                        guard let geoPoint = data["location"] as? GeoPoint,
                              let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(),
                              expiresAt > Date() else { return nil }
                        
                        return UserLocation(
                            id: doc.documentID,
                            displayName: data["displayName"] as? String ?? "Unknown",
                            photoURL: data["photoURL"] as? String,
                            location: CLLocationCoordinate2D(
                                latitude: geoPoint.latitude,
                                longitude: geoPoint.longitude
                            ),
                            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                            expiresAt: expiresAt
                        )
                    } ?? []
                    
                    DispatchQueue.main.async {
                        self?.mutualFollowersLocations = locations
                    }
                }
        }
    }
    
    func stopListeningToMutualLocations() {
        locationListener?.remove()
        locationListener = nil
        mutualFollowersLocations = []
    }
    
    private func fetchMutualFollowers(completion: @escaping ([String]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        let group = DispatchGroup()
        var following: Set<String> = []
        var followers: Set<String> = []
        
        // Fetch following - 正しいパス: following/{uid}/users
        group.enter()
        db.collection("following").document(uid).collection("users").getDocuments { snapshot, _ in
            following = Set(snapshot?.documents.map { $0.documentID } ?? [])
            print("Following users: \(following)")
            group.leave()
        }
        
        // Fetch followers - 正しいパス: followers/{uid}/users  
        group.enter()
        db.collection("followers").document(uid).collection("users").getDocuments { snapshot, _ in
            followers = Set(snapshot?.documents.map { $0.documentID } ?? [])
            print("Follower users: \(followers)")
            group.leave()
        }
        
        group.notify(queue: .main) {
            let mutualFollowers = Array(following.intersection(followers))
            print("Mutual followers: \(mutualFollowers)")
            completion(mutualFollowers)
        }
    }
    
    // MARK: - Expiration Timer
    
    private func setupExpirationTimer(expiresAt: Date) {
        expirationTimer?.invalidate()
        
        let timeInterval = expiresAt.timeIntervalSinceNow
        if timeInterval > 0 {
            expirationTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.stopSharingLocation()
            }
        }
    }
    
    // MARK: - Check Sharing Status
    
    func checkSharingStatus() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("user_locations").document(uid).getDocument { [weak self] snapshot, error in
            if let data = snapshot?.data(),
               let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(),
               expiresAt > Date() {
                DispatchQueue.main.async {
                    self?.isSharing = true
                    self?.sharingExpiresAt = expiresAt
                    self?.startLocationUpdates()
                    self?.setupExpirationTimer(expiresAt: expiresAt)
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationSharingManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Update Firestore if sharing
        if isSharing {
            updateLocationInFirestore()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            stopSharingLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
}