import AppKit
import SwiftUI

struct AccessDeniedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Photos access is required")
                .font(.headline)
            Text("Grant access in System Settings > Privacy & Security > Photos, then relaunch the app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!
                NSWorkspace.shared.open(url)
            }
        }
        .padding(40)
    }
}
