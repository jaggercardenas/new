import Foundation
import SwiftUI

/// Interprets capture-button presses that the OS actually delivers to an ACTIVE camera app.
/// It is not a SpringBoard hook, global button remapper, or background gesture listener.
@MainActor
final class CameraGestureController: ObservableObject {
    @Published private(set) var status = "Waiting for Camera Control input"
    @Published var wheelVisible = false
    @Published private(set) var singleCount = 0
    @Published private(set) var doubleCount = 0
    @Published private(set) var holdCount = 0

    var onSingle: (() -> Void)?
    var onDouble: (() -> Void)?

    private var isPressing = false
    private var holdTriggered = false
    private var isSecondPress = false
    private var holdWork: DispatchWorkItem?
    private var clickWork: DispatchWorkItem?

    // A full Camera Control press, rather than a light touch, is the capture event.
    // Apple can intercept or omit some system-level gestures; only delivered events count.
    func began() {
        guard !isPressing else { return }
        isPressing = true
        holdTriggered = false

        // A second press cancels the pending single-click action.
        isSecondPress = clickWork != nil
        clickWork?.cancel()
        clickWork = nil

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isPressing else { return }
            self.holdTriggered = true
            self.wheelVisible = true
            self.holdCount += 1
            self.status = "Hold detected — wheel open. Slide or tap to choose."
        }
        holdWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }

    func ended() {
        guard isPressing else { return }
        isPressing = false
        holdWork?.cancel()
        holdWork = nil

        if holdTriggered {
            isSecondPress = false
            return
        }

        if isSecondPress {
            isSecondPress = false
            runDouble()
        } else {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.clickWork = nil
                self.runSingle()
            }
            clickWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: work)
        }
    }

    func cancelled() {
        isPressing = false
        holdTriggered = false
        isSecondPress = false
        holdWork?.cancel()
        holdWork = nil
        clickWork?.cancel()
        clickWork = nil
        status = "Camera Control press cancelled"
    }

    func simulateSingle() { runSingle() }
    func simulateDouble() { runDouble() }
    func simulateHold() {
        wheelVisible = true
        holdCount += 1
        status = "Test hold — wheel open"
    }

    func closeWheel() {
        wheelVisible = false
        status = "Wheel dismissed"
    }

    private func runSingle() {
        singleCount += 1
        status = "Single click — launching assigned action"
        onSingle?()
    }

    private func runDouble() {
        doubleCount += 1
        status = "Double-click — launching assigned action"
        onDouble?()
    }
}
