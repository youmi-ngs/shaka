//
//  ShakaWidget.swift
//  ShakaWidget
//
//  Live Activity for Location Sharing
//

import WidgetKit
import SwiftUI
import ActivityKit

// Shared definition with main app via App Groups
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

@main
struct ShakaWidgetBundle: WidgetBundle {
    var body: some Widget {
        LocationActivityWidget()
    }
}

struct LocationActivityWidget: Widget {
    let kind: String = "LocationActivity"
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationSharingAttributes.self) { context in
            // Lock screen UI
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading) {
                    Text("Sharing Location")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(context.state.remainingMinutes) min • \(context.state.sharedWithCount) people")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .activitySystemActionForegroundColor(.primary)
            .activityBackgroundTint(Color(UIColor.systemBackground))
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("Sharing with \(context.state.sharedWithCount) people")
                        Text("• \(context.state.remainingMinutes) min left")
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
            } compactTrailing: {
                Text("\(context.state.remainingMinutes)m")
                    .foregroundColor(.green)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
            }
        }
    }
}