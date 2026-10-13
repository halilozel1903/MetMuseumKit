import Foundation
import Testing
@testable import MetMuseumKit

@Suite("Throttling and concurrency")
struct ThrottleTests {
    @Test func slotsAreSpacedOut() async {
        let throttle = MetRequestThrottle(requestsPerSecond: 80)
        let start = ContinuousClock.now

        let first = await throttle.reserve(at: start)
        let second = await throttle.reserve(at: start)
        let third = await throttle.reserve(at: start)

        #expect(first == .zero)
        #expect(second == .milliseconds(12.5))
        #expect(third == .milliseconds(25))
        #expect(throttle.interval == .milliseconds(12.5))
    }

    @Test func idleTimeIsNotSavedUp() async {
        let throttle = MetRequestThrottle(requestsPerSecond: 10)
        let start = ContinuousClock.now

        _ = await throttle.reserve(at: start)
        // A second later the next slot is free at once, and the one after waits a full interval.
        let later = start.advanced(by: .seconds(1))
        let afterPause = await throttle.reserve(at: later)
        let next = await throttle.reserve(at: later)

        #expect(afterPause == .zero)
        #expect(next == .milliseconds(100))
    }

    @Test func zeroTurnsThrottlingOff() async {
        let throttle = MetRequestThrottle(requestsPerSecond: 0)
        let start = ContinuousClock.now
        for _ in 0..<5 {
            let delay = await throttle.reserve(at: start)
            #expect(delay == .zero)
        }
    }

    @Test func acquireWaits() async throws {
        let throttle = MetRequestThrottle(requestsPerSecond: 50)
        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            for _ in 0..<6 {
                try await throttle.acquire()
            }
        }
        // Five intervals of 20 ms after the first, free slot.
        #expect(elapsed >= .milliseconds(95))
    }

    @Test func boundedMapKeepsOrderAndLimitsConcurrency() async throws {
        let gauge = Gauge()
        let results = try await boundedMap(Array(0..<20), maxConcurrent: 4) { value in
            await gauge.enter()
            try await Task.sleep(for: .milliseconds(Double((value * 7) % 5 + 1)))
            await gauge.leave()
            return value * 10
        }

        #expect(results == (0..<20).map { $0 * 10 })
        let peak = await gauge.peak
        #expect(peak <= 4)
        #expect(peak >= 2)
    }

    @Test func boundedMapRethrows() async {
        struct Boom: Error {}
        await #expect(throws: Boom.self) {
            _ = try await boundedMap([1, 2, 3], maxConcurrent: 2) { value in
                if value == 2 { throw Boom() }
                return value
            }
        }
    }

    @Test func boundedMapOfNothing() async throws {
        let results = try await boundedMap([Int](), maxConcurrent: 3) { $0 }
        #expect(results.isEmpty)
    }

    @Test func clientRequestsGoThroughTheThrottle() async throws {
        let stub = StubbedClient(requestsPerSecond: 40) { request in
            .object(request.objectID ?? 0)
        }
        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            _ = try await stub.client.objects(ids: Array(1...5), maxConcurrentRequests: 5)
        }
        // Five requests at 40 per second: the last leaves 100 ms after the first.
        #expect(elapsed >= .milliseconds(95))
        #expect(stub.requests.count == 5)
    }
}

/// Tracks how many tasks are inside a section at once.
actor Gauge {
    private(set) var current = 0
    private(set) var peak = 0

    func enter() {
        current += 1
        peak = max(peak, current)
    }

    func leave() {
        current -= 1
    }
}
