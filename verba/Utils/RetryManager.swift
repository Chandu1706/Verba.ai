//
//  RetryManager.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//
// RetryManager.swift
// Located in Controller or Utils folder

import Foundation

class RetryManager {
    static let shared = RetryManager()
    private var failureCount = 0
    private let maxFailures = 5

    func recordFailure() {
        failureCount += 1
    }

    func resetFailures() {
        failureCount = 0
    }

    func shouldFallback() -> Bool {
        return failureCount >= maxFailures
    }

    func exponentialBackoff(for attempt: Int) -> TimeInterval {
        // capping max wait to 32 seconds
        return min(pow(2.0, Double(attempt)), 32.0)
    }
}
