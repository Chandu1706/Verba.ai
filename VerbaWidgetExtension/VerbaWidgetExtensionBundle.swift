//
//  VerbaWidgetExtensionBundle.swift
//  VerbaWidgetExtension
//
//  Created by Chandu Korubilli on 7/5/25.
//

import WidgetKit
import SwiftUI

@main
struct VerbaWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        VerbaWidgetExtension()
        VerbaWidgetExtensionControl()
        VerbaWidgetExtensionLiveActivity()
    }
}
