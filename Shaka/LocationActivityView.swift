//
//  LocationActivityView.swift
//  Shaka
//
//  Live Activity Views in Main App
//

import SwiftUI
import ActivityKit
import WidgetKit

// Widget Configuration in Main App
struct LocationSharingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationSharingAttributes.self) { context in
            // Lock screen view
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sharing Location")
                        .font(.subheadline.weight(.semibold))
                    
                    HStack(spacing: 8) {
                        Label("\(context.state.remainingMinutes)m left", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if context.state.sharedWithCount > 0 {
                            Label("\(context.state.sharedWithCount)", systemImage: "person.2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Stop button
                Link(destination: URL(string: "shaka://stoplocation")!) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.green.opacity(0.1))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text("Sharing Location")
                        .font(.caption)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.remainingMinutes)m")
                        .font(.caption2)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.sharedWithCount) followers can see you")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
            } compactTrailing: {
                Text("\(context.state.remainingMinutes)")
                    .font(.caption2)
                    .foregroundColor(.green)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

// Register in main app
struct ActivityRegistry {
    static func register() {
        // This ensures the activity configuration is registered
        _ = LocationSharingLiveActivity()
    }
}