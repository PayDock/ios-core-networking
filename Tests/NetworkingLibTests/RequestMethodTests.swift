//
//  RequestMethodTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class RequestMethodTests: XCTestCase {

    func testRequestMethodRawValues() {
        XCTAssertEqual(RequestMethod.get.rawValue, "GET")
        XCTAssertEqual(RequestMethod.post.rawValue, "POST")
        XCTAssertEqual(RequestMethod.put.rawValue, "PUT")
        XCTAssertEqual(RequestMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(RequestMethod.delete.rawValue, "DELETE")
    }

    func testAllRequestMethods() {
        let methods: [RequestMethod] = [.get, .post, .put, .patch, .delete]
        let rawValues = methods.map { $0.rawValue }

        XCTAssertEqual(rawValues, ["GET", "POST", "PUT", "PATCH", "DELETE"])
    }
}
