import Foundation

enum RateLimitError: LocalizedError {
    case tooManyRequests(retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case let .tooManyRequests(retryAfter):
            let seconds = max(1, Int(retryAfter.rounded(.up)))
            return "Rate limit exceeded. Try again in \(seconds) seconds."
        }
    }
}

actor FixedWindowRateLimiter {
    private let maxRequests: Int
    private let window: TimeInterval
    private var requestTimestamps: [Date] = []

    init(maxRequests: Int, window: TimeInterval) {
        self.maxRequests = max(1, maxRequests)
        self.window = max(1, window)
    }

    func acquire() throws {
        let now = Date()
        let cutoff = now.addingTimeInterval(-window)
        requestTimestamps.removeAll { $0 < cutoff }

        guard requestTimestamps.count < maxRequests else {
            guard let earliest = requestTimestamps.min() else {
                throw RateLimitError.tooManyRequests(retryAfter: window)
            }
            let retryAfter = earliest.addingTimeInterval(window).timeIntervalSince(now)
            throw RateLimitError.tooManyRequests(retryAfter: retryAfter)
        }

        requestTimestamps.append(now)
    }
}
