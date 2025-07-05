//
//  WaveformBar.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//

import SwiftUI

struct WaveformBar: View {
    var level: Float  // Expected 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                Rectangle()
                    .fill(Color.green)
                    .frame(width: CGFloat(level) * geometry.size.width)
                    .animation(.linear(duration: 0.1), value: level)
            }
            .cornerRadius(4)
        }
        .frame(height: 10)
    }
}
