import SwiftUI

struct NetworkStatusBanner: View {
    let isOnline: Bool

    var body: some View {
        Text(isOnline ? "Online" : "Offline")
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(isOnline ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(isOnline ? .green : .red)
            .font(.caption)
            .accessibilityLabel(isOnline ? "Online status" : "Offline status")
    }
}

