//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

enum InteractionSettings {
    static let holdSpeedKey = "dev.djenriquez.DClutter.holdSpeed"
    static let confirmAddFolderKey = "dev.djenriquez.DClutter.confirmAddFolder"
    static let defaultHoldSpeed: Double = 3
    static let holdSpeedRange: ClosedRange<Double> = 0.5...8

    static func boundedSpeed(_ value: Double) -> Double {
        guard value.isFinite else { return defaultHoldSpeed }
        return min(max(value, holdSpeedRange.lowerBound), holdSpeedRange.upperBound)
    }
}

/// Owns repeat timing instead of letting the macOS key-repeat rate decide
/// files. No backlog is accumulated: release or loss of focus stops the hold.
@MainActor
final class HeldDecisionController {
    static let initialDelay: Duration = .milliseconds(450)
    private let sleep: @MainActor (Duration) async throws -> Void
    private let now: @MainActor () -> ContinuousClock.Instant
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private(set) var direction: DecisionDirection?

    init(
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping @MainActor () -> ContinuousClock.Instant = { ContinuousClock().now }
    ) {
        self.sleep = sleep
        self.now = now
    }

    /// `perform` returns false when the queue ends or another UI owns input.
    func start(_ direction: DecisionDirection, speed: Double, perform: @escaping @MainActor (Bool) -> Bool) {
        stop()
        self.direction = direction
        guard perform(false) else { stop(); return }
        let generation = self.generation
        let interval = Duration.seconds(1 / InteractionSettings.boundedSpeed(speed))
        let sleep = self.sleep
        let now = self.now
        // Slow paces must also govern the first repeat. At 0.5 files/s,
        // the second decision waits two seconds rather than 450 ms.
        let initialDelay = max(Self.initialDelay, interval)
        var nextRepeat = now().advanced(by: initialDelay)
        task = Task { [weak self] in
            do {
                try await sleep(initialDelay)
                while !Task.isCancelled {
                    guard let self, self.generation == generation else { return }
                    guard perform(true) else { self.stop(); return }
                    nextRepeat = nextRepeat.advanced(by: interval)
                    let current = now()
                    // Account for rendering/persistence time, but never
                    // replay missed ticks in a burst after a stall.
                    if nextRepeat <= current { nextRepeat = current.advanced(by: interval) }
                    try await sleep(current.duration(to: nextRepeat))
                }
            } catch {
                // Releasing the key cancels the current sleep.
            }
        }
    }

    func stop(ifHeld direction: DecisionDirection? = nil) {
        if let direction, direction != self.direction { return }
        generation = UUID()
        task?.cancel()
        task = nil
        self.direction = nil
    }
}
