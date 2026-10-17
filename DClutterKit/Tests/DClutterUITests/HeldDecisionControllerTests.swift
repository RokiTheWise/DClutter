//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation
import Testing
@testable import DClutterUI

@MainActor
private final class ManualSleeper {
    let requests = AsyncStream<Duration>.makeStream()
    var now = ContinuousClock().now
    private var pending: [(Duration, CheckedContinuation<Void, Error>)] = []

    func sleep(_ duration: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pending.append((duration, continuation))
            requests.continuation.yield(duration)
        }
    }

    func advance(elapsingTime: Bool = true) {
        guard !pending.isEmpty else { Issue.record("No scheduled repeat to advance"); return }
        let (duration, continuation) = pending.removeFirst()
        if elapsingTime { now = now.advanced(by: duration) }
        continuation.resume()
    }

    func finish() {
        for (_, continuation) in pending { continuation.resume(throwing: CancellationError()) }
        pending.removeAll()
        requests.continuation.finish()
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct HeldDecisionControllerTests {
    @Test(arguments: [0.5, 1.0, 1.5, 3.0, 8.0])
    func firstPressIsImmediateAndRepeatsUseTheSelectedPace(speed: Double) async {
        let sleeper = ManualSleeper()
        let controller = HeldDecisionController(sleep: sleeper.sleep, now: { sleeper.now })
        defer { controller.stop(); sleeper.finish() }
        var waits = sleeper.requests.stream.makeAsyncIterator()
        var presses: [Bool] = []

        controller.start(.keep, speed: speed) { repeating in presses.append(repeating); return true }
        #expect(presses == [false])
        let initialDelay = await waits.next()
        #expect(initialDelay == max(.milliseconds(450), .seconds(1 / speed)))
        #expect(presses == [false])

        sleeper.advance()
        let repeatDelay = await waits.next()
        #expect(repeatDelay == .seconds(1 / speed))
        #expect(presses == [false, true])

        sleeper.advance()
        let nextDelay = await waits.next()
        #expect(nextDelay == repeatDelay)
        #expect(presses == [false, true, true])
    }

    @Test func releasingBeforeTheInitialDelayNeverRepeats() async throws {
        let sleeper = ManualSleeper()
        let controller = HeldDecisionController(sleep: sleeper.sleep, now: { sleeper.now })
        defer { controller.stop(); sleeper.finish() }
        var waits = sleeper.requests.stream.makeAsyncIterator()
        var count = 0
        controller.start(.stage, speed: 8) { _ in count += 1; return true }
        _ = await waits.next()

        controller.stop(ifHeld: .stage)
        sleeper.advance()
        try await Task.sleep(for: .milliseconds(10))

        #expect(count == 1)
        #expect(controller.direction == nil)
    }

    @Test func halfAFilePerSecondWaitsTwoSecondsAndStopsOnRelease() async throws {
        let sleeper = ManualSleeper()
        let controller = HeldDecisionController(sleep: sleeper.sleep, now: { sleeper.now })
        defer { controller.stop(); sleeper.finish() }
        var waits = sleeper.requests.stream.makeAsyncIterator()
        var count = 0
        controller.start(.keep, speed: 0.5) { _ in count += 1; return true }

        let firstDelay = await waits.next()
        #expect(firstDelay == .seconds(2))
        #expect(count == 1)
        sleeper.advance()
        let nextDelay = await waits.next()
        #expect(nextDelay == .seconds(2))
        #expect(count == 2)

        controller.stop(ifHeld: .keep)
        sleeper.advance()
        try await Task.sleep(for: .milliseconds(10))
        #expect(count == 2)
    }

    @Test func switchingDirectionCancelsTheOldHoldAndIgnoresItsKeyUp() async throws {
        let sleeper = ManualSleeper()
        let controller = HeldDecisionController(sleep: sleeper.sleep, now: { sleeper.now })
        defer { controller.stop(); sleeper.finish() }
        var waits = sleeper.requests.stream.makeAsyncIterator()
        var kept = 0
        var staged = 0
        controller.start(.keep, speed: 3) { _ in kept += 1; return true }
        _ = await waits.next()
        controller.start(.stage, speed: 1) { _ in staged += 1; return true }
        _ = await waits.next()

        controller.stop(ifHeld: .keep)
        #expect(controller.direction == .stage)
        sleeper.advance(elapsingTime: false) // canceled right-arrow sleep
        sleeper.advance() // current left-arrow sleep
        let delay = await waits.next()
        #expect(delay == .seconds(1))
        #expect(kept == 1)
        #expect(staged == 2)

        controller.stop()
        sleeper.advance()
        try await Task.sleep(for: .milliseconds(10))
        #expect(staged == 2)
    }

    @Test func blockedInputOrAnEmptyQueueStopsTheHold() async throws {
        let sleeper = ManualSleeper()
        let controller = HeldDecisionController(sleep: sleeper.sleep, now: { sleeper.now })
        defer { controller.stop(); sleeper.finish() }
        var waits = sleeper.requests.stream.makeAsyncIterator()
        var canDecide = true
        var count = 0
        controller.start(.keep, speed: 3) { _ in
            guard canDecide else { return false }
            count += 1
            return true
        }
        _ = await waits.next()
        canDecide = false
        sleeper.advance()
        try await Task.sleep(for: .milliseconds(10))

        #expect(count == 1)
        #expect(controller.direction == nil)
    }

    @Test func aFreshTapIsNotDelayedByThePreviousHold() async {
        let sleeper = ManualSleeper()
        let controller = HeldDecisionController(sleep: sleeper.sleep, now: { sleeper.now })
        defer { controller.stop(); sleeper.finish() }
        var count = 0
        for _ in 0..<5 {
            controller.start(.keep, speed: 1) { repeating in
                #expect(!repeating)
                count += 1
                return true
            }
            controller.stop(ifHeld: .keep)
        }
        #expect(count == 5)
    }

    @Test func renderingTimeDoesNotSlowTheSelectedRepeatPace() async {
        let sleeper = ManualSleeper()
        let controller = HeldDecisionController(sleep: sleeper.sleep, now: { sleeper.now })
        defer { controller.stop(); sleeper.finish() }
        var waits = sleeper.requests.stream.makeAsyncIterator()
        controller.start(.stage, speed: 8) { repeating in
            if repeating { sleeper.now = sleeper.now.advanced(by: .milliseconds(50)) }
            return true
        }
        _ = await waits.next()
        sleeper.advance()
        let delay = await waits.next()
        #expect(delay == .milliseconds(75))
    }

    @Test func aSlowFrameNeverCreatesABurstOfCatchUpDecisions() async {
        let sleeper = ManualSleeper()
        let controller = HeldDecisionController(sleep: sleeper.sleep, now: { sleeper.now })
        defer { controller.stop(); sleeper.finish() }
        var waits = sleeper.requests.stream.makeAsyncIterator()
        var count = 0
        controller.start(.stage, speed: 8) { repeating in
            count += 1
            if repeating { sleeper.now = sleeper.now.advanced(by: .seconds(3)) }
            return true
        }
        _ = await waits.next()
        sleeper.advance()
        let delay = await waits.next()
        #expect(delay == .milliseconds(125))
        #expect(count == 2)
    }
}
