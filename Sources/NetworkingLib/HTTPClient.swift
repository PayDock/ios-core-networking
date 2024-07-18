//
//  HTTPClient.swift
//  NetworkingLib
//
//  Created by Domagoj Grizelj on 02.10.2023..
//  Copyright © 2023 Paydock Ltd. All rights reserved.
//

import Foundation

public protocol HTTPClient {

    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type) async throws -> T

}

final class HTTPClientImpl {

    private let session: URLSession
    private let sslPinningManager: SSLPinningManager
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    convenience init() {
        let sslPinningManager = SSLPinningManager()
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.init(session: URLSession(configuration: configuration, delegate: sslPinningManager, delegateQueue: nil))
    }

    init(session: URLSession,
         sslPinningManager: SSLPinningManager = SSLPinningManager()) {
        self.sslPinningManager = SSLPinningManager()
        self.session = session
    }
}

// MARK: - HTTPClient

extension HTTPClientImpl: HTTPClient {

    public func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type) async throws -> T {
        var urlComponents = URLComponents()
        urlComponents.scheme = endpoint.scheme
        urlComponents.host = endpoint.host
        urlComponents.path = endpoint.path
        urlComponents.queryItems = endpoint.parameters

        guard let url = urlComponents.url else {
            throw RequestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.header

        if let body = endpoint.body {
            request.httpBody = body
        }

        do {
            NetworkLogger.log(request: request)
            let (data, response) = try await session.data(for: request, delegate: nil)
            NetworkLogger.log(data: data, response: response as? HTTPURLResponse, error: nil)

            guard let response = response as? HTTPURLResponse else {
                throw RequestError.noResponse
            }

            switch response.statusCode {
            case 200...299:
                guard let decodedResponse = try? decoder.decode(responseModel, from: data) else {
                    throw RequestError.decode
                }
                return decodedResponse

            case 401:
                throw RequestError.unauthorized

            default:
                throw RequestError.unexpectedStatusCode
            }

        } catch {
            throw RequestError.unknown
        }
    }

}
