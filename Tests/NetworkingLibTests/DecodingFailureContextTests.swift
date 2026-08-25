//
//  DecodingFailureContextTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class DecodingFailureContextTests: XCTestCase {

    // Nested model mirroring a typical response envelope, so we can assert coding paths.
    private struct Outer: Decodable { let resource: Middle }
    private struct Middle: Decodable { let data: Inner }
    private struct Inner: Decodable {
        let tempToken: String
        let amount: Int
    }

    private func decodingError(from json: String) -> DecodingError {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            _ = try decoder.decode(Outer.self, from: Data(json.utf8))
            XCTFail("expected decode to fail")
            return DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "unreachable"))
        } catch let error as DecodingError {
            return error
        } catch {
            XCTFail("expected a DecodingError, got \(error)")
            return DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "unreachable"))
        }
    }

    func testKeyNotFound_IdentifiesFieldAndPath() {
        let error = decodingError(from: #"{"resource":{"data":{"amount":5}}}"#)
        let context = DecodingFailureContext(error)

        XCTAssertEqual(context.kind, .keyNotFound)
        XCTAssertEqual(context.codingPath, "resource.data.tempToken")
        XCTAssertTrue(context.summary.contains("keyNotFound"))
        XCTAssertTrue(context.summary.contains("tempToken"))
        XCTAssertTrue(context.summary.contains("resource.data"))
    }

    func testTypeMismatch_IdentifiesFieldAndPath() {
        let error = decodingError(from: #"{"resource":{"data":{"temp_token":"t","amount":"NaN"}}}"#)
        let context = DecodingFailureContext(error)

        XCTAssertEqual(context.kind, .typeMismatch)
        XCTAssertEqual(context.codingPath, "resource.data.amount")
        XCTAssertTrue(context.summary.contains("typeMismatch"))
        XCTAssertTrue(context.summary.contains("amount"))
    }

    func testValueNotFound_IdentifiesFieldAndPath() {
        let error = decodingError(from: #"{"resource":{"data":{"temp_token":"t","amount":null}}}"#)
        let context = DecodingFailureContext(error)

        XCTAssertEqual(context.kind, .valueNotFound)
        XCTAssertEqual(context.codingPath, "resource.data.amount")
        XCTAssertTrue(context.summary.contains("amount"))
    }

    func testDataCorrupted_AtRoot() {
        let decoder = JSONDecoder()
        let error: DecodingError
        do {
            _ = try decoder.decode(Outer.self, from: Data("not json".utf8))
            return XCTFail("expected decode to fail")
        } catch let decodeError as DecodingError {
            error = decodeError
        } catch {
            return XCTFail("expected a DecodingError")
        }

        let context = DecodingFailureContext(error)
        XCTAssertEqual(context.kind, .dataCorrupted)
        XCTAssertEqual(context.codingPath, "")
        XCTAssertTrue(context.summary.contains("dataCorrupted"))
    }

    func testContextIsEquatableValueType() {
        let firstContext = DecodingFailureContext(kind: .keyNotFound, codingPath: "a.b", summary: "s", debugDescription: "d")
        let secondContext = DecodingFailureContext(kind: .keyNotFound, codingPath: "a.b", summary: "s", debugDescription: "d")
        XCTAssertEqual(firstContext, secondContext)
    }
}
