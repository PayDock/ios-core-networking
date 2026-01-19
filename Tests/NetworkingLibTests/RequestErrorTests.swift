//
//  RequestErrorTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class RequestErrorTests: XCTestCase {

    func testConnectionErrorCustomMessage() {
        let urlError = URLError(.notConnectedToInternet)
        let error = RequestError.connectionError(urlError)
        XCTAssertEqual(error.customMessage, urlError.localizedDescription)
    }

    func testDecodeCustomMessage() {
        let error = RequestError.decode
        XCTAssertEqual(error.customMessage, "Error while mapping a JSON response")
    }

    func testInvalidRequestCustomMessage() {
        let urlError = URLError(.badURL)
        let error = RequestError.invalidRequest(urlError)
        XCTAssertEqual(error.customMessage, urlError.localizedDescription)
    }

    func testInvalidURLCustomMessage() {
        let error = RequestError.invalidURL
        XCTAssertEqual(error.customMessage, "Invalid URL - please try again later")
    }

    func testNoResponseCustomMessage() {
        let error = RequestError.noResponse
        XCTAssertEqual(error.customMessage, "No response received - - please try again later")
    }

    func testServerErrorCustomMessage() {
        let urlError = URLError(.badServerResponse)
        let error = RequestError.serverError(urlError)
        XCTAssertEqual(error.customMessage, urlError.localizedDescription)
    }

    func testUnexpectedErrorModelCustomMessage() {
        let error = RequestError.unexpectedErrorModel
        XCTAssertEqual(error.customMessage, "Unexpected error model - unable to decode JSON")
    }

    func testRequestErrorCustomMessage() {
        let errorRes = ErrorRes(
            status: 400,
            error: ErrorObj(message: "Test error message", code: "TEST_CODE", details: nil),
            resource: nil,
            errorSummary: nil
        )
        let error = RequestError.requestError(errorRes)
        XCTAssertEqual(error.customMessage, "Test error message")
    }

    func testRequestErrorCustomMessageWithNilMessage() {
        let errorRes = ErrorRes(
            status: 400,
            error: ErrorObj(message: nil, code: "TEST_CODE", details: nil),
            resource: nil,
            errorSummary: nil
        )
        let error = RequestError.requestError(errorRes)
        XCTAssertEqual(error.customMessage, "Request error - please try again later")
    }

    func testUnknownCustomMessage() {
        let urlError = URLError(.unknown)
        let error = RequestError.unknown(urlError)
        XCTAssertEqual(error.customMessage, urlError.localizedDescription)
    }
}
