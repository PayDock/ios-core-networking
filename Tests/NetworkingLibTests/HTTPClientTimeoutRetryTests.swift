//
//  HTTPClientTimeoutRetryTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class HTTPClientTimeoutRetryTests: XCTestCase {

    private var httpClient: HTTPClient!

    override func setUp() {
        super.setUp()
        httpClient = HTTPClientTestable()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        httpClient = nil
        super.tearDown()
    }

    // MARK: - Timeout Tests

    func testRequestWithCustomTimeoutSucceeds() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 5.0
            )
            XCTAssertEqual(result.id, 1)
        } catch {
            XCTFail("Request should succeed: \(error)")
        }
    }

    func testRequestTimesOutWhenExceedingTimeout() async {
        let endpoint = MockEndpoint()
        MockURLProtocol.delay = 3.0

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let _: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 1.0
            )
            XCTFail("Request should have timed out")
        } catch let error as RequestError {
            if case .connectionError(let urlError) = error {
                XCTAssertEqual(urlError.code, .timedOut)
            } else {
                XCTFail("Expected connectionError with timedOut, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRequestCompletesBeforeTimeout() async {
        let endpoint = MockEndpoint()
        MockURLProtocol.delay = 0.5

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":42}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 5.0
            )
            XCTAssertEqual(result.id, 42)
        } catch {
            XCTFail("Request should succeed: \(error)")
        }
    }

    func testDefaultTimeoutIsUsed() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self
            )
            XCTAssertEqual(result.id, 1)
        } catch {
            XCTFail("Request should succeed: \(error)")
        }
    }

    // MARK: - Retry Tests

    func testRetryOnConnectionError() async {
        let endpoint = MockEndpoint()

        var attemptCount = 0
        MockURLProtocol.requestHandler = { request in
            attemptCount += 1
            if attemptCount < 3 {
                throw URLError(.notConnectedToInternet)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 30.0,
                maxRetries: 3
            )
            XCTAssertEqual(result.id, 1)
            XCTAssertEqual(attemptCount, 3, "Should have made 3 attempts")
        } catch {
            XCTFail("Request should succeed after retries: \(error)")
        }
    }

    func testNoRetryOnNonConnectionError() async {
        let endpoint = MockEndpoint()

        var attemptCount = 0
        MockURLProtocol.requestHandler = { request in
            attemptCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"error\":\"bad request\"}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let _: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 30.0,
                maxRetries: 3
            )
            XCTFail("Request should fail with error")
        } catch {
            XCTAssertEqual(attemptCount, 1, "Should only make 1 attempt for non-connection errors")
        }
    }

    func testMaxRetriesExceeded() async {
        let endpoint = MockEndpoint()

        var attemptCount = 0
        MockURLProtocol.requestHandler = { _ in
            attemptCount += 1
            throw URLError(.networkConnectionLost)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let _: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 30.0,
                maxRetries: 2
            )
            XCTFail("Request should fail after max retries")
        } catch let error as RequestError {
            XCTAssertEqual(attemptCount, 3, "Should have made 3 attempts (1 initial + 2 retries)")
            if case .connectionError = error {
                XCTAssert(true)
            } else {
                XCTFail("Expected connectionError, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testZeroRetriesOnlyMakesOneAttempt() async {
        let endpoint = MockEndpoint()

        var attemptCount = 0
        MockURLProtocol.requestHandler = { _ in
            attemptCount += 1
            throw URLError(.timedOut)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let _: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 30.0,
                maxRetries: 0
            )
            XCTFail("Request should fail")
        } catch {
            XCTAssertEqual(attemptCount, 1, "Should only make 1 attempt with 0 retries")
        }
    }

    func testRetryWithDifferentConnectionErrors() async {
        let endpoint = MockEndpoint()

        let errors: [URLError.Code] = [.notConnectedToInternet, .timedOut, .networkConnectionLost]
        var attemptCount = 0

        MockURLProtocol.requestHandler = { request in
            attemptCount += 1
            if attemptCount <= errors.count {
                throw URLError(errors[attemptCount - 1])
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":99}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 30.0,
                maxRetries: 5
            )
            XCTAssertEqual(result.id, 99)
            XCTAssertEqual(attemptCount, 4, "Should have made 4 attempts")
        } catch {
            XCTFail("Request should succeed after retries: \(error)")
        }
    }

    func testTimeoutWithRetries() async {
        let endpoint = MockEndpoint()

        var attemptCount = 0
        MockURLProtocol.requestHandler = { request in
            attemptCount += 1
            if attemptCount == 1 {
                Thread.sleep(forTimeInterval: 2.0)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 1.0,
                maxRetries: 2
            )
            XCTAssertEqual(result.id, 1)
            XCTAssertEqual(attemptCount, 2, "Should retry after timeout")
        } catch {
            XCTFail("Request should succeed after retry: \(error)")
        }
    }

    // MARK: - Timeout Validation Tests

    func testNegativeTimeoutDoesNotCrash() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: -5.0
            )
            XCTAssertEqual(result.id, 1, "Should succeed with fallback timeout")
        } catch {
            XCTFail("Request should not crash with negative timeout: \(error)")
        }
    }

    func testZeroTimeoutDoesNotCrash() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 0
            )
            XCTAssertEqual(result.id, 1, "Should succeed with fallback timeout")
        } catch {
            XCTFail("Request should not crash with zero timeout: \(error)")
        }
    }

    func testInfinityTimeoutDoesNotCrash() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: Double.infinity
            )
            XCTAssertEqual(result.id, 1, "Should succeed with fallback timeout")
        } catch {
            XCTFail("Request should not crash with infinity timeout: \(error)")
        }
    }

    func testNaNTimeoutDoesNotCrash() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: Double.nan
            )
            XCTAssertEqual(result.id, 1, "Should succeed with fallback timeout")
        } catch {
            XCTFail("Request should not crash with NaN timeout: \(error)")
        }
    }

    func testVeryLargeTimeoutIsClamped() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: 1_000_000_000
            )
            XCTAssertEqual(result.id, 1, "Should succeed with clamped timeout")
        } catch {
            XCTFail("Request should not crash with very large timeout: \(error)")
        }
    }

    func testNegativeInfinityTimeoutDoesNotCrash() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(
                endpoint: endpoint,
                responseModel: TestModel.self,
                timeout: -Double.infinity
            )
            XCTAssertEqual(result.id, 1, "Should succeed with fallback timeout")
        } catch {
            XCTFail("Request should not crash with negative infinity timeout: \(error)")
        }
    }
}
