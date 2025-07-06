//
//  VerbaWidgetExtensionLiveActivity.swift
//  VerbaWidgetExtension
//
//  Created by Chandu Korubilli on 7/5/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct VerbaWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct VerbaWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VerbaWidgetExtensionAttributes.self) { context in
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

extension VerbaWidgetExtensionAttributes {
    fileprivate static var preview: VerbaWidgetExtensionAttributes {
        VerbaWidgetExtensionAttributes(name: "World")
    }
}

extension VerbaWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: VerbaWidgetExtensionAttributes.ContentState {
        VerbaWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: VerbaWidgetExtensionAttributes.ContentState {
         VerbaWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: VerbaWidgetExtensionAttributes.preview) {
   VerbaWidgetExtensionLiveActivity()
} contentStates: {
    VerbaWidgetExtensionAttributes.ContentState.smiley
    VerbaWidgetExtensionAttributes.ContentState.starEyes
}
