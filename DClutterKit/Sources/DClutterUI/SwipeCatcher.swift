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
    var onProgress: ((CGFloat) -> Void)?
    var onCommit: ((DecisionDirection) -> Void)?
    /// Gesture released below the threshold — return the card to rest.
    var onSnapBack: (() -> Void)?
    var isEnabled: Bool = true

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
    }

    /// Returns true when the event was consumed as a swipe.
    private func handle(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        // Only a genuine trackpad gesture carries phase information; a
        // mouse wheel does not, and must keep scrolling normally.
        guard event.phase == .began else { return false }
        // Vertical belongs to the preview's scroller (§6).
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return false }

        var committed = false
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

            guard phase == .ended || isComplete else { return }

            if amount <= -0.5 {
                committed = true
                // Hand over cleanly: stop the tracker dead so it cannot keep
                // animating `amount` underneath the exit animation. Past the
                // threshold the gesture is over and the card simply finishes
                // the throw, exactly as a key press would.
                stop.pointee = true
                self.onCommit?(.stage)
            } else if amount >= 0.5 {
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
