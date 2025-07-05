import SwiftUI

struct NetworkStatusBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            Text("⚠️ Offline Mode: Changes will sync when you're online.")
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.orange)
                .foregroundColor(.white)
                .font(.caption)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

