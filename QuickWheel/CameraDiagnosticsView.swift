import SwiftUI
import AVFoundation

// On-device feasibility diagnostics. This does NOT register the app as a Camera Control target.
struct CameraDiagnosticsView: View {
    @State private var permission = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var deviceAvailable = AVCaptureDevice.default(for: .video) != nil
    @State private var requested = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Hardware") {
                    LabeledContent("Camera present", value: deviceAvailable ? "Yes" : "No")
                    LabeledContent("Camera authorization", value: cameraPermissionLabel)
                    Button("Request camera access") {
                        requested = true
                        AVCaptureDevice.requestAccess(for: .video) { _ in
                            DispatchQueue.main.async {
                                permission = AVCaptureDevice.authorizationStatus(for: .video)
                            }
                        }
                    }
                }
                Section("Camera Control test matrix") {
                    diagnostic("App opens normally", "Use the Launcher tab")
                    diagnostic("Camera permission", "Request access above")
                    diagnostic("Camera Control launches app", "Not implemented: requires eligible camera capture extension")
                    diagnostic("Button surface rotates wheel", "Not implemented: public APIs do not grant arbitrary global gestures")
                    diagnostic("System-wide overlay", "Not available to a normal third-party iOS app")
                    diagnostic("Open another app", "Test an installed app URL from Launcher")
                }
                Section("What this proves") {
                    Text("These checks identify the supported device capabilities and explicitly distinguish them from unimplemented or restricted OS features. An unsigned IPA does not bypass iOS permissions.")
                }
            }
            .navigationTitle("Diagnostics")
        }
    }
    private var cameraPermissionLabel: String {
        switch permission {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }
    private func diagnostic(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}
