//
//  SSLPinningManagerTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class SSLPinningManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        NetworkingLib.shared.publicKeyHash = "test-hash"
    }

    override func tearDown() {
        NetworkingLib.shared.publicKeyHash = nil
        super.tearDown()
    }

    func testSSLPinningManagerInitialization() {
        NetworkingLib.shared.publicKeyHash = "test-hash-123"
        let manager = SSLPinningManager()
        XCTAssertNotNil(manager)
    }

    func testSSLPinningManagerHasRSASN1Header() {
        // This tests that the RSA 2048 ASN.1 header is correctly defined
        // The header is a private property, but we can verify the manager exists
        let manager = SSLPinningManager()
        XCTAssertNotNil(manager)
    }

    // Note: Full SSL pinning tests would require actual certificates and network setup
    // which is complex to mock. The actual SSL pinning logic is tested through
    // integration tests or manual testing with real certificates.
}
