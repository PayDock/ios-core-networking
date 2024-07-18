//
//  MockApiClient.swift
//  NetworkingLibTests
//
//  Copyright © 2024 Paydock Ltd.
//  Created by Domagoj Grizelj on 18.07.2024..
//

import Foundation
@testable import NetworkingLib

class MockHTTPClient: Mockable, HTTPClient {

    var sendError: Bool
    var mockFile: String?

    init(sendError: Bool = false, mockFile: String? = nil) {
        self.sendError = sendError
        self.mockFile = mockFile
    }

    func sendRequest<T>(endpoint: any Endpoint, responseModel: T.Type) async throws -> T where T : Decodable {
        if sendError {
            throw RequestError.requestError(ErrorRes(status: 1, error: .init(message: "Error", code: "ErrorCode"), resource: nil, errorSummary: nil))
        } else {
            return loadJSON(filename: "test", type: responseModel.self)
        }
    }
}
