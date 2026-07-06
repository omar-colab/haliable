//
//  LookupResilienceTests.swift
//  HaliableTests
//
//  Phase 3 hardening: the explicit fallback chain (USDA → Open Food Facts →
//  offline cache) and the HTTP retry/backoff helper. Sources and cache are faked
//  so the chain logic is tested without a network; the retry helper is driven by a
//  stubbed URLProtocol with an injected no-op sleep.
//

import XCTest
@testable import Haliable

// MARK: - Test doubles

private struct FakeSource: ProductLookupSource {
    let result: Result<Product, Error>
    func fetchProduct(barcode: String) async throws -> Product { try result.get() }
}

@MainActor
private final class FakeCache: ProductCaching {
    var entries: [String: Product] = [:]
    private(set) var storeCount = 0
    func cached(barcode: String) -> Product? { entries[barcode] }
    func store(_ product: Product) { storeCount += 1; entries[product.id] = product }
}

private func makeProduct(_ id: String, _ name: String) -> Product {
    Product(id: id, name: name, brand: nil, rawIngredientsText: "water",
            additivesENumbers: [], labels: [])
}

@MainActor
final class LookupResilienceTests: XCTestCase {

    // MARK: - Fallback chain

    func testUsdaSuccessUsedFirst() async throws {
        let svc = ProductLookupService(
            usda: FakeSource(result: .success(makeProduct("1", "USDA Item"))),
            off: FakeSource(result: .failure(OFFError.productNotFound)))
        let p = try await svc.fetchProduct(barcode: "1")
        XCTAssertEqual(p.name, "USDA Item")
    }

    func testUsdaNotFoundFallsToOFF() async throws {
        let svc = ProductLookupService(
            usda: FakeSource(result: .failure(OFFError.productNotFound)),
            off: FakeSource(result: .success(makeProduct("2", "OFF Item"))))
        let p = try await svc.fetchProduct(barcode: "2")
        XCTAssertEqual(p.name, "OFF Item")
    }

    func testMissingUsdaKeySkipsToOFF() async throws {
        let svc = ProductLookupService(
            usda: FakeSource(result: .failure(OFFError.configurationMissing("no key"))),
            off: FakeSource(result: .success(makeProduct("3", "OFF Item"))))
        let p = try await svc.fetchProduct(barcode: "3")
        XCTAssertEqual(p.name, "OFF Item")
    }

    func testBothNotFoundThrowsNotFound() async {
        let svc = ProductLookupService(
            usda: FakeSource(result: .failure(OFFError.productNotFound)),
            off: FakeSource(result: .failure(OFFError.productNotFound)))
        do { _ = try await svc.fetchProduct(barcode: "4"); XCTFail("should throw") }
        catch { guard case OFFError.productNotFound = error else { return XCTFail("wrong error: \(error)") } }
    }

    // MARK: - Cache tiering

    func testSuccessfulLookupIsCached() async throws {
        let cache = FakeCache()
        let svc = ProductLookupService(
            usda: FakeSource(result: .success(makeProduct("5", "Cached Me"))),
            off: FakeSource(result: .failure(OFFError.productNotFound)))
        _ = try await svc.fetchProduct(barcode: "5", cache: cache)
        XCTAssertEqual(cache.storeCount, 1)
        XCTAssertEqual(cache.entries["5"]?.name, "Cached Me")
    }

    func testOfflineFallsBackToCache() async throws {
        let cache = FakeCache()
        cache.entries["6"] = makeProduct("6", "From Cache")
        let svc = ProductLookupService(
            usda: FakeSource(result: .failure(OFFError.offline)),
            off: FakeSource(result: .failure(OFFError.offline)))
        let p = try await svc.fetchProduct(barcode: "6", cache: cache)
        XCTAssertEqual(p.name, "From Cache")
    }

    func testOfflineWithNoCacheThrowsOffline() async {
        let svc = ProductLookupService(
            usda: FakeSource(result: .failure(OFFError.offline)),
            off: FakeSource(result: .failure(OFFError.offline)))
        do { _ = try await svc.fetchProduct(barcode: "7", cache: FakeCache()); XCTFail("should throw") }
        catch { guard case OFFError.offline = error else { return XCTFail("wrong error: \(error)") } }
    }

    // MARK: - HTTP retry / backoff

    func testRetriesOn429ThenSucceedsHonoringRetryAfter() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.queue = [
            .response(status: 429, headers: ["Retry-After": "0"], body: Data()),
            .response(status: 200, headers: [:], body: Data("ok".utf8)),
        ]
        var slept: [TimeInterval] = []
        let (data, http) = try await HTTPRetry.data(
            for: URLRequest(url: URL(string: "https://x.test/a")!),
            session: MockURLProtocol.session(),
            sleep: { slept.append($0) })
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "ok")
        XCTAssertEqual(MockURLProtocol.served, 2, "should have retried once")
        XCTAssertEqual(slept, [0], "honored Retry-After: 0")
    }

    func testGivesUpAfterMaxAttemptsOn429() async {
        MockURLProtocol.reset()
        MockURLProtocol.queue = Array(repeating: .response(status: 429, headers: [:], body: Data()), count: 5)
        do {
            _ = try await HTTPRetry.data(
                for: URLRequest(url: URL(string: "https://x.test/b")!),
                session: MockURLProtocol.session(),
                policy: RetryPolicy(maxAttempts: 3, baseDelay: 0.01),
                sleep: { _ in })
            XCTFail("should throw rateLimited")
        } catch {
            guard case OFFError.rateLimited = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(MockURLProtocol.served, 3)
        }
    }

    func testNotConnectedMapsToOffline() async {
        MockURLProtocol.reset()
        MockURLProtocol.queue = [.failure(URLError(.notConnectedToInternet))]
        do {
            _ = try await HTTPRetry.data(
                for: URLRequest(url: URL(string: "https://x.test/c")!),
                session: MockURLProtocol.session(),
                sleep: { _ in })
            XCTFail("should throw offline")
        } catch {
            guard case OFFError.offline = error else { return XCTFail("wrong error: \(error)") }
        }
    }
}

// MARK: - Stubbed URLProtocol

final class MockURLProtocol: URLProtocol {
    enum Step {
        case response(status: Int, headers: [String: String], body: Data)
        case failure(URLError)
    }
    nonisolated(unsafe) static var queue: [Step] = []
    nonisolated(unsafe) static var served = 0

    static func reset() { queue = []; served = 0 }

    static func session() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let step = Self.queue[min(Self.served, Self.queue.count - 1)]
        Self.served += 1
        switch step {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .response(let status, let headers, let body):
            let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
