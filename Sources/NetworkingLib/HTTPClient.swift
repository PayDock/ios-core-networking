//
//  HTTPClient.swift
//  NetworkingLib
//
//  Created by Domagoj Grizelj on 02.10.2023..
//  Copyright © 2023 Paydock Ltd. All rights reserved.
//

import Foundation

public protocol HTTPClient {

    var session: URLSession { get }
    var decoder: JSONDecoder { get }
    var sslPinningManager: SSLPinningManager { get }

    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type) async throws -> T

}

extension HTTPClient {

    // MARK: - Variables

    public var sslPinningManager: SSLPinningManager {
        return SSLPinningManager()
    }

    // MARK: - Default implementation

    public var session: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300

        return URLSession(configuration: configuration, delegate: sslPinningManager, delegateQueue: nil)
    }

    public var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

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
            request.httpBody = endpoint.body

            #if DEBUG
                NetworkLogger.log(request: request)
            #endif

            do {
                let (data, response) = try await session.data(for: request, delegate: nil)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw RequestError.noResponse
                }
                
                #if DEBUG
                    NetworkLogger.log(data: data, response: httpResponse, error: nil)
                #endif

                switch httpResponse.statusCode {
                case 200...299:
                    do {
                        return try decoder.decode(responseModel, from: data)
                    } catch {
                        throw RequestError.decode
                    }

                default:
                    if let errorResponse = try? decoder.decode(ErrorRes.self, from: data) {
                        throw RequestError.requestError(errorResponse)
                    }
                    throw RequestError.unexpectedErrorModel
                }
            } catch let urlError as URLError {
                switch urlError.code {
                case .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .secureConnectionFailed:
                    throw RequestError.connectionError(urlError)
                case .unsupportedURL, .badURL:
                    throw RequestError.invalidRequest(urlError)
                case .badServerResponse, .resourceUnavailable, .httpTooManyRedirects:
                    throw RequestError.serverError(urlError)
                default:
                    throw RequestError.unknown(urlError)
                }
            } catch {
                throw error
            }
        }

}
