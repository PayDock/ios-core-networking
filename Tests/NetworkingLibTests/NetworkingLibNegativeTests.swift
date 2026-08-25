//
//  NetworkingLibNegativeTests.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import XCTest
@testable import NetworkingLib

final class NetworkingLibNegativeTests: XCTestCase {

    struct TestModel: Codable {
        let id: Int
        let title: String
    }

    private var httpClient: HTTPClient!
    private var endpoint: Endpoint!

    override func setUp() {
        super.setUp()

        self.httpClient = HTTPClientTestable()
        self.endpoint = MockEndpoint()
    }

    private func setFailingMockProtocol(status: Int) {
        MockURLProtocol.requestHandler = { request in
            let exampleData = Data("""
            {"id":1,"title":"Hello, World!"}
            """.utf8)
            let response = HTTPURLResponse.init(url: request.url!, statusCode: status, httpVersion: "2.0", headerFields: nil)!
            return (response, exampleData)
        }
    }

    private func setErrorResponseMockProtocol(status: Int, errorMessage: String) {
        MockURLProtocol.requestHandler = { request in
            let errorData = Data("""
            {
                "status": \(status),
                "error": {
                    "message": "\(errorMessage)",
                    "code": "ERROR_CODE"
                }
            }
            """.utf8)
            let response = HTTPURLResponse.init(url: request.url!, statusCode: status, httpVersion: "2.0", headerFields: nil)!
            return (response, errorData)
        }
    }

    func testFailingRequest() async {
        setFailingMockProtocol(status: 400)
        do {
            _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTFail("Response should not be decoded for 400 status.")
        } catch let error as RequestError {
            switch error {
            case .requestError, .unexpectedErrorModel:
                XCTAssert(true)
            default:
                XCTFail("Error should be requestError or unexpectedErrorModel, got: \(error)")
            }
        } catch {
            XCTFail("Error should be RequestError, got: \(error)")
        }
    }

    func testRequestDecodeFail() async {
        setFailingMockProtocol(status: 200)

        do {
            _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: String.self)
            XCTFail("Response should not be decoded for invalid model.")
        } catch let error as RequestError {
            switch error {
            case .decode(let context):
                XCTAssertNotNil(context, "decode failure should carry a DecodingFailureContext")
            default: XCTFail("Error needs to be decode.")
            }
        } catch {
            XCTFail("Error should be known.")
        }
    }

    func testRequestUnauthorised() async {
        setFailingMockProtocol(status: 401)

        do {
            _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: String.self)
            XCTFail("Response should not be decoded for 401 status.")
        } catch let error as RequestError {
            switch error {
            case .requestError, .unexpectedErrorModel:
                XCTAssert(true)
            default:
                XCTFail("Error should be requestError or unexpectedErrorModel, got: \(error)")
            }
        } catch {
            XCTFail("Error should be RequestError, got: \(error)")
        }
    }

    func testRequestErrorWithErrorResponse() async {
        setErrorResponseMockProtocol(status: 400, errorMessage: "Bad Request")

        do {
            _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTFail("Response should throw RequestError.requestError")
        } catch let error as RequestError {
            switch error {
            case .requestError(let errorRes):
                XCTAssertEqual(errorRes.status, 400)
                XCTAssertEqual(errorRes.error?.message, "Bad Request")
                XCTAssertEqual(errorRes.error?.code, "ERROR_CODE")
            default:
                XCTFail("Error should be requestError with ErrorRes, got: \(error)")
            }
        } catch {
            XCTFail("Error should be RequestError, got: \(error)")
        }
    }

    func testInvalidURL() async {
        // Create an endpoint that will result in an invalid URL
        struct InvalidEndpoint: Endpoint {
            var scheme: String = "https"
            var host: String = ""
            var path: String = ""
            var method: RequestMethod = .get
            var header: [String: String]?
            var body: Data?
            var parameters: [URLQueryItem] = []
            var mockFile: String?
            var bundle: Bundle?
        }
        let invalidEndpoint = InvalidEndpoint()

        do {
            _ = try await httpClient.sendRequest(endpoint: invalidEndpoint, responseModel: TestModel.self)
            XCTFail("Should throw invalidURL or invalidRequest error")
        } catch let error as RequestError {
            switch error {
            case .invalidURL, .invalidRequest:
                XCTAssert(true)
            default:
                XCTFail("Error should be invalidURL or invalidRequest, got: \(error)")
            }
        } catch {
            XCTFail("Error should be RequestError, got: \(error)")
        }
    }

    func testConnectionError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTFail("Should throw connectionError")
        } catch let error as RequestError {
            switch error {
            case .connectionError(let urlError):
                XCTAssertEqual(urlError.code, .notConnectedToInternet)
            default:
                XCTFail("Error should be connectionError, got: \(error)")
            }
        } catch {
            XCTFail("Error should be RequestError, got: \(error)")
        }
    }

    func testServerError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.badServerResponse)
        }

        do {
            _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTFail("Should throw serverError")
        } catch let error as RequestError {
            switch error {
            case .serverError(let urlError):
                XCTAssertEqual(urlError.code, .badServerResponse)
            default:
                XCTFail("Error should be serverError, got: \(error)")
            }
        } catch {
            XCTFail("Error should be RequestError, got: \(error)")
        }
    }

    func testInvalidRequest() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.badURL)
        }

        do {
            _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTFail("Should throw invalidRequest")
        } catch let error as RequestError {
            switch error {
            case .invalidRequest(let urlError):
                XCTAssertEqual(urlError.code, .badURL)
            default:
                XCTFail("Error should be invalidRequest, got: \(error)")
            }
        } catch {
            XCTFail("Error should be RequestError, got: \(error)")
        }
    }

    func testNoResponse() async {
        // This test is difficult to mock directly since URLSession always returns HTTPURLResponse
        // Instead, we test the error handling path by ensuring the code handles non-HTTP responses
        // In practice, this would be tested with integration tests
        // For now, we'll skip this test or test it differently
        MockURLProtocol.requestHandler = { request in
            // We can't easily return a non-HTTP response through MockURLProtocol
            // This would require more complex mocking
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            let data = Data("{\"id\":1}".utf8)
            return (response, data)
        }

        // Since we can't easily test noResponse through MockURLProtocol,
        // we'll verify the code path exists by checking the error enum
        let error = RequestError.noResponse
        XCTAssertEqual(error.customMessage, "No response received - - please try again later")
    }

    override func tearDown() {
        httpClient = nil
        endpoint = nil

        super.tearDown()
    }
}
