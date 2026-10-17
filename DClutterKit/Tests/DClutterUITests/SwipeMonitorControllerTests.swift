//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import AppKit
import SwiftUI
import Testing
@testable import DClutterUI

private final class ScrollEvent: NSEvent {
    var targetWindow: NSWindow?
    var gesturePhase: NSEvent.Phase = .began
    var momentum: NSEvent.Phase = []
    var testDeltaX: CGFloat = 0
    var testDeltaY: CGFloat = -20

    override var window: NSWindow? { targetWindow }
    override var phase: NSEvent.Phase { gesturePhase }
    override var momentumPhase: NSEvent.Phase { momentum }
    override var scrollingDeltaX: CGFloat { testDeltaX }
    override var scrollingDeltaY: CGFloat { testDeltaY }
}

private final class TriageWindow: NSWindow {
    var testKeyWindow = true
    var testSheet: NSWindow?
    override var isKeyWindow: Bool { testKeyWindow }
    override var attachedSheet: NSWindow? { testSheet }
}

@MainActor
@Suite(.serialized)
struct SwipeMonitorControllerTests {
    private func window() -> TriageWindow {
        _ = NSApplication.shared
        return TriageWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
    }

    @Test func backgroundReaderBindsTheMonitorToItsHostingWindow() {
        let triage = window()
        let controller = SwipeMonitorController()
        let host = NSHostingView(rootView:
            Color.clear.frame(width: 100, height: 100)
                .background { SwipeMonitorWindowReader(controller: controller) }
        )
        triage.contentView = host
        host.layoutSubtreeIfNeeded()

        #expect(controller.window === triage)
    }

    @Test func onlyTheActiveTriageWindowCanOpenTheShelf() {
        let triage = window()
        let picker = window()
        let controller = SwipeMonitorController()
        controller.window = triage
        defer { controller.stop() }
        var opened = 0
        controller.onShelfOpen = { opened += 1 }
        let event = ScrollEvent()

        event.targetWindow = picker
        #expect(!controller.handle(event))
        event.targetWindow = nil
        #expect(!controller.handle(event))
        event.targetWindow = triage
        triage.testKeyWindow = false
        #expect(!controller.handle(event))
        triage.testKeyWindow = true
        triage.testSheet = picker
        #expect(!controller.handle(event))
        triage.testSheet = nil
        controller.isEnabled = false
        #expect(!controller.handle(event))
        #expect(opened == 0)

        controller.isEnabled = true
        #expect(controller.handle(event))
        #expect(opened == 1)
    }

    @Test func scrollingInAPickerCannotSteerOrCommitAnExistingGesture() {
        let triage = window()
        let picker = window()
        let controller = SwipeMonitorController()
        controller.window = triage
        defer { controller.stop() }
        var steps = 0
        var commits = 0
        controller.onShelfStep = { steps += $0 }
        controller.onShelfCommit = { commits += 1 }
        let event = ScrollEvent()
        event.targetWindow = triage
        #expect(controller.handle(event))

        event.targetWindow = picker
        event.testDeltaX = 120
        event.gesturePhase = .ended
        #expect(!controller.handleShelfSteering(event))
        // The abandoned gesture must not commit when focus returns either.
        event.targetWindow = triage
        #expect(!controller.handleShelfSteering(event))
        #expect(steps == 0)
        #expect(commits == 0)
    }

    @Test func disablingInputAbandonsSteeringUntilAFreshGesture() {
        let triage = window()
        let controller = SwipeMonitorController()
        controller.window = triage
        defer { controller.stop() }
        var commits = 0
        controller.onShelfCommit = { commits += 1 }
        let event = ScrollEvent()
        event.targetWindow = triage
        #expect(controller.handle(event))

        controller.isEnabled = false
        controller.isEnabled = true
        event.gesturePhase = .ended
        #expect(!controller.handleShelfSteering(event))
        #expect(commits == 0)

        event.gesturePhase = .began
        #expect(controller.handle(event))
        event.gesturePhase = .ended
        #expect(controller.handleShelfSteering(event))
        #expect(commits == 1)
    }

    @Test func shelfGestureSteersAndCommitsOnceWithoutReplayingMomentum() {
        let triage = window()
        let controller = SwipeMonitorController()
        controller.window = triage
        defer { controller.stop() }
        var steps = 0
        var commits = 0
        controller.onShelfStep = { steps += $0 }
        controller.onShelfCommit = { commits += 1 }
        let event = ScrollEvent()
        event.targetWindow = triage
        #expect(controller.handle(event))

        event.gesturePhase = .changed
        event.testDeltaX = 120
        event.testDeltaY = 0
        #expect(controller.handleShelfSteering(event))
        #expect(steps == 2)
        event.gesturePhase = .ended
        event.testDeltaX = 0
        #expect(controller.handleShelfSteering(event))
        event.gesturePhase = []
        event.momentum = .ended
        #expect(!controller.handleShelfSteering(event))
        #expect(!controller.handle(event))
        #expect(commits == 1)
    }

    @Test func cancelledShelfGestureDoesNotFileAnything() {
        let triage = window()
        let controller = SwipeMonitorController()
        controller.window = triage
        defer { controller.stop() }
        var cancelled = 0
        var commits = 0
        controller.onShelfCancel = { cancelled += 1 }
        controller.onShelfCommit = { commits += 1 }
        let event = ScrollEvent()
        event.targetWindow = triage
        #expect(controller.handle(event))

        event.gesturePhase = .cancelled
        #expect(controller.handleShelfSteering(event))
        event.gesturePhase = .ended
        #expect(!controller.handleShelfSteering(event))
        #expect(cancelled == 1)
        #expect(commits == 0)
    }
}
