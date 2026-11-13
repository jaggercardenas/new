import SwiftUI
import AVFoundation
import AVKit
import Photos
import UIKit

/// A real live camera pipeline shared by the unlocked app and LockedCameraCapture extension.
/// Never attempts to access the app container from the locked extension.
final class CameraEngine: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureSessionControlsDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.quickwheel.camera.session")
    private var configured = false
    private var cameraDevice: AVCaptureDevice?
    private var activePicker: AVCaptureIndexPicker?

    @Published private(set) var running = false
    @Published private(set) var status = "Not started"
    @Published private(set) var supportsControls = false
    @Published private(set) var controlsCount = 0
    @Published private(set) var selectedIndex = 0
    @Published private(set) var selectionEventCount = 0
    @Published private(set) var captureEventCount = 0
    @Published private(set) var overlayActive = false
    @Published private(set) var errorMessage = ""
    @Published private(set) var savedPhotoCount = 0

    /// Set only for the locked extension, where photos must remain in the session's provided directory.
    var sessionContentURL: URL?
    var selectionTitles: [String] = ["Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5"]

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorized()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.startAuthorized() }
                else { self?.publishStatus("Camera permission denied") }
            }
        case .denied, .restricted:
            publishStatus("Camera unavailable: permission denied or restricted")
        @unknown default:
            publishStatus("Unknown camera permission state")
        }
    }

    private func publishStatus(_ message: String) {
        DispatchQueue.main.async { self.status = message }
    }

    private func startAuthorized() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured { self.configure() }
            guard self.configured else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async {
                self.running = self.session.isRunning
                self.status = self.running ? "Camera running" : "Camera failed to start"
            }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            publishStatus("No camera device found")
            return
        }
        self.cameraDevice = device

        session.beginConfiguration()
        session.sessionPreset = .photo
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                publishStatus("Camera input/output unavailable")
                return
            }
            session.addInput(input)
            session.addOutput(photoOutput)
        } catch {
            session.commitConfiguration()
            publishStatus("Could not configure camera: \(error.localizedDescription)")
            return
        }

        // Genuine Camera Control integration: hardware zoom and index selection.
        // The custom picker is experimental; the system decides whether to present it.
        if session.supportsControls {
            let zoom = AVCaptureSystemZoomSlider(device: device)
            if session.canAddControl(zoom) { session.addControl(zoom) }

            let titles = selectionTitles.isEmpty ? ["Slot 1"] : selectionTitles
            let picker = AVCaptureIndexPicker("QuickWheel Slots", symbolName: "circle.grid.3x3",
                                              localizedIndexTitles: titles)
            picker.setActionQueue(sessionQueue) { [weak self] index in
                DispatchQueue.main.async {
                    self?.selectedIndex = index
                    self?.selectionEventCount += 1
                    self?.status = "Camera Control selected slot \(index + 1)"
                }
            }
            if session.canAddControl(picker) {
                session.addControl(picker)
                activePicker = picker
            }
            session.setControlsDelegate(self, queue: sessionQueue)
        }

        session.commitConfiguration()
        configured = true
        DispatchQueue.main.async {
            self.supportsControls = self.session.supportsControls
            self.controlsCount = self.session.controls.count
            self.status = "Camera configured with \(self.session.controls.count) hardware controls"
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.running = false
                self.status = "Camera stopped"
            }
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.configured && self.session.isRunning else {
                self.publishStatus("Photo capture unavailable: camera is not running")
                return
            }
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            DispatchQueue.main.async { self.captureEventCount += 1 }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { publishStatus("Photo failed: \(error.localizedDescription)"); return }
        guard let data = photo.fileDataRepresentation() else { publishStatus("No photo data"); return }

        if let directory = sessionContentURL {
            let url = directory.appendingPathComponent(UUID().uuidString + ".heic")
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
                DispatchQueue.main.async {
                    self.savedPhotoCount += 1
                    self.status = "Captured to secure session"
                }
            } catch {
                publishStatus("Could not save session image: \(error.localizedDescription)")
            }
        } else {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] authorization in
                guard let self else { return }
                guard authorization == .authorized || authorization == .limited else {
                    self.publishStatus("Photo permission denied — camera remains available")
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, data: data, options: nil)
                } completionHandler: { ok, err in
                    DispatchQueue.main.async {
                        if ok { self.savedPhotoCount += 1 }
                        self.status = ok ? "Saved photo to Photos" : "Photo save failed: \(err?.localizedDescription ?? "unknown")"
                    }
                }
            }
        }
    }

    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {
        DispatchQueue.main.async { self.overlayActive = true }
    }
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {
        DispatchQueue.main.async { self.overlayActive = false }
    }
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {
        DispatchQueue.main.async { self.status = "Camera Control overlay fullscreen" }
    }
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {
        DispatchQueue.main.async { self.status = "Camera Control overlay exited fullscreen" }
    }
}

final class CameraPreviewUIKitView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> CameraPreviewUIKitView {
        let view = CameraPreviewUIKitView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }
    func updateUIView(_ uiView: CameraPreviewUIKitView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}
