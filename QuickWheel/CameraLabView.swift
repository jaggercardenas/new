import SwiftUI
import AVKit
import UIKit

/// Runs only in the unlocked containing app. An active camera session is required
/// before iOS can present Camera Control controls and deliver capture events.
struct CameraLabView: View {
    @AppStorage("savedShortcuts") private var saved = Data()
    @StateObject private var camera = CameraEngine()
    @State private var shortcuts: [Shortcut] = [
        .init(name: "Shortcuts", symbol: "square.stack.3d.up.fill", url: "shortcuts://"),
        .init(name: "Maps", symbol: "map.fill", url: "maps://"),
        .init(name: "Messages", symbol: "message.fill", url: "sms:"),
        .init(name: "Music", symbol: "music.note", url: "music://"),
        .init(name: "ChatGPT web", symbol: "bubble.left.and.bubble.right", url: "https://chatgpt.com")
    ]
    @State private var selection = 0
    @State private var pressOpensApp = false
    @State private var launchResult = "No launch attempted"
    @State private var showingGuide = false
    @State private var lastDrag: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .onCameraCaptureEvent { event in
                        if event.phase == .ended {
                            if pressOpensApp {
                                // Experimental: system may reserve hardware capture presses.
                                openSelected()
                            } else {
                                camera.capturePhoto()
                            }
                        }
                    }

                LinearGradient(colors: [.black.opacity(0.62), .clear, .black.opacity(0.82)],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Label(camera.running ? "Camera live" : "Camera starting", systemImage: "camera.fill")
                        Spacer()
                        Button { showingGuide = true } label: { Image(systemName: "info.circle") }
                    }.font(.caption.bold())
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    Text(camera.status).font(.caption2).lineLimit(2)
                    Spacer(minLength: 8)

                    let diameter = min(geometry.size.width - 95, 300.0)
                    ZStack {
                        Circle().fill(.ultraThinMaterial).opacity(0.82)
                            .overlay(Circle().stroke(.cyan.opacity(0.7), lineWidth: 2))
                        ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, item in
                            let angle = Double(index - selection) * 2 * Double.pi / Double(shortcuts.count) - Double.pi / 2
                            Button {
                                selection = index
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Image(systemName: item.symbol).font(.title3)
                                    .frame(width: 43, height: 43)
                                    .background(index == selection ? Color.blue : Color.black.opacity(0.6),
                                                in: RoundedRectangle(cornerRadius: 12))
                            }.position(x: diameter / 2 + cos(angle) * diameter * 0.38,
                                       y: diameter / 2 + sin(angle) * diameter * 0.38)
                        }
                        VStack(spacing: 6) {
                            Image(systemName: shortcuts[selection].symbol).font(.title)
                            Text(shortcuts[selection].name).font(.caption.bold()).lineLimit(2)
                                .multilineTextAlignment(.center)
                        }.frame(width: diameter * 0.43, height: diameter * 0.43)
                            .background(.black.opacity(0.8), in: Circle())
                    }
                    .frame(width: diameter, height: diameter)
                    .gesture(
                        DragGesture(minimumDistance: 8).onChanged { value in
                            let difference = value.translation.height - lastDrag
                            if abs(difference) >= 30 {
                                selection = (selection + (difference > 0 ? 1 : -1) + shortcuts.count) % shortcuts.count
                                UISelectionFeedbackGenerator().selectionChanged()
                                lastDrag = value.translation.height
                            }
                        }.onEnded { _ in lastDrag = 0 }
                    )

                    HStack {
                        Button { camera.capturePhoto() } label: {
                            Label("Capture", systemImage: "camera.circle.fill")
                        }.buttonStyle(.bordered)
                        Button { openSelected() } label: {
                            Label("Open " + shortcuts[selection].name, systemImage: "arrow.up.right")
                                .lineLimit(1)
                        }.buttonStyle(.borderedProminent)
                    }.font(.caption)
                    Toggle("Experimental: button press opens selected app", isOn: $pressOpensApp)
                        .font(.caption2)
                        .padding(.horizontal, 20)

                    HStack {
                        Text("Picker callbacks: \(camera.selectionEventCount)")
                        Spacer()
                        Text("Controls: \(camera.controlsCount)")
                        Spacer()
                        Text("Photos: \(camera.savedPhotoCount)")
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 18)
                    Text(launchResult).font(.caption2).lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }.foregroundStyle(.white).padding(.bottom, 10)
            }
        }
        .onAppear {
            if let configured = try? JSONDecoder().decode([Shortcut].self, from: saved),
               !configured.isEmpty { shortcuts = configured }
            camera.selectionTitles = shortcuts.map(\.name)
            camera.start()
        }
        .onDisappear { camera.stop() }
        .onReceive(camera.$selectedIndex) { value in
            if !shortcuts.isEmpty { selection = value % shortcuts.count }
        }
        .sheet(isPresented: $showingGuide) {
            NavigationStack {
                Form {
                    LabeledContent("AVCaptureSession", value: camera.running ? "Running" : "Stopped")
                    LabeledContent("Hardware controls supported", value: camera.supportsControls ? "Yes" : "No")
                    LabeledContent("Controls registered", value: "\(camera.controlsCount)")
                    LabeledContent("Picker callbacks", value: "\(camera.selectionEventCount)")
                    LabeledContent("Hardware capture events", value: "\(camera.captureEventCount)")
                    LabeledContent("Overlay active", value: camera.overlayActive ? "Yes" : "No")
                    Section("Expected testing") {
                        Text("Light press the Camera Control button while Camera Lab is live. The iOS controls interface may expose QuickWheel Slots, allowing slide selection. The system controls how and whether the interface appears.")
                        Text("A full press captures a real photo by default. The experimental toggle attempts to open the selected app, and only works when iOS sends the capture event to this active app.")
                        Text("This interface cannot appear as a transparent overlay over unrelated apps.")
                    }
                }.navigationTitle("Camera Control Lab")
                .toolbar { ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingGuide = false }
                }}
            }
        }
    }

    private func openSelected() {
        guard !shortcuts.isEmpty else { return }
        let raw = shortcuts[selection].url
        guard let url = URL(string: raw), url.scheme != nil else {
            launchResult = "Invalid shortcut URL"
            return
        }
        launchResult = "Opening \(shortcuts[selection].name)..."
        UIApplication.shared.open(url, options: [:]) { ok in
            launchResult = ok ? "iOS accepted \(raw)" : "iOS rejected \(raw)"
        }
    }
}
