import Foundation

/// Spaces requests out so a client never sends more than a set number per second.
///
/// The Met asks API users to stay under 80 requests per second. Every request a
/// ``MetMuseumClient`` sends first takes the next free slot here; slots are `1 / requestsPerSecond`
/// apart, so a burst of concurrent requests leaves at a steady rate instead of all at once.
/// Share one client (and so one throttle) across your app to keep the limit app-wide.
public actor MetRequestThrottle {
    /// The most requests per second. `0` or less turns throttling off.
    public nonisolated let requestsPerSecond: Double
    /// The time between two slots.
    public nonisolated let interval: Duration
    private var nextSlot: ContinuousClock.Instant?

    public init(requestsPerSecond: Double) {
        self.requestsPerSecond = requestsPerSecond
        if requestsPerSecond > 0, requestsPerSecond.isFinite {
            // Whole nanoseconds, so slots add up exactly.
            interval = .nanoseconds(Int64(min(1_000_000_000 / requestsPerSecond, 1e15).rounded()))
        } else {
            interval = .zero
        }
    }

    /// Takes the next free slot and returns how long to wait for it, measured from `now`.
    /// Exposed for tests; ``acquire()`` is what the client calls.
    public func reserve(at now: ContinuousClock.Instant) -> Duration {
        guard interval > .zero else { return .zero }
        let slot = max(now, nextSlot ?? now)
        nextSlot = slot.advanced(by: interval)
        return now.duration(to: slot)
    }

    /// Waits for the next free slot. Throws `CancellationError` when the task is cancelled while
    /// waiting.
    public func acquire() async throws {
        let delay = reserve(at: ContinuousClock.now)
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
    }
}

/// Runs `transform` over `items` with at most `maxConcurrent` calls in flight, and returns the
/// results in the order of `items`. The first error cancels the remaining work and is rethrown.
func boundedMap<Item: Sendable, Result: Sendable>(
    _ items: [Item],
    maxConcurrent: Int,
    _ transform: @escaping @Sendable (Item) async throws -> Result
) async throws -> [Result] {
    guard !items.isEmpty else { return [] }
    let width = max(1, min(maxConcurrent, items.count))
    return try await withThrowingTaskGroup(of: (Int, Result).self) { group in
        var results = [Result?](repeating: nil, count: items.count)
        var next = 0
        while next < width {
            let index = next
            let item = items[index]
            group.addTask { (index, try await transform(item)) }
            next += 1
        }
        while let finished = try await group.next() {
            results[finished.0] = finished.1
            if next < items.count {
                let index = next
                let item = items[index]
                group.addTask { (index, try await transform(item)) }
                next += 1
            }
        }
        return results.compactMap { $0 }
    }
}
