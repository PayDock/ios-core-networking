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
    var session: URLSession {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        return session
    }

    var sslPinningManager: SSLPinningManager {
        return SSLPinningManager()
    }

    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }


    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type) async throws -> T {
        return loadJSON(filename: "test", type: responseModel.self)
    }

}
