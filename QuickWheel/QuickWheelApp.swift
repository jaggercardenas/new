import SwiftUI
import LockedCameraCapture

@main
struct QuickWheelApp: App {
    // The standalone Camera Control build starts in its active camera experience.
    // The user can still switch to Launcher to edit and test shortcut URLs.
    @State private var selectedTab = 1

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                WheelView()
                    .tabItem { Label("Launcher", systemImage: "circle.grid.2x2.fill") }
                    .tag(0)
                CameraLabView()
                    .tabItem { Label("Camera Lab", systemImage: "camera.fill") }
                    .tag(1)
                CameraDiagnosticsView()
                    .tabItem { Label("Diagnostics", systemImage: "checkmark.shield") }
                    .tag(2)
            }
            .onContinueUserActivity(NSUserActivityTypeLockedCameraCapture) { _ in
                // After authentication, enter the real camera viewfinder.
                selectedTab = 1
            }
        }
    }
}
