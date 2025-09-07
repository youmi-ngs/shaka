//
//  LocationActivityView.swift
//  Shaka
//
//  Live Activity Views in Main App
//

import SwiftUI
#if !targetEnvironment(macCatalyst)
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
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(context.state.sharedWithCount) people")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(context.state.remainingMinutes) min left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Stop button
                Button {
                    // This doesn't actually stop it, just a visual
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.green)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text("Sharing Location")
                            .font(.headline)
                        Text("\(context.state.sharedWithCount) people • \(context.state.remainingMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Button {
                        // Stop action
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
            } compactTrailing: {
                Text("\(context.state.remainingMinutes)m")
                    .font(.caption)
                    .foregroundColor(.green)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
            }
        }
    }
}
#endif

// Preview for debugging
struct LocationActivityView_Previews: PreviewProvider {
    static var previews: some View {
        #if !targetEnvironment(macCatalyst)
        Text("Live Activity Preview")
        #else
        Text("Live Activities not supported on Mac")
        #endif
    }
}