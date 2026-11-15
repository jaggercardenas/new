import SwiftUI
import AVKit
import UIKit

/// Gesture lab for the iPhone's Camera Control while this app has an active camera session.
/// The initial press that launches an app, and presses made in other apps, are controlled by iOS.
struct CameraLabView: View {
    @AppStorage("savedShortcuts") private var saved = Data()
    @AppStorage("quickwheel.singleActionIndex") private var singleActionIndex = 0
    @AppStorage("quickwheel.doubleActionIndex") private var doubleActionIndex = 1

    @StateObject private var camera = CameraEngine()
    @StateObject private var gestures = CameraGestureController()

    @State private var shortcuts: [Shortcut] = [
        .init(name: "Shortcuts", symbol: "square.stack.3d.up.fill", url: "shortcuts://"),
        .init(name: "Maps", symbol: "map.fill", url: "maps://"),
        .init(name: "Messages", symbol: "message.fill", url: "sms:"),
        .init(name: "Music", symbol: "music.note", url: "music://"),
        .init(name: "ChatGPT web", symbol: "bubble.left.and.bubble.right.fill", url: "https://chatgpt.com")
    ]
    @State private var selection = 0
    @State private var result = "Run a gesture test, or press Camera Control with the camera live."
    @State private var showingGuide = false
    @State private var lastDrag: CGFloat = 0

    private var selected: Shortcut {
        shortcuts[min(max(selection, 0), shortcuts.count - 1)]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .onCameraCaptureEvent { event in
                        switch event.phase {
                        case .began: gestures.began()
                        case .ended: gestures.ended()
                        case .cancelled: gestures.cancelled()
                        @unknown default: break
                        }
                    }

                LinearGradient(
                    colors: [.black.opacity(0.72), .clear, .black.opacity(0.88)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 12) {
                    HStack {
                        Label(camera.running ? "Camera Control live" : "Camera starting",
                              systemImage: "camera.fill")
                        Spacer()
                        Button { showingGuide = true } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    Text(camera.status)
                        .font(.caption2)
                        .lineLimit(2)

                    VStack(spacing: 7) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.tap.fill").frame(width: 24)
                            Text("Single click").frame(maxWidth: .infinity, alignment: .leading)
                            Picker("Single-click action", selection: $singleActionIndex) {
                                ForEach(shortcuts.indices, id: \.self) { index in
                                    Text(shortcuts[index].name).tag(index)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "hand.tap.fill").frame(width: 24)
                            Text("Double-click").frame(maxWidth: .infinity, alignment: .leading)
                            Picker("Double-click action", selection: $doubleActionIndex) {
                                ForEach(shortcuts.indices, id: \.self) { index in
                                    Text(shortcuts[index].name).tag(index)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "hand.point.up.left.fill").frame(width: 24)
                            Text("Hold").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Open wheel").foregroundStyle(.cyan)
                        }
                    }
                    .font(.subheadline)
                    .padding(14)
                    .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 14)

                    Spacer(minLength: 0)

                    if gestures.wheelVisible {
                        wheel(diameter: min(geometry.size.width - 75, 300.0))
                            .transition(.scale.combined(with: .opacity))
                        Text("Slide on the wheel, or use QuickWheel Slots in Camera Control")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        HStack {
                            Button { gestures.closeWheel() } label: {
                                Label("Close", systemImage: "xmark")
                            }
                            .buttonStyle(.bordered)

                            Button { openAction(selection) } label: {
                                Label("Run " + selected.name, systemImage: "arrow.up.right")
                                    .lineLimit(1)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) { gestures.simulateHold() }
                        } label: {
                            Label("Open QuickWheel", systemImage: "circle.grid.3x3.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal, 28)
                    }

                    HStack(spacing: 9) {
                        Button("Test click") { gestures.simulateSingle() }
                        Button("Test double") { gestures.simulateDouble() }
                        Button("Test hold") {
                            withAnimation(.easeInOut(duration: 0.22)) { gestures.simulateHold() }
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)

                    Text(gestures.status)
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 15)

                    Text(result)
                        .font(.caption2)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    HStack {
                        Text("Click: \(gestures.singleCount)")
                        Spacer()
                        Text("Double: \(gestures.doubleCount)")
                        Spacer()
                        Text("Hold: \(gestures.holdCount)")
                        Spacer()
                        Text("Picker: \(camera.selectionEventCount)")
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 20)

                    Button { camera.capturePhoto() } label: {
                        Label("Take photo", systemImage: "camera.shutter.button")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .foregroundStyle(.white)
                .padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let configured = try? JSONDecoder().decode([Shortcut].self, from: saved),
               !configured.isEmpty { shortcuts = configured }
            selection = min(selection, shortcuts.count - 1)
            singleActionIndex = min(max(singleActionIndex, 0), shortcuts.count - 1)
            doubleActionIndex = min(max(doubleActionIndex, 0), shortcuts.count - 1)
            camera.selectionTitles = shortcuts.map(\.name)
            gestures.onSingle = { openAction(singleActionIndex) }
            gestures.onDouble = { openAction(doubleActionIndex) }
            camera.start()
        }
        .onDisappear {
            gestures.cancelled()
            gestures.onSingle = nil
            gestures.onDouble = nil
            camera.stop()
        }
        .onReceive(camera.$selectedIndex) { value in
            if !shortcuts.isEmpty { selection = max(0, value % shortcuts.count) }
        }
        .onReceive(camera.$selectionEventCount) { count in
            if count > 0 { gestures.wheelVisible = true }
        }
        .sheet(isPresented: $showingGuide) {
            NavigationStack {
                Form {
                    Section("What the three gestures do") {
                        Text("One short full press runs the assigned single-click action after a short wait. Two short full presses run the double-click action. A full press held for about 0.55 seconds opens the on-screen wheel.")
                        Text("The Test buttons work without pressing the hardware button. Actual hardware events only arrive while this camera session is running and iOS allows them.")
                    }
                    Section("Sliding") {
                        Text("The system's Camera Control QuickWheel Slots picker can select an item when iOS exposes it. A light double-press may be needed to select that picker first. We cannot intercept arbitrary raw Camera Control swipes.")
                        Text("Once the wheel is visible, you can also drag it on-screen and tap Run.")
                    }
                    Section("Limitations") {
                        Text("The Camera Control click that initially opens a camera app is handled by iOS and may not arrive here as an event.")
                        Text("QuickWheel cannot replace single/double/hold for the entire operating system or show a floating wheel over unrelated apps using LiveContainer.")
                        Text("Changing a shortcut's target URL is done in the Launcher tab. Shortcut links must be supported by the destination app or Apple Shortcuts.")
                    }
                    Section("Diagnostics") {
                        LabeledContent("Session", value: camera.running ? "Running" : "Stopped")
                        LabeledContent("Registered controls", value: "\(camera.controlsCount)")
                        LabeledContent("Hardware picker callbacks", value: "\(camera.selectionEventCount)")
                    }
                }
                .navigationTitle("Camera Control")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showingGuide = false }
                    }
                }
            }
        }
    }

    private func wheel(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(.cyan.opacity(0.85), lineWidth: 2))

            ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, item in
                let angle = Double(index - selection) * 2 * Double.pi
                    / Double(max(shortcuts.count, 1)) - Double.pi / 2

                Button {
                    selection = index
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: item.symbol)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(index == selection ? Color.blue : Color.black.opacity(0.65),
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .position(
                    x: diameter / 2 + cos(angle) * diameter * 0.37,
                    y: diameter / 2 + sin(angle) * diameter * 0.37
                )
            }

            VStack(spacing: 6) {
                Image(systemName: selected.symbol).font(.system(size: 32))
                Text(selected.name).font(.caption.bold())
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(width: diameter * 0.44, height: diameter * 0.44)
            .background(.black.opacity(0.85), in: Circle())
        }
        .frame(width: diameter, height: diameter)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    let delta = value.translation.height - lastDrag
                    if abs(delta) >= 30 {
                        selection = (selection + (delta > 0 ? 1 : -1)
                                     + shortcuts.count) % shortcuts.count
                        UISelectionFeedbackGenerator().selectionChanged()
                        lastDrag = value.translation.height
                    }
                }
                .onEnded { _ in lastDrag = 0 }
        )
    }

    private func openAction(_ index: Int) {
        guard shortcuts.indices.contains(index) else {
            result = "No action assigned"
            return
        }

        let action = shortcuts[index]
        let value = action.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), url.scheme != nil else {
            result = "Invalid link for \(action.name). Edit it in Launcher."
            return
        }

        result = "Opening \(action.name)..."
        UIApplication.shared.open(url, options: [:]) { accepted in
            result = accepted
                ? "iOS accepted \(action.name)."
                : "iOS rejected \(value). Try an Apple Shortcut or a web URL."
        }
    }
}
