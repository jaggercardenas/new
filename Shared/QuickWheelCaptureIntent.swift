import AppIntents
import Foundation

/// Advertises QuickWheel's camera experience to the system Camera Control launcher.
/// CameraCaptureIntent is distinct from the LockedCameraCapture extension:
/// the former registers the unlocked Camera Control entry point, while the latter
/// supplies the secure camera view when the phone is locked.
struct QuickWheelCaptureIntent: CameraCaptureIntent {
    static var title: LocalizedStringResource = "QuickWheel Camera"
    static var description = IntentDescription("Open QuickWheel's camera experience and gesture wheel.")

    @MainActor
    func perform() async throws -> some IntentResult {
        // CameraCaptureIntent launches the containing camera app, or its capture
        // extension when appropriate. The app defaults to its Camera Lab tab.
        return .result()
    }
}
