//
//  HTTPClient.swift
//  NetworkingLib
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import Foundation

public protocol HTTPClient {

    var session: URLSession { get }
    var decoder: JSONDecoder { get }
    var sslPinningManager: SSLPinningManager? { get }

    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type) async throws -> T
}

// MARK: - Shared Session Manager

// Private class to manage shared URLSession and SSL Pinning Manager instances
private final class SharedSessionManager {
    static let shared = SharedSessionManager()

    private var _session: URLSession?
    private let sessionLock = NSLock()

    private var _sslPinningManager: SSLPinningManager?
    private let sslManagerLock = NSLock()

    private init() {}

    func getSession() -> URLSession {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        if let existingSession = _session {
            return existingSession
        }

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300

        let sslManager = getSSLPinningManager()
        let newSession = URLSession(
            configuration: configuration,
            delegate: sslManager,
            delegateQueue: nil
        )

        _session = newSession
        return newSession
    }

    func getSSLPinningManager() -> SSLPinningManager? {
        sslManagerLock.lock()
        defer { sslManagerLock.unlock() }

        if let cached = _sslPinningManager {
            return cached
        }

        guard NetworkingLib.shared.publicKeyHash != nil else {
            return nil
        }

        let manager = SSLPinningManager()
        _sslPinningManager = manager
        return manager
    }

    func reset() {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        _session?.invalidateAndCancel()
        _session = nil

        sslManagerLock.lock()
        _sslPinningManager = nil
        sslManagerLock.unlock()
    }
}

extension HTTPClient {

    // MARK: - Variables

    public var sslPinningManager: SSLPinningManager? {
        return SharedSessionManager.shared.getSSLPinningManager()
    }

    // MARK: - Default implementation

    public var session: URLSession {
        return SharedSessionManager.shared.getSession()
    }

    /// Resets the shared session (useful if SSL pinning configuration changes)
    public static func resetSharedSession() {
        SharedSessionManager.shared.reset()
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
                // Decode JSON on background queue to avoid blocking main thread
                do {
                    return try await Task.detached(priority: .userInitiated) {
                        try decoder.decode(responseModel, from: data)
                    }.value
                } catch {
                    throw RequestError.decode
                }

            default:
                // Decode error response on background queue
                try await handleErrorResponse(data: data, decoder: decoder)
            }
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw error
        }
    }

    // MARK: - Private Helpers

    private func handleErrorResponse(data: Data, decoder: JSONDecoder) async throws -> Never {
        let errorResponse = try? await Task.detached(priority: .userInitiated) {
            try decoder.decode(ErrorRes.self, from: data)
        }.value

        if let errorResponse = errorResponse {
            throw RequestError.requestError(errorResponse)
        }
        throw RequestError.unexpectedErrorModel
    }

    private func mapURLError(_ urlError: URLError) -> RequestError {
        switch urlError.code {
        case .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .secureConnectionFailed:
            return RequestError.connectionError(urlError)
        case .unsupportedURL, .badURL:
            return RequestError.invalidRequest(urlError)
        case .badServerResponse, .resourceUnavailable, .httpTooManyRedirects:
            return RequestError.serverError(urlError)
        default:
            return RequestError.unknown(urlError)
        }
    }
}

// MARK: - Public Session Reset Function

// Resets the shared URLSession (useful when SSL pinning configuration changes)
public func resetSharedSession() {
    SharedSessionManager.shared.reset()
}
