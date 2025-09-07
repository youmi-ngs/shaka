//
//  TestLiveActivity.swift
//  Shaka
//
//  Test Live Activity
//

import SwiftUI
#if !targetEnvironment(macCatalyst)
import ActivityKit
#endif

struct TestLiveActivityView: View {
    @State private var activityID: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Live Activity Test")
                .font(.title)
            
            #if !targetEnvironment(macCatalyst)
            Button("Start Test Activity") {
                startTestActivity()
            }
            .buttonStyle(.borderedProminent)
            
            if let id = activityID {
                Text("Activity ID: \(id)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Button("Stop All Activities") {
                stopAllActivities()
            }
            .buttonStyle(.bordered)
            #else
            Text("Live Activities are not supported on Mac")
                .foregroundColor(.secondary)
            #endif
        }
        .padding()
    }
    
    #if !targetEnvironment(macCatalyst)
    func startTestActivity() {
        Task {
            // まず全てのActivityを終了
            for activity in Activity<LocationSharingAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
            
            let attributes = LocationSharingAttributes(
                startTime: Date(),
                duration: 3600
            )
            
            let state = LocationSharingAttributes.ContentState(
                remainingMinutes: 60,
                sharedWithCount: 3
            )
            
            let content = ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(3600)
            )
            
            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                
                DispatchQueue.main.async {
                    self.activityID = activity.id
                }
                
                print("Test Activity started: \(activity.id)")
            } catch {
                print("Failed to start test activity: \(error)")
            }
        }
    }
    
    func stopAllActivities() {
        Task {
            for activity in Activity<LocationSharingAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
            
            DispatchQueue.main.async {
                self.activityID = nil
            }
        }
    }
    #else
    func startTestActivity() {}
    func stopAllActivities() {}
    #endif
}

#Preview {
    TestLiveActivityView()
}