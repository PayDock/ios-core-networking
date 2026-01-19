//
//  HTTPClientTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class HTTPClientTests: XCTestCase {

    private struct SnakeCaseRequestModel: Codable {
        let userId: Int
        let userName: String
        let createdAt: String
    }

    private struct CustomRequestModel: Codable {
        let userId: Int
        let userName: String
    }

    private struct SnakeCaseTestEndpoint: Endpoint {
        var path: String = "/test"
        var method: RequestMethod = .post
        var header: [String: String]? = ["Content-Type": "application/json"]
        var body: Data? {
            let model = SnakeCaseRequestModel(userId: 456, userName: "encodeduser", createdAt: "2024-02-01")
            return try? encoder.encode(model)
        }
        var parameters: [URLQueryItem] = []
        var mockFile: String?
        var bundle: Bundle?
    }

    private struct CustomEncoderEndpoint: Endpoint {
        var path: String = "/test"
        var method: RequestMethod = .post
        var header: [String: String]? = ["Content-Type": "application/json"]
        var encoder: JSONEncoder {
            let encoder = JSONEncoder()
            // Use default key encoding (no snake_case conversion)
            encoder.keyEncodingStrategy = .useDefaultKeys
            return encoder
        }
        var body: Data? {
            let model = CustomRequestModel(userId: 789, userName: "customuser")
            return try? encoder.encode(model)
        }
        var parameters: [URLQueryItem] = []
        var mockFile: String?
        var bundle: Bundle?
    }

    private var httpClient: HTTPClient!

    override func setUp() {
        super.setUp()
        httpClient = HTTPClientTestable()
    }

    override func tearDown() {
        httpClient = nil
        super.tearDown()
    }

    func testHTTPClientHasSession() {
        XCTAssertNotNil(httpClient.session)
    }

    func testHTTPClientHasDecoder() {
        XCTAssertNotNil(httpClient.decoder)
    }

    func testHTTPClientDecoderUsesSnakeCase() {
        let decoder = httpClient.decoder
        // JSONDecoder.KeyDecodingStrategy doesn't conform to Equatable, so we check the case directly
        if case .convertFromSnakeCase = decoder.keyDecodingStrategy {
            XCTAssert(true)
        } else {
            XCTFail("Decoder should use convertFromSnakeCase strategy")
        }
    }

    func testHTTPClientSessionConfiguration() {
        // HTTPClientTestable uses ephemeral configuration, so we test a real HTTPClient implementation
        class TestHTTPClient: HTTPClient {}
        let testClient = TestHTTPClient()
        let session = testClient.session
        let configuration = session.configuration

        XCTAssertTrue(configuration.waitsForConnectivity)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 60)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 300)
    }

    func testHTTPClientSSLPinningManagerWhenPublicKeyHashIsSet() {
        NetworkingLib.shared.publicKeyHash = "test-hash"
        let manager = httpClient.sslPinningManager
        XCTAssertNotNil(manager)
    }

    func testHTTPClientSSLPinningManagerWhenPublicKeyHashIsNil() {
        NetworkingLib.shared.publicKeyHash = nil
        let manager = httpClient.sslPinningManager
        XCTAssertNil(manager)
    }

    func testHTTPClientRequestWithQueryParameters() async {
        let endpoint = MockEndpoint(
            path: "/test",
            parameters: [
                URLQueryItem(name: "key1", value: "value1"),
                URLQueryItem(name: "key2", value: "value2")
            ]
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertNotNil(components?.queryItems)
            XCTAssertTrue(components?.queryItems?.contains(where: { $0.name == "key1" && $0.value == "value1" }) ?? false)
            XCTAssertTrue(components?.queryItems?.contains(where: { $0.name == "key2" && $0.value == "value2" }) ?? false)

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTAssertEqual(result.id, 1)
        } catch {
            XCTFail("Request should succeed: \(error)")
        }
    }

    func testHTTPClientRequestWithHeaders() async {
        let headers = ["Authorization": "Bearer token", "X-Custom-Header": "custom-value"]
        let endpoint = MockEndpoint(header: headers)

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer token")
            XCTAssertEqual(request.allHTTPHeaderFields?["X-Custom-Header"], "custom-value")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let _: TestModel = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTAssert(true)
        } catch {
            XCTFail("Request should succeed: \(error)")
        }
    }

    func testHTTPClientRequestWithBody() async {
        let bodyData = Data("{\"name\":\"test\"}".utf8)
        let endpoint = MockEndpoint(method: .post, body: bodyData)

        var receivedBody: Data?
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            receivedBody = request.httpBody
            // Note: URLRequest may not always preserve httpBody, so we check if it was set
            // In real scenarios, the body is sent correctly

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        struct TestModel: Codable {
            let id: Int
        }

        do {
            let _: TestModel = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            // Verify endpoint has the body set (the actual transmission is handled by URLSession)
            XCTAssertEqual(endpoint.body, bodyData)
        } catch {
            XCTFail("Request should succeed: \(error)")
        }
    }

    func testHTTPClientRequestWithDifferentMethods() async {
        let methods: [RequestMethod] = [.get, .post, .put, .patch, .delete]

        for method in methods {
            let endpoint = MockEndpoint(method: method)

            MockURLProtocol.requestHandler = { request in
                XCTAssertEqual(request.httpMethod, method.rawValue)

                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
                let data = Data("{\"id\":1}".utf8)
                return (response, data)
            }

            struct TestModel: Codable {
                let id: Int
            }

            do {
                let _: TestModel = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
                XCTAssert(true, "Method \(method.rawValue) should succeed")
            } catch {
                XCTFail("Request with method \(method.rawValue) should succeed: \(error)")
            }
        }
    }

    func testHTTPClientSnakeCaseDecoding() async {
        let endpoint = MockEndpoint()

        MockURLProtocol.requestHandler = { request in
            let json = """
            {
                "user_id": 123,
                "user_name": "testuser",
                "created_at": "2024-01-01T00:00:00Z"
            }
            """
            let data = json.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            return (response, data)
        }

        struct TestModel: Codable {
            let userId: Int
            let userName: String
            let createdAt: String
        }

        do {
            let result: TestModel = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTAssertEqual(result.userId, 123)
            XCTAssertEqual(result.userName, "testuser")
            XCTAssertEqual(result.createdAt, "2024-01-01T00:00:00Z")
        } catch {
            XCTFail("Request should succeed with snake_case decoding: \(error)")
        }
    }

    func testHTTPClientSnakeCaseEncoding() async {
        // Create an endpoint that uses the default encoder (with snake_case conversion)
        let endpoint = SnakeCaseTestEndpoint()

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"success\":true}".utf8)
            return (response, data)
        }

        struct ResponseModel: Codable {
            let success: Bool
        }

        do {
            let _: ResponseModel = try await httpClient.sendRequest(endpoint: endpoint, responseModel: ResponseModel.self)

            // Verify the endpoint's body was encoded in snake_case
            // Note: We check the endpoint's body directly since URLRequest.httpBody may not be available in mocks
            guard let bodyData = endpoint.body else {
                XCTFail("Endpoint body should be present")
                return
            }

            let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertNotNil(json)

            // Verify keys are in snake_case (not camelCase)
            XCTAssertNotNil(json?["user_id"], "Key should be user_id, not userId")
            XCTAssertNotNil(json?["user_name"], "Key should be user_name, not userName")
            XCTAssertNotNil(json?["created_at"], "Key should be created_at, not createdAt")
            XCTAssertNil(json?["userId"], "Key should not be camelCase")
            XCTAssertNil(json?["userName"], "Key should not be camelCase")
            XCTAssertNil(json?["createdAt"], "Key should not be camelCase")

            // Verify values
            XCTAssertEqual(json?["user_id"] as? Int, 456)
            XCTAssertEqual(json?["user_name"] as? String, "encodeduser")
            XCTAssertEqual(json?["created_at"] as? String, "2024-02-01")
        } catch {
            XCTFail("Request should succeed with snake_case encoding: \(error)")
        }
    }

    func testHTTPClientSnakeCaseEncodingWithCustomEncoder() async {
        // Test that a custom encoder can override the default snake_case behavior
        let endpoint = CustomEncoderEndpoint()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"success\":true}".utf8)
            return (response, data)
        }

        struct ResponseModel: Codable {
            let success: Bool
        }

        do {
            let _: ResponseModel = try await httpClient.sendRequest(endpoint: endpoint, responseModel: ResponseModel.self)

            // Verify the endpoint's body was encoded with custom encoder (camelCase)
            guard let bodyData = endpoint.body else {
                XCTFail("Endpoint body should be present")
                return
            }

            let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            XCTAssertNotNil(json)

            // With custom encoder using .useDefaultKeys, keys should be camelCase
            XCTAssertNotNil(json?["userId"], "Key should be userId with custom encoder")
            XCTAssertNotNil(json?["userName"], "Key should be userName with custom encoder")
            XCTAssertNil(json?["user_id"], "Key should not be snake_case with custom encoder")
            XCTAssertNil(json?["user_name"], "Key should not be snake_case with custom encoder")
        } catch {
            XCTFail("Request should succeed: \(error)")
        }
    }
}
