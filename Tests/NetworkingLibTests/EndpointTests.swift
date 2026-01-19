//
//  EndpointTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class EndpointTests: XCTestCase {

    private struct SimpleTestEndpoint: Endpoint {
        var path: String = "/test"
        var method: RequestMethod = .get
        var header: [String: String]?
        var body: Data?
        var parameters: [URLQueryItem] = []
        var mockFile: String?
        var bundle: Bundle?
    }

    private struct RequestModel: Codable {
        let userId: Int
        let userName: String
        let createdAt: String
    }

    private struct TestEndpointWithBody: Endpoint {
        var path: String = "/test"
        var method: RequestMethod = .post
        var header: [String: String]?
        var body: Data? {
            let model = RequestModel(userId: 123, userName: "testuser", createdAt: "2024-01-01")
            return try? encoder.encode(model)
        }
        var parameters: [URLQueryItem] = []
        var mockFile: String?
        var bundle: Bundle?
    }

    func testEndpointDefaultScheme() {
        let endpoint = MockEndpoint()
        XCTAssertEqual(endpoint.scheme, "https")
    }

    func testEndpointDefaultHost() {
        NetworkingLib.shared.host = "test.example.com"
        // MockEndpoint has a hardcoded host, so we need to create one without specifying host
        // to test the default behavior. Since MockEndpoint always sets host, we test that
        // a custom endpoint would use the default.
        let endpoint = SimpleTestEndpoint()
        XCTAssertEqual(endpoint.host, "test.example.com")
    }

    func testEndpointCustomHost() {
        NetworkingLib.shared.host = "default.example.com"
        let endpoint = MockEndpoint(host: "custom.example.com")
        XCTAssertEqual(endpoint.host, "custom.example.com")
    }

    func testEndpointDefaultEncoder() {
        let endpoint = MockEndpoint()
        XCTAssertNotNil(endpoint.encoder)
    }

    func testEndpointDefaultEncoderUsesSnakeCase() {
        // Create an endpoint that uses the default encoder (not MockEndpoint which overrides it)
        let endpoint = SimpleTestEndpoint()

        // Check that the encoder uses snake_case conversion
        if case .convertToSnakeCase = endpoint.encoder.keyEncodingStrategy {
            XCTAssert(true)
        } else {
            XCTFail("Default encoder should use convertToSnakeCase strategy")
        }
    }

    func testEndpointEncoderConvertsToSnakeCase() throws {
        // Create an endpoint that uses the default encoder
        let endpoint = TestEndpointWithBody()

        guard let bodyData = endpoint.body else {
            XCTFail("Body should be encoded")
            return
        }

        // Decode the JSON to verify it's in snake_case
        let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertNotNil(json)

        // Verify keys are in snake_case
        XCTAssertNotNil(json?["user_id"])
        XCTAssertNotNil(json?["user_name"])
        XCTAssertNotNil(json?["created_at"])
        XCTAssertNil(json?["userId"])
        XCTAssertNil(json?["userName"])
        XCTAssertNil(json?["createdAt"])

        // Verify values
        XCTAssertEqual(json?["user_id"] as? Int, 123)
        XCTAssertEqual(json?["user_name"] as? String, "testuser")
        XCTAssertEqual(json?["created_at"] as? String, "2024-01-01")
    }

    func testEndpointWithQueryParameters() {
        let endpoint = MockEndpoint(parameters: [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "10")
        ])

        XCTAssertEqual(endpoint.parameters.count, 2)
        XCTAssertEqual(endpoint.parameters.first?.name, "page")
        XCTAssertEqual(endpoint.parameters.first?.value, "1")
    }

    func testEndpointWithHeaders() {
        let headers = ["Authorization": "Bearer token", "Content-Type": "application/json"]
        let endpoint = MockEndpoint(header: headers)

        XCTAssertEqual(endpoint.header?["Authorization"], "Bearer token")
        XCTAssertEqual(endpoint.header?["Content-Type"], "application/json")
    }

    func testEndpointWithBody() {
        let bodyData = Data("{\"key\":\"value\"}".utf8)
        let endpoint = MockEndpoint(body: bodyData)

        XCTAssertEqual(endpoint.body, bodyData)
    }

    func testEndpointWithAllMethods() {
        let methods: [RequestMethod] = [.get, .post, .put, .patch, .delete]

        for method in methods {
            let endpoint = MockEndpoint(method: method)
            XCTAssertEqual(endpoint.method, method)
        }
    }
}
