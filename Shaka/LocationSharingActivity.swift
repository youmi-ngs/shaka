//
//  LocationSharingActivity.swift
//  Shaka
//
//  Live Activity for location sharing
//

import ActivityKit
import SwiftUI

// Live Activity Attributes (must match exactly with Widget Extension)
public struct LocationSharingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var remainingMinutes: Int
        public var sharedWithCount: Int
        
        public init(remainingMinutes: Int, sharedWithCount: Int) {
            self.remainingMinutes = remainingMinutes
            self.sharedWithCount = sharedWithCount
        }
    }
    
    public let startTime: Date
    public let duration: Int
    
    public init(startTime: Date, duration: Int) {
        self.startTime = startTime
        self.duration = duration
    }
}


// Activity Manager
class LocationActivityManager {
    static let shared = LocationActivityManager()
    private var currentActivity: Activity<LocationSharingAttributes>?
    
    func startActivity(duration: Int, sharedWithCount: Int) async {
        print("Starting Live Activity...")
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { 
            print("Live Activities are not enabled")
            return 
        }
        
        let attributes = LocationSharingAttributes(
            startTime: Date(),
            duration: duration
        )
        
        let contentState = LocationSharingAttributes.ContentState(
            remainingMinutes: duration / 60,
            sharedWithCount: sharedWithCount
        )
        
        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(TimeInterval(duration))
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            print("Live Activity started successfully")
            print("Activity ID: \(currentActivity?.id ?? "nil")")
            if let state = currentActivity?.activityState {
                print("Activity State: \(state)")
            }
            
            // Check all current activities
            Task {
                for activity in Activity<LocationSharingAttributes>.activities {
                    print("Found activity: \(activity.id) - State: \(activity.activityState)")
                }
            }
            
            // Start timer to update the activity
            startUpdateTimer()
        } catch {
            print("Failed to start Live Activity: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    func updateActivity(remainingMinutes: Int, sharedWithCount: Int) async {
        guard let activity = currentActivity else { return }
        
        let contentState = LocationSharingAttributes.ContentState(
            remainingMinutes: remainingMinutes,
            sharedWithCount: sharedWithCount
        )
        
        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(TimeInterval(remainingMinutes * 60))
        )
        
        await activity.update(activityContent)
    }
    
    // Method to update only the shared count (called when mutual followers change)
    func updateSharedCount(_ count: Int) async {
        guard let activity = currentActivity else { return }
        
        let elapsed = Date().timeIntervalSince(activity.attributes.startTime)
        let remainingSeconds = max(0, activity.attributes.duration - Int(elapsed))
        let remainingMinutes = (remainingSeconds + 59) / 60
        
        await updateActivity(remainingMinutes: remainingMinutes, sharedWithCount: count)
    }
    
    func endActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalContent = LocationSharingAttributes.ContentState(
            remainingMinutes: 0,
            sharedWithCount: 0
        )
        
        await activity.end(
            ActivityContent(state: finalContent, staleDate: .now),
            dismissalPolicy: .immediate
        )
        currentActivity = nil
    }
    
    private func startUpdateTimer() {
        Task {
            guard let activity = currentActivity else { return }
            
            // Store initial shared count
            let initialSharedCount = activity.content.state.sharedWithCount
            
            while activity.activityState == .active {
                // Update every minute
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                
                let elapsed = Date().timeIntervalSince(activity.attributes.startTime)
                let remainingSeconds = max(0, activity.attributes.duration - Int(elapsed))
                let remainingMinutes = (remainingSeconds + 59) / 60 // Round up
                
                if remainingMinutes > 0 {
                    await updateActivity(
                        remainingMinutes: remainingMinutes,
                        sharedWithCount: initialSharedCount // Keep the original count
                    )
                } else {
                    await endActivity()
                }
            }
        }
    }
}

// Lock Screen View  
struct LocationSharingLockScreenView: View {
    let attributes: LocationSharingAttributes
    let state: LocationSharingAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sharing Location")
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text("\(state.remainingMinutes) min remaining")
                        Text("•")
                        Text("\(state.sharedWithCount) followers")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Stop button
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * progressPercentage(), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding()
    }
    
    private func progressPercentage() -> CGFloat {
        let elapsed = Date().timeIntervalSince(attributes.startTime)
        let total = Double(attributes.duration)
        return min(max(0, 1 - (elapsed / total)), 1)
    }
}