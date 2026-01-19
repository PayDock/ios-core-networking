//
//  NetworkingLibTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class NetworkingLibTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset shared instance state
        NetworkingLib.shared.host = ""
        NetworkingLib.shared.publicKeyHash = nil
    }

    override func tearDown() {
        NetworkingLib.shared.host = ""
        NetworkingLib.shared.publicKeyHash = nil
        super.tearDown()
    }

    func testNetworkingLibSharedInstance() {
        let instance1 = NetworkingLib.shared
        let instance2 = NetworkingLib.shared
        XCTAssertTrue(instance1 === instance2, "Should return the same singleton instance")
    }

    func testNetworkingLibHostProperty() {
        NetworkingLib.shared.host = "api.example.com"
        XCTAssertEqual(NetworkingLib.shared.host, "api.example.com")
    }

    func testNetworkingLibPublicKeyHashProperty() {
        NetworkingLib.shared.publicKeyHash = "test-hash-123"
        XCTAssertEqual(NetworkingLib.shared.publicKeyHash, "test-hash-123")
    }

    func testNetworkingLibPublicKeyHashCanBeNil() {
        NetworkingLib.shared.publicKeyHash = "test-hash"
        NetworkingLib.shared.publicKeyHash = nil
        XCTAssertNil(NetworkingLib.shared.publicKeyHash)
    }
}
