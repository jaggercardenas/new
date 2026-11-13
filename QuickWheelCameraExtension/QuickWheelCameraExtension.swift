import Foundation
import SwiftUI
import LockedCameraCapture
import AVKit

/// Dedicated locked-device camera extension. Never accesses other installed apps,
/// network resources, shared preferences, or any App Group container.
@main
struct QuickWheelCameraExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            LockedCameraView(session: session)
                .statusBarHidden(true)
        }
    }
}

struct LockedCameraView: View {
    let session: LockedCameraCaptureSession
    @StateObject private var camera = CameraEngine()
    @State private var result = ""

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .onCameraCaptureEvent { event in
                    if event.phase == .ended {
                        camera.capturePhoto()
                    }
                }
            VStack {
                HStack {
                    Label("QuickWheel Camera", systemImage: "camera.fill")
                    Spacer()
                    Text(camera.running ? "Live" : "Starting")
                }
                .font(.caption.bold()).foregroundStyle(.white)
                .padding(18)
                .background(.black.opacity(0.38))
                Spacer()

                Text(camera.status)
                    .font(.caption).multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                HStack(spacing: 18) {
                    Button("Continue in app") { openContainingApp() }
                        .buttonStyle(.bordered)
                    Button {
                        camera.capturePhoto()
                    } label: {
                        Image(systemName: "circle.inset.filled")
                            .font(.system(size: 62))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Capture photo")
                }
                .foregroundStyle(.white)
                .padding(.bottom, 45)
                Text(result).foregroundStyle(.white).font(.caption2)
            }
        }
        .onAppear {
            // Captured photos are written to the extension's session directory.
            camera.sessionContentURL = session.sessionContentURL
            camera.selectionTitles = ["Normal", "Close-up", "Portrait"]
            camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private func openContainingApp() {
        Task {
            do {
                let activity = NSUserActivity(activityType: NSUserActivityTypeLockedCameraCapture)
                try await session.openApplication(for: activity)
            } catch {
                result = "Unable to open app: \(error.localizedDescription)"
            }
        }
    }
}
