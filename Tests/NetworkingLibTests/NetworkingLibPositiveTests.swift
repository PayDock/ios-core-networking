//
//  NetworkingLibPositiveTests.swift
//  NetworkingLibTests
//
//  Copyright © 2024 Paydock Ltd.
//  Created by Domagoj Grizelj on 18.07.2024..
//

import XCTest
@testable import NetworkingLib

final class NetworkingLibPositiveTests: XCTestCase {

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

    private func setMockProtocol() {
        MockURLProtocol.requestHandler = { request in
            let exampleData =
            """
            {"id":1,"title":"Hello, World!"}
            """
            .data(using: .utf8)!
            let response = HTTPURLResponse.init(url: request.url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)!
            return (response, exampleData)
        }
    }

    func testAsyncRequestSuccess() async {
        setMockProtocol()

        do {
            let result = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTAssertEqual(result.id, 1)
            XCTAssertEqual(result.title, "Hello, World!")
        } catch {
            XCTFail("Client failed to return data!")
        }
    }

    func testAsyncRequestFail() async {
        setMockProtocol()

        do {
            let result = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTAssertNotEqual(result.id, 2)
            XCTAssertNotEqual(result.title, "Bye, world!")
        } catch {
            XCTFail("Client failed to return data!")
        }
    }

    override func tearDown() {
        httpClient = nil
        endpoint = nil

        super.tearDown()
    }
}
