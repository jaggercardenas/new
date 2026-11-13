# QuickWheel: Camera Control Launcher Lab

QuickWheel is a real iOS camera application with a configurable shortcut wheel, a dedicated
LockedCameraCapture extension, a live AVFoundation capture pipeline, and an on-device Camera Control lab.

## Feature implementation
- **Main launcher:** circular wheel, swipe and touch rotation, configurable 1–10 apps or URL schemes, Apple Shortcuts URL launching, website fallback, and tap-to-launch.
- **Camera Lab:** real camera video preview and photo capture. `AVCaptureIndexPicker` exposes "QuickWheel Slots" to Camera Control where iOS supports it. `AVCaptureSystemZoomSlider` offers actual camera zoom. A per-session delegate records active overlays and callback counts. SwiftUI `onCameraCaptureEvent` receives physical capture presses when an active session is running.
- **Experimental camera press launch:** disabled by default. When enabled in the unlocked Camera Lab, uses a capture event to request opening the currently selected shortcut. Whether the OS permits this should be tested on the specific device and OS. Camera shutter still has its own UI button.
- **LockedCameraCapture extension:** separate ExtensionKit process with a real live camera; capture events take photographs. Does not attempt to launch third-party apps while locked. Saves capture files only to the extension-provided session directory. Supports requesting the containing app after unlocking.
- **Diagnostics:** camera permission and active session capability, native controls count, selection callbacks, capture event counts, and startup errors.

## What iOS does NOT support
- Arbitrary **global floating interactive overlays** on top of whatever app was previously open.
- An unlocked background app receiving all Camera Control swipes without running its own live camera.
- Directly opening arbitrary apps or querying the installed app list without public URL schemes/Shortcuts.
- Using LockedCameraCapture as an arbitrary launch-button extension while device is locked. The extension must remain camera-focused, cannot access app data or networking, and must use capture events.

## Build and sideload
GitHub Actions > **Build QuickWheel IPA** creates unsigned `QuickWheel-unsigned.ipa`.
The workflow verifies that the embedded `QuickWheelCameraExtension.appex` exists and identifies
`com.apple.securecapture`. Sign **both the parent app and its nested extension** using a
signer capable of embedded ExtensionKit appex signing. The signing service must preserve the
extension binary, extension metadata, and applicable provisioning requirements.

Install on the same iPhone as the existing QuickWheel; the app's bundle ID remains
`com.quickwheel.launcher`. Existing preferences may be preserved depending on the signer.

## Device test matrix (iOS 18+, tested compilation only; iOS 27 runtime unverified)
1. Install and open QuickWheel > Launcher. Verify apps open from known URLs, or create an Apple Shortcut
   named `Open ChatGPT` with the **Open App** action and set a link of
   `shortcuts://run-shortcut?name=Open%20ChatGPT`.
2. Open Camera Lab, grant camera access, verify "Camera running" and live preview.
3. Tap Capture and grant add-only Photos permission; verify an image appears in Photos.
4. Light-press Camera Control to reveal the native controls. Slide through "QuickWheel Slots" and
   watch the callback count and selection move. Compare with the visible on-screen wheel.
5. Full-press Camera Control; verify camera capture and count. If the experimental switch is
   enabled while **unlocked**, verify whether the selected shortcut launches.
6. Under Settings > Camera > Camera Control, check whether QuickWheel registers as a camera experience.
   If absent, check that the signer installed the bundled extension and the OS recognizes it.
7. Lock iPhone and try QuickWheel as a launch camera. Verify actual camera preview, shutter capture,
   and app continuation after authentication.
8. If the extension disappears or crashes, inspect device logs; locked capture sessions terminate
   when camera permission or the active capture event interaction is absent.
9. Neither the prior app nor an interactive global translucent overlay should be expected.

Apple references:
- https://developer.apple.com/documentation/avfoundation/enhancing-your-app-experience-with-the-camera-control
- https://developer.apple.com/documentation/lockedcameracapture/creating-a-camera-experience-for-the-lock-screen
- https://developer.apple.com/documentation/avfoundation/avcaptureindexpicker

### Privacy
QuickWheel contains no analytics, no backend and no external APIs. The unlocked camera photo
saves to Photos only with permission. The locked extension remains sandboxed and uses session storage.

### Supported and experimental
Compiling the IPA proves the code builds for the iPhone. It does **not** prove the signing
service registers its ExtensionKit extension or that a particular iOS version dispatches every
capture gesture as expected. Those outcomes require real device tests.


Public CI mirror for reproducible unsigned builds; source of truth remains in blank-incase.
