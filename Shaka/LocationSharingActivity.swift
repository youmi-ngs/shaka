//
//  LocationSharingActivity.swift
//  Shaka
//
//  Live Activity for location sharing
//

import SwiftUI

#if !targetEnvironment(macCatalyst)
import ActivityKit

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
#endif

// Activity Manager
class LocationActivityManager {
    static let shared = LocationActivityManager()
    
    #if !targetEnvironment(macCatalyst)
    private var currentActivity: Activity<LocationSharingAttributes>?
    #endif
    
    func startActivity(duration: Int, sharedWithCount: Int) async {
        #if !targetEnvironment(macCatalyst)
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
            print("Creating activity with duration: \(duration) seconds, count: \(sharedWithCount)")
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
        #else
        print("Live Activities are not supported on Mac Catalyst")
        #endif
    }
    
    func updateActivity(remainingMinutes: Int, sharedWithCount: Int) async {
        #if !targetEnvironment(macCatalyst)
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
        #endif
    }
    
    // Method to update only the shared count (called when mutual followers change)
    func updateSharedCount(_ count: Int) async {
        #if !targetEnvironment(macCatalyst)
        guard let activity = currentActivity else { return }
        
        let elapsed = Date().timeIntervalSince(activity.attributes.startTime)
        let remainingSeconds = max(0, activity.attributes.duration - Int(elapsed))
        let remainingMinutes = (remainingSeconds + 59) / 60
        
        await updateActivity(remainingMinutes: remainingMinutes, sharedWithCount: count)
        #endif
    }
    
    func endActivity() async {
        #if !targetEnvironment(macCatalyst)
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
        #endif
    }
    
    private func startUpdateTimer() {
        #if !targetEnvironment(macCatalyst)
        Task {
            guard let activity = currentActivity else { return }
            
            // Store initial shared count
            let initialSharedCount = activity.content.state.sharedWithCount
            
            while activity.activityState == .active {
                // Update every minute
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                
                let elapsed = Date().timeIntervalSince(activity.attributes.startTime)
                let remainingSeconds = max(0, activity.attributes.duration - Int(elapsed))
                
                if remainingSeconds > 0 {
                    let remainingMinutes = (remainingSeconds + 59) / 60
                    await updateActivity(
                        remainingMinutes: remainingMinutes,
                        sharedWithCount: initialSharedCount
                    )
                } else {
                    await endActivity()
                    break
                }
            }
        }
        #endif
    }
}