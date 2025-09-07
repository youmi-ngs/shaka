//
//  LiveActivityDebugView.swift
//  Shaka
//
//  Debug Live Activity Issues
//

import SwiftUI
#if !targetEnvironment(macCatalyst)
import ActivityKit
#endif
import UserNotifications

struct LiveActivityDebugView: View {
    @State private var debugInfo: String = ""
    @State private var hasNotificationPermission = false
    @State private var hasLiveActivityPermission = false
    
    var body: some View {
        #if !targetEnvironment(macCatalyst)
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
                    Text("Test Live Activity")
                        .font(.headline)
                    
                    Button("Start Test Activity (30 min)") {
                        startTestActivity(duration: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Update Activity") {
                        updateTestActivity()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("End Activity") {
                        endTestActivity()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Debug Info Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Debug Info")
                        .font(.headline)
                    
                    ScrollView {
                        Text(debugInfo)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(5)
                    
                    Button("Refresh Debug Info") {
                        checkPermissions()
                        listAllActivities()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
        .onAppear {
            checkPermissions()
            listAllActivities()
        }
        #else
        // Mac Catalyst doesn't support Live Activities
        VStack {
            Text("Live Activities Not Supported")
                .font(.largeTitle)
                .bold()
            
            Text("Live Activities are not available on Mac")
                .foregroundColor(.secondary)
        }
        .padding()
        #endif
    }
    
    #if !targetEnvironment(macCatalyst)
    private func checkPermissions() {
        // Check notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                hasNotificationPermission = settings.authorizationStatus == .authorized
                
                // Check Live Activity permission
                hasLiveActivityPermission = ActivityAuthorizationInfo().areActivitiesEnabled
                let frequentPushes = ActivityAuthorizationInfo().frequentPushesEnabled
                
                debugInfo += "Notification Status: \(settings.authorizationStatus.rawValue)\n"
                debugInfo += "Live Activities Enabled: \(hasLiveActivityPermission)\n"
                debugInfo += "Frequent Pushes Enabled: \(frequentPushes)\n"
                debugInfo += "---\n"
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                hasNotificationPermission = granted
                debugInfo += "Notification permission: \(granted ? "Granted" : "Denied")\n"
                if let error = error {
                    debugInfo += "Error: \(error.localizedDescription)\n"
                }
                debugInfo += "---\n"
            }
        }
    }
    
    private func listAllActivities() {
        Task {
            debugInfo += "Current Activities:\n"
            for activity in Activity<LocationSharingAttributes>.activities {
                debugInfo += "ID: \(activity.id)\n"
                debugInfo += "State: \(activity.activityState)\n"
                debugInfo += "Content: \(activity.content.state)\n"
                debugInfo += "---\n"
            }
            
            if Activity<LocationSharingAttributes>.activities.isEmpty {
                debugInfo += "No active Live Activities\n"
                debugInfo += "---\n"
            }
        }
    }
    
    private func startTestActivity(duration: Int) {
        Task {
            debugInfo += "Starting test activity...\n"
            await LocationActivityManager.shared.startActivity(
                duration: duration * 60,
                sharedWithCount: 3
            )
            debugInfo += "Test activity started\n"
            debugInfo += "---\n"
            
            // List activities after starting
            listAllActivities()
        }
    }
    
    private func updateTestActivity() {
        Task {
            debugInfo += "Updating test activity...\n"
            await LocationActivityManager.shared.updateActivity(
                remainingMinutes: 15,
                sharedWithCount: 5
            )
            debugInfo += "Test activity updated\n"
            debugInfo += "---\n"
        }
    }
    
    private func endTestActivity() {
        Task {
            debugInfo += "Ending test activity...\n"
            await LocationActivityManager.shared.endActivity()
            debugInfo += "Test activity ended\n"
            debugInfo += "---\n"
            
            // List activities after ending
            listAllActivities()
        }
    }
    #else
    // Empty implementations for Mac Catalyst
    private func checkPermissions() {}
    private func requestNotificationPermission() {}
    private func listAllActivities() {}
    private func startTestActivity(duration: Int) {}
    private func updateTestActivity() {}
    private func endTestActivity() {}
    #endif
}

#Preview {
    LiveActivityDebugView()
}