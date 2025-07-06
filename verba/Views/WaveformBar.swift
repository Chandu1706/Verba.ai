//
//  WaveformBar.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//
import SwiftUI

struct WaveformBar: View {
    let level: Float
    private let barCount = 40

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.green.opacity(Double(index) / Double(barCount)))
                    .frame(height: barHeight(for: index))
            }
        }
        .animation(.easeInOut(duration: 0.1), value: level)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalized = CGFloat(level)
        let center = CGFloat(barCount) / 2
        let distance = abs(center - CGFloat(index))
        return max(4, 40 * normalized - distance)
    }
}

