import WidgetKit
import SwiftUI

/// Public camera control used in Control Center, the Lock Screen and by the system.
/// The same CameraCaptureIntent is compiled into this extension, the unlocked app,
/// and the LockedCameraCapture extension.
struct QuickWheelCameraControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.quickwheel.launcher.capturecontrol") {
            ControlWidgetButton(action: QuickWheelCaptureIntent()) {
                Label("QuickWheel Camera", systemImage: "camera")
            }
        }
        .displayName("QuickWheel Camera")
        .description("Open QuickWheel's live camera experience.")
    }
}

@main
struct QuickWheelControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickWheelCameraControl()
    }
}
