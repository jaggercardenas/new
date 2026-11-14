import SwiftUI

// Dedicated LiveContainer testing entry point.
// No LockedCameraCapture import, no ExtensionKit dependencies.
@main
struct QuickWheelLiveContainerApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                WheelView()
                    .tabItem { Label("Launcher", systemImage: "circle.grid.2x2.fill") }
                CameraLabView()
                    .tabItem { Label("Camera Lab", systemImage: "camera.fill") }
                CameraDiagnosticsView()
                    .tabItem { Label("Diagnostics", systemImage: "checkmark.shield") }
            }
            .overlay(alignment: .top) {
                Text("LIVE CONTAINER TEST")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.5), in: Capsule())
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }
        }
    }
}
