//
//  ErrorResTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class ErrorResTests: XCTestCase {

    private var httpClient: HTTPClient!

    override func setUp() {
        super.setUp()
        httpClient = HTTPClientTestable()
    }

    override func tearDown() {
        httpClient = nil
        super.tearDown()
    }

    func testErrorResDecoding() throws {
        let json = """
        {
            "status": 400,
            "error": {
                "message": "Invalid request",
                "code": "INVALID_REQUEST",
                "details": {
                    "path": "",
                    "messages": []
                }
            },
            "resource": {
                "type": "charge"
            },
            "error_summary": {
                "message": "Summary message",
                "code": "SUMMARY_CODE",
                "status_code": "400",
                "status_code_description": "Bad Request",
                "details": {
                    "messages": [
                        {
                            "gateway_specific_code": "GATEWAY_CODE",
                            "gateway_specific_description": "Gateway error",
                            "description": "Error 1"
                        },
                        {
                            "description": "Error 2"
                        }
                    ]
                }
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = httpClient.decoder
        let errorRes = try decoder.decode(ErrorRes.self, from: data)

        verifyBasicErrorRes(errorRes)
        verifyErrorSummary(errorRes.errorSummary)
    }

    private func verifyBasicErrorRes(_ errorRes: ErrorRes) {
        XCTAssertEqual(errorRes.status, 400)
        XCTAssertEqual(errorRes.error?.message, "Invalid request")
        XCTAssertEqual(errorRes.error?.code, "INVALID_REQUEST")
        XCTAssertEqual(errorRes.resource?.type, "charge")
    }

    private func verifyErrorSummary(_ errorSummary: ErrorSummary?) {
        XCTAssertNotNil(errorSummary, "errorSummary should be decoded")
        guard let errorSummary = errorSummary else {
            return
        }

        XCTAssertEqual(errorSummary.message, "Summary message")
        XCTAssertEqual(errorSummary.code, "SUMMARY_CODE")
        XCTAssertEqual(errorSummary.statusCode, "400")
        XCTAssertEqual(errorSummary.statusCodeDescription, "Bad Request")

        XCTAssertNotNil(errorSummary.details, "ErrorSummary details should be decoded")
        guard let details = errorSummary.details else {
            return
        }

        XCTAssertEqual(details.path, nil)
        XCTAssertEqual(details.messages?.count, 2)
        XCTAssertEqual(details.messages?.first?.gatewaySpecificCode, "GATEWAY_CODE")
        XCTAssertEqual(details.messages?.first?.gatewaySpecificDescription, "Gateway error")
        XCTAssertEqual(details.messages?.first?.description, "Error 1")
    }

    func testErrorResDecodingMinimal() throws {
        let json = """
        {
            "status": 500
        }
        """

        let data = json.data(using: .utf8)!
        // Use the actual HTTPClient decoder
        let decoder = httpClient.decoder

        let errorRes = try decoder.decode(ErrorRes.self, from: data)

        XCTAssertEqual(errorRes.status, 500)
        XCTAssertNil(errorRes.error)
        XCTAssertNil(errorRes.resource)
        XCTAssertNil(errorRes.errorSummary)
    }

    func testErrorResEncoding() throws {
        let errorRes = ErrorRes(
            status: 404,
            error: ErrorObj(message: "Not found", code: "NOT_FOUND", details: nil),
            resource: Resource(type: "user"),
            errorSummary: nil
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(errorRes)

        // Use the actual HTTPClient decoder
        let decoder = httpClient.decoder
        let decoded = try decoder.decode(ErrorRes.self, from: data)

        XCTAssertEqual(decoded.status, 404)
        XCTAssertEqual(decoded.error?.message, "Not found")
        XCTAssertEqual(decoded.error?.code, "NOT_FOUND")
        XCTAssertEqual(decoded.resource?.type, "user")
    }

    func testErrorResDecodingWithActualAPIResponse() throws {
        // Test with actual API response structure from wallet capture error
        let json = """
        {
            "status": 400,
            "error": {
                "message": "Transaction Declined",
                "code": "transaction_declined",
                "details": {
                    "path": "",
                    "messages": [
                        {
                            "gateway_specific_code": "DECLINED",
                            "gateway_specific_description": "The requested operation was not successful",
                            "description": "Transaction Declined",
                            "status_code": null,
                            "status_code_description": null
                        }
                    ]
                }
            },
            "resource": {
                "type": "charge",
                "data": {
                    "_id": "696df56dc439f020f63f2df8",
                    "amount": 10,
                    "currency": "AUD"
                }
            },
            "error_summary": {
                "message": "Transaction Declined",
                "code": "transaction_declined",
                "details": {
                    "messages": [
                        {
                            "gateway_specific_code": "DECLINED",
                            "gateway_specific_description": "The requested operation was not successful",
                            "description": "Transaction Declined",
                            "status_code": null,
                            "status_code_description": null
                        }
                    ]
                }
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = httpClient.decoder
        let errorRes = try decoder.decode(ErrorRes.self, from: data)

        verifyActualAPIResponseBasic(errorRes)
        verifyActualAPIResponseErrorDetails(errorRes.error?.details)
        verifyActualAPIResponseErrorSummary(errorRes.errorSummary)
    }

    private func verifyActualAPIResponseBasic(_ errorRes: ErrorRes) {
        XCTAssertEqual(errorRes.status, 400)
        XCTAssertEqual(errorRes.error?.message, "Transaction Declined")
        XCTAssertEqual(errorRes.error?.code, "transaction_declined")
        XCTAssertEqual(errorRes.resource?.type, "charge")
    }

    private func verifyActualAPIResponseErrorDetails(_ details: ErrorDetails?) {
        XCTAssertNotNil(details)
        XCTAssertEqual(details?.path, "")
        XCTAssertEqual(details?.messages?.count, 1)
        XCTAssertEqual(details?.messages?.first?.gatewaySpecificCode, "DECLINED")
        XCTAssertEqual(details?.messages?.first?.gatewaySpecificDescription, "The requested operation was not successful")
        XCTAssertEqual(details?.messages?.first?.description, "Transaction Declined")
    }

    private func verifyActualAPIResponseErrorSummary(_ errorSummary: ErrorSummary?) {
        XCTAssertNotNil(errorSummary)
        XCTAssertEqual(errorSummary?.message, "Transaction Declined")
        XCTAssertEqual(errorSummary?.code, "transaction_declined")
        XCTAssertNotNil(errorSummary?.details)
        XCTAssertEqual(errorSummary?.details?.messages?.count, 1)
        XCTAssertEqual(errorSummary?.details?.messages?.first?.gatewaySpecificCode, "DECLINED")
    }
}
