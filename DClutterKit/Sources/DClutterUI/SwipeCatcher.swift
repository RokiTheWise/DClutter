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
struct SwipeCatcher: ViewModifier {
    /// Live gesture position, -1 (fully left) to 1 (fully right), so the
    /// card can follow the fingers before any decision is committed.
    var onProgress: (CGFloat) -> Void
    /// Fired once the gesture settles past `trackSwipeEvent`'s threshold.
    var onCommit: (DecisionDirection) -> Void
    /// While the live preview has focus the gesture belongs to it, not to
    /// triage — the same rule the keyboard handler follows.
    var isEnabled: Bool

    func body(content: Content) -> some View {
        content.background(
            SwipeMonitor(onProgress: onProgress, onCommit: onCommit, isEnabled: isEnabled)
                .frame(width: 0, height: 0)
        )
    }
}

private struct SwipeMonitor: NSViewRepresentable {
    var onProgress: (CGFloat) -> Void
    var onCommit: (DecisionDirection) -> Void
    var isEnabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.update(onProgress: onProgress, onCommit: onCommit, isEnabled: isEnabled)
        context.coordinator.start()
        return NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.update(onProgress: onProgress, onCommit: onCommit, isEnabled: isEnabled)
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        private var monitor: Any?
        private var onProgress: ((CGFloat) -> Void)?
        private var onCommit: ((DecisionDirection) -> Void)?
        private var isEnabled = true

        func update(
            onProgress: @escaping (CGFloat) -> Void,
            onCommit: @escaping (DecisionDirection) -> Void,
            isEnabled: Bool
        ) {
            self.onProgress = onProgress
            self.onCommit = onCommit
            self.isEnabled = isEnabled
        }

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
            ) { [weak self] amount, phase, isComplete, _ in
                guard let self else { return }
                self.onProgress?(amount)

                // trackSwipeEvent reports completion only once the gesture
                // has settled past its own threshold, so this IS the
                // threshold decision — no hand-rolled distance check.
                if !committed, phase == .ended || isComplete {
                    if amount <= -0.5 {
                        committed = true
                        self.onCommit?(.stage)
                    } else if amount >= 0.5 {
                        committed = true
                        self.onCommit?(.keep)
                    }
                }
                if isComplete { self.onProgress?(0) }
            }
            return true
        }
    }
}

extension View {
    /// §6 horizontal swipe. See `SwipeCatcher`.
    func onHorizontalSwipe(
        isEnabled: Bool,
        onProgress: @escaping (CGFloat) -> Void,
        onCommit: @escaping (DecisionDirection) -> Void
    ) -> some View {
        modifier(SwipeCatcher(onProgress: onProgress, onCommit: onCommit, isEnabled: isEnabled))
    }
}
