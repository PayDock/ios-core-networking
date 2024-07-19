//
//  NetworkingLibNegativeTests.swift
//  NetworkingLibTests
//
//  Copyright © 2024 Paydock Ltd.
//  Created by Domagoj Grizelj on 18.07.2024..
//

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
            let exampleData =
            """
            {"id":1,"title":"Hello, World!"}
            """
            .data(using: .utf8)!
            let response = HTTPURLResponse.init(url: request.url!, statusCode: status, httpVersion: "2.0", headerFields: nil)!
            return (response, exampleData)
        }
    }

    func testFailingRequest() async {
        setFailingMockProtocol(status: 400)
        do {
            let _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTFail("Response should not be decoded for 400 status.")
        } catch let error as RequestError {
            switch error {
            case .unexpectedStatusCode : XCTAssert(true)
            default: XCTFail("Error need to be an unexpected status code.")
            }
        } catch {
            XCTFail("Error should be known.")
        }
    }

    func testRequestDecodeFail() async {
        setFailingMockProtocol(status: 200)

        do {
            let _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: String.self)
            XCTFail("Response should not be decoded for invalid model.")
        } catch let error as RequestError {
            switch error {
            case .decode : XCTAssert(true)
            default: XCTFail("Error needs to be decode.")
            }
        } catch {
            XCTFail("Error should be known.")
        }
    }

    func testRequestUnauthorised() async {
        setFailingMockProtocol(status: 401)

        do {
            let _ = try await httpClient.sendRequest(endpoint: endpoint, responseModel: String.self)
            XCTFail("Response should not be decoded for invalid model.")
        } catch let error as RequestError {
            switch error {
            case .unauthorized : XCTAssert(true)
            default: XCTFail("Error needs to be unauthorized.")
            }
        } catch {
            XCTFail("Error should be known.")
        }
    }

    override func tearDown() {
        httpClient = nil
        endpoint = nil

        super.tearDown()
    }
}
