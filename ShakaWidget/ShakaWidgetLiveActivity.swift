//
//  ShakaWidgetLiveActivity.swift
//  ShakaWidget
//
//  Created by Youmi Nagase on 2025/09/04.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ShakaWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ShakaWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShakaWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ShakaWidgetAttributes {
    fileprivate static var preview: ShakaWidgetAttributes {
        ShakaWidgetAttributes(name: "World")
    }
}

extension ShakaWidgetAttributes.ContentState {
    fileprivate static var smiley: ShakaWidgetAttributes.ContentState {
        ShakaWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ShakaWidgetAttributes.ContentState {
         ShakaWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ShakaWidgetAttributes.preview) {
   ShakaWidgetLiveActivity()
} contentStates: {
    ShakaWidgetAttributes.ContentState.smiley
    ShakaWidgetAttributes.ContentState.starEyes
}
