import SwiftUI
import LockedCameraCapture

@main
struct QuickWheelApp: App {
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
            .onContinueUserActivity(NSUserActivityTypeLockedCameraCapture) { _ in
                // Locked camera extension must authenticate before switching to the containing app.
            }
        }
    }
}
