//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import AppKit
import SwiftUI

/// Two-finger horizontal swipe → keep / stage-for-trash (§6).
///
/// Built on `NSEvent.trackSwipeEvent`, which supplies rubber-banding and
/// snap-back-below-threshold for free; §6 is explicit that the threshold
/// logic must not be hand-rolled.
///
/// **Horizontal only, deliberately.** Two-finger *vertical* arrives as the
/// same `scrollWheel:` stream that scrolls the QuickLook preview, so §6
/// reserves vertical for scrolling and puts move-to-destination on a
/// click-drag instead. Anything not dominantly horizontal is passed
/// straight through untouched.
///
/// Implemented as a window-local event monitor rather than a view: an
/// `NSView` overlay would have to win hit-testing to receive scroll events,
/// and winning hit-testing would swallow the double-click-to-open on the
/// card underneath it.
/// Owns the window-local scroll monitor. Driven from `onAppear` rather
/// than wrapped in an `NSViewRepresentable`: a zero-sized representable in
/// a `.background` was never instantiated by SwiftUI, so the monitor was
/// never installed at all.
@MainActor
final class SwipeMonitorController {
    private var monitor: Any?
    private var steeringMonitor: Any?
    var onProgress: ((CGFloat) -> Void)?
    var onCommit: ((DecisionDirection) -> Void)?
    /// Gesture released below the threshold — return the card to rest.
    var onSnapBack: (() -> Void)?
    /// Two fingers up: reveal the destination shelf. Safe on the same
    /// event stream as the horizontal swipe now that nothing else wants
    /// vertical — the live preview that §6 was protecting is gone, so the
    /// two gestures are separated by axis alone.
    var onShelfOpen: (() -> Void)?
    /// Fingers moved horizontally while the shelf is open: -1 or +1 to
    /// step the highlighted bin.
    var onShelfStep: ((Int) -> Void)?
    /// Fingers lifted with the shelf open: file into the highlighted bin.
    var onShelfCommit: (() -> Void)?
    /// Fingers dragged back down: abandon the shelf without filing.
    /// Cancelling has to be as easy as committing (§6).
    var onShelfCancel: (() -> Void)?
    /// True while the shelf is showing, so the monitor knows to steer bins
    /// rather than start another decision.
    var isShelfOpen = false
    var isEnabled: Bool = true

    /// Fraction of a full gesture that commits a decision. Low enough to
    /// fire early in a deliberate flick, high enough that a stray
    /// horizontal wobble during a scroll doesn't decide a file.
    private static let threshold: CGFloat = 0.4

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        endShelfSteering()
    }

    /// Steers the highlighted bin using the raw scroll deltas of the very
    /// gesture that opened the shelf, and files into the highlighted bin
    /// when the fingers lift. `trackSwipeEvent` reports a single dominant
    /// axis, so it cannot follow a gesture that starts vertical and then
    /// moves sideways — which is exactly the "up, across, let go" motion.
    private func beginShelfSteering() {
        guard steeringMonitor == nil else { return }
        var travelled: CGFloat = 0
        var vertical: CGFloat = 0
        steeringMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }

            // Dragging back down abandons the shelf — the same fingers that
            // opened it close it, without having to reach for Escape.
            vertical += event.scrollingDeltaY
            if vertical > 50 {
                self.endShelfSteering()
                self.onShelfCancel?()
                return nil
            }

            travelled += event.scrollingDeltaX
            // One bin per 60pt of travel: far enough that a wobble doesn't
            // skid across the row, close enough to reach bin three easily.
            while abs(travelled) >= 60 {
                let step = travelled > 0 ? 1 : -1
                travelled -= CGFloat(step) * 60
                self.onShelfStep?(step)
            }
            if event.phase == .ended || event.momentumPhase == .ended {
                self.endShelfSteering()
                self.onShelfCommit?()
            }
            return nil
        }
    }

    func endShelfSteering() {
        if let steeringMonitor { NSEvent.removeMonitor(steeringMonitor) }
        steeringMonitor = nil
    }

    /// Returns true when the event was consumed as a swipe.
    private func handle(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        // Only a genuine trackpad gesture carries phase information; a
        // mouse wheel does not, and must keep scrolling normally.
        guard event.phase == .began else { return false }

        // Already steering — the steering monitor owns the events.
        if isShelfOpen { return false }

        // Fingers up reveals the shelf, and the very same gesture carries on
        // into steering so the motion is one continuous "up, across, let
        // go" rather than two separate swipes.
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
            guard event.scrollingDeltaY < 0 else { return false }
            onShelfOpen?()
            beginShelfSteering()
            return true
        }

        var committed = false
        var stepAccumulator: CGFloat = 0
        event.trackSwipeEvent(
            options: .lockDirection,
            dampenAmountThresholdMin: -1,
            max: 1
        ) { [weak self] amount, phase, isComplete, stop in
            guard let self else { return }

            // Once the decision is made this gesture is over as far as the
            // card is concerned. trackSwipeEvent keeps calling back while it
            // settles, and letting those through moved the *next* card —
            // the new card inherited the tail of the finished swipe, which
            // is what made releasing feel sticky next to the arrow keys.
            if committed { return }

            // Live tracking: follow the fingers exactly, unanimated.
            self.onProgress?(amount)

            // Commit as soon as the threshold is crossed, mid-gesture,
            // rather than waiting for the fingers to lift. Waiting was what
            // made a swipe feel sluggish next to a key press: the decision
            // could not start until the gesture ended, so the delay was the
            // user's own release, not the animation.
            if amount <= -Self.threshold {
                committed = true
                // Stop the tracker dead, so it cannot keep animating
                // `amount` underneath the exit that is about to play.
                stop.pointee = true
                self.onCommit?(.stage)
            } else if amount >= Self.threshold {
                committed = true
                stop.pointee = true
                self.onCommit?(.keep)
            } else if isComplete {
                // Below threshold: spring the card back rather than
                // leaving it parked where the fingers stopped.
                self.onSnapBack?()
            }
        }
        return true
    }
}
