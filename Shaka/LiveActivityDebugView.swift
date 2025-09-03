//
//  LiveActivityDebugView.swift
//  Shaka
//
//  Debug Live Activity Issues
//

import SwiftUI
import ActivityKit
import UserNotifications

struct LiveActivityDebugView: View {
    @State private var debugInfo: String = ""
    @State private var hasNotificationPermission = false
    @State private var hasLiveActivityPermission = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Live Activity Debug")
                    .font(.largeTitle)
                    .bold()
                
                // Permissions Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Permissions")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: hasNotificationPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(hasNotificationPermission ? .green : .red)
                        Text("Notification Permission")
                    }
                    
                    HStack {
                        Image(systemName: hasLiveActivityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(hasLiveActivityPermission ? .green : .red)
                        Text("Live Activities Enabled")
                    }
                    
                    Button("Request Notification Permission") {
                        requestNotificationPermission()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Test Activity Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Test Activity")
                        .font(.headline)
                    
                    Button("Start Simple Activity") {
                        startSimpleActivity()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("List All Activities") {
                        listAllActivities()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("End All Activities") {
                        endAllActivities()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Debug Info
                if !debugInfo.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Debug Info")
                            .font(.headline)
                        
                        Text(debugInfo)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    func checkPermissions() {
        // Check notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasNotificationPermission = settings.authorizationStatus == .authorized
                self.debugInfo += "Notification Status: \(settings.authorizationStatus.rawValue)\n"
            }
        }
        
        // Check Live Activity permission
        self.hasLiveActivityPermission = ActivityAuthorizationInfo().areActivitiesEnabled
        self.debugInfo += "Live Activities Enabled: \(ActivityAuthorizationInfo().areActivitiesEnabled)\n"
        self.debugInfo += "Frequent Updates: \(ActivityAuthorizationInfo().frequentPushesEnabled)\n"
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.hasNotificationPermission = granted
                self.debugInfo += "Permission granted: \(granted)\n"
                if let error = error {
                    self.debugInfo += "Error: \(error)\n"
                }
            }
        }
    }
    
    func startSimpleActivity() {
        Task {
            // End existing activities
            for activity in Activity<LocationSharingAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
            
            let attributes = LocationSharingAttributes(
                startTime: Date(),
                duration: 3600
            )
            
            let state = LocationSharingAttributes.ContentState(
                remainingMinutes: 60,
                sharedWithCount: 1
            )
            
            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(
                        state: state,
                        staleDate: Date().addingTimeInterval(3600)
                    ),
                    pushType: nil
                )
                
                await MainActor.run {
                    self.debugInfo = "Activity Started!\n"
                    self.debugInfo += "ID: \(activity.id)\n"
                    self.debugInfo += "State: \(activity.activityState)\n"
                }
                
            } catch {
                await MainActor.run {
                    self.debugInfo = "Failed: \(error)\n"
                    self.debugInfo += "Error Type: \(type(of: error))\n"
                    self.debugInfo += "Localized: \(error.localizedDescription)\n"
                }
            }
        }
    }
    
    func listAllActivities() {
        debugInfo = "Active Activities:\n"
        for activity in Activity<LocationSharingAttributes>.activities {
            debugInfo += "- ID: \(activity.id)\n"
            debugInfo += "  State: \(activity.activityState)\n"
        }
        if Activity<LocationSharingAttributes>.activities.isEmpty {
            debugInfo += "No active activities\n"
        }
    }
    
    func endAllActivities() {
        Task {
            for activity in Activity<LocationSharingAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
            await MainActor.run {
                self.debugInfo = "All activities ended\n"
            }
        }
    }
}