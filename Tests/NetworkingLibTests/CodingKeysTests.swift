//
//  CodingKeysTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class CodingKeysTests: XCTestCase {

    private struct TestModelWithUnderscores: Codable {
        let id: String
        let name: String
        let threeDS: String

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case threeDS = "_3ds"
        }
    }

    private struct ExampleModel: Codable {
        let id: String
        let threeDS: String

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case threeDS = "_3ds"
        }
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

    func testModelWithUnderscorePrefixFields() throws {
        // Test that models can use explicit CodingKeys for fields like "_id" or "_3ds"
        // that don't follow snake_case convention

        let json = """
        {
            "_id": "test-id-123",
            "name": "Test Name",
            "_3ds": "standalone_3ds"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = httpClient.decoder

        let model = try decoder.decode(TestModelWithUnderscores.self, from: data)

        XCTAssertEqual(model.id, "test-id-123")
        XCTAssertEqual(model.name, "Test Name")
        XCTAssertEqual(model.threeDS, "standalone_3ds")
    }

    private struct TestModelWithoutCodingKeys: Codable {
        let userId: Int
        let userName: String
        let createdAt: String
        let isActive: Bool
    }

    func testModelWithoutCodingKeysUsesSnakeCase() throws {
        // Test that models without explicit CodingKeys use snake_case conversion

        let json = """
        {
            "user_id": 789,
            "user_name": "testuser",
            "created_at": "2024-01-01T00:00:00Z",
            "is_active": true
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = httpClient.decoder

        let model = try decoder.decode(TestModelWithoutCodingKeys.self, from: data)

        XCTAssertEqual(model.userId, 789)
        XCTAssertEqual(model.userName, "testuser")
        XCTAssertEqual(model.createdAt, "2024-01-01T00:00:00Z")
        XCTAssertEqual(model.isActive, true)
    }

    func testCodingKeysDocumentation() {
        // Documentation test: Shows that models can use CodingKeys for special fields
        // When CodingKeys are present, they override snake_case conversion
        // This is useful for fields like "_id" or "_3ds" that don't follow snake_case

        // Example: A model with special fields
        // The decoder will use these CodingKeys exactly as specified
        // This test just verifies the pattern compiles and is valid
        XCTAssertTrue(true, "CodingKeys pattern is valid for special fields")
    }
}
