//
//  HTTPRetry.swift
//  Haliable
//
//  One place for the network hardening every product lookup needs: a request
//  timeout, retry-with-exponential-backoff on transient failures and HTTP 429/5xx,
//  and respect for a `Retry-After` header. Terminal conditions become typed
//  `OFFError`s (offline, rateLimited, badStatus) so the lookup chain and the UI can
//  react predictably instead of seeing raw URLErrors.
//
//  `sleep` is injectable so tests exercise the backoff logic without real delays.
//

import Foundation

struct RetryPolicy {
    var maxAttempts: Int = 3
    var baseDelay: TimeInterval = 0.5     // exponential: 0.5s, 1s, 2s …
    var maxDelay: TimeInterval = 8

    static let `default` = RetryPolicy()
    static let none = RetryPolicy(maxAttempts: 1)
}

enum HTTPRetry {

    /// Perform `request`, retrying transient failures / 429 / 5xx up to the
    /// policy's attempt budget. Returns the body + HTTPURLResponse on a non-retry
    /// status; throws a typed `OFFError` otherwise.
    static func data(for request: URLRequest,
                     session: URLSession,
                     policy: RetryPolicy = .default,
                     sleep: (TimeInterval) async -> Void = Self.realSleep) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw OFFError.networkFailure(underlying: URLError(.badServerResponse))
                }

                // Retryable status codes: 429 (rate limit) and 5xx (server).
                if http.statusCode == 429 || (500...599).contains(http.statusCode) {
                    if attempt < policy.maxAttempts {
                        let delay = retryAfter(http) ?? backoff(attempt, policy)
                        await sleep(min(delay, policy.maxDelay))
                        continue
                    }
                    if http.statusCode == 429 {
                        throw OFFError.rateLimited(retryAfter: retryAfter(http))
                    }
                    throw OFFError.badStatus(http.statusCode)
                }
                return (data, http)

            } catch let urlError as URLError {
                // A genuine lack of connectivity is NOT retried — it short-circuits
                // to `.offline` so the caller can fall back to the cache immediately.
                if urlError.code == .notConnectedToInternet || urlError.code == .dataNotAllowed {
                    throw OFFError.offline
                }
                if isTransient(urlError), attempt < policy.maxAttempts {
                    await sleep(backoff(attempt, policy))
                    continue
                }
                throw OFFError.networkFailure(underlying: urlError)
            }
        }
    }

    // MARK: - Helpers

    private static func isTransient(_ e: URLError) -> Bool {
        switch e.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    static func backoff(_ attempt: Int, _ p: RetryPolicy) -> TimeInterval {
        min(p.baseDelay * pow(2, Double(attempt - 1)), p.maxDelay)
    }

    /// Parse a `Retry-After` header in delta-seconds form (the form Cloudflare /
    /// OFF / data.gov use). HTTP-date form is intentionally not handled.
    static func retryAfter(_ http: HTTPURLResponse) -> TimeInterval? {
        guard let raw = http.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(raw.trimmingCharacters(in: .whitespaces)) else { return nil }
        return max(0, seconds)
    }

    static func realSleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
