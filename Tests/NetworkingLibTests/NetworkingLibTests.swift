//
//  NetworkingLibTests.swift
//  NetworkingLibTests
//
//  Copyright © 2024 Paydock Ltd.
//  Created by Domagoj Grizelj on 18.07.2024..
//

import XCTest
@testable import NetworkingLib

final class ApiClientTests: XCTestCase {

    struct TestModel: Codable {
        let id: Int
        let title: String
    }

    private var httpClient: HTTPClient!
    private var endpoint: Endpoint!

    override func setUp() {
        super.setUp()

        self.httpClient = MockHTTPClient()
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

    func testAsyncRequest() async throws {

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        setMockProtocol()

        let apiClient = HTTPClientImpl(session: session)
        let endpoint = MockEndpoint()

        do {
            let result = try await apiClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTAssertEqual(result.id, 1)
            XCTAssertEqual(result.title, "Hello, World!")
        } catch {
            print(error.localizedDescription)
            throw error
        }
    }

    func testAsyncRequestSuccess() async {
        setMockProtocol()

        do {
            let result = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)
            XCTAssertEqual(result.id, 1)
            XCTAssertEqual(result.title, "Hello, world!")
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

    func testSendRequestSuccess() async throws {
        // Given
        let expectedResponse = TestModel(id: 1, title: "Hello, world!")

        // Mock the response handler
        MockURLProtocol.requestHandler = { request in
            let data = try! JSONEncoder().encode(expectedResponse)
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, data)
        }

        // When
        let response: TestModel = try await httpClient.sendRequest(endpoint: endpoint, responseModel: TestModel.self)

        // Then
        XCTAssertEqual(response.id, expectedResponse.id)
        XCTAssertEqual(response.title, expectedResponse.title)
    }

    override func tearDown() {
        httpClient = nil
        endpoint = nil

        super.tearDown()
    }
}
