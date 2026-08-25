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
    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type, timeout: TimeInterval) async throws -> T
    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type, timeout: TimeInterval, maxRetries: Int) async throws -> T
}

public enum NetworkingTimeoutError: Error {
    case timedOut
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
        return try await sendRequest(endpoint: endpoint, responseModel: responseModel, timeout: 60, maxRetries: 0)
    }

    public func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type, timeout: TimeInterval) async throws -> T {
        return try await sendRequest(endpoint: endpoint, responseModel: responseModel, timeout: timeout, maxRetries: 0)
    }

    public func sendRequest<T: Decodable>(
        endpoint: Endpoint,
        responseModel: T.Type,
        timeout: TimeInterval,
        maxRetries: Int
    ) async throws -> T {
        let maxAttempts = max(1, maxRetries + 1)

        for attempt in 1...maxAttempts {
            do {
                return try await performRequest(endpoint: endpoint, responseModel: responseModel, timeout: timeout)
            } catch let error as RequestError {
                guard case .connectionError = error, attempt < maxAttempts else {
                    throw error
                }
                let delay = calculateRetryDelay(attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw RequestError.noResponse
    }

    private func performRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type, timeout: TimeInterval) async throws -> T {
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
            let (data, response) = try await withTimeout(seconds: timeout) {
                try await self.session.data(for: request, delegate: nil)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RequestError.noResponse
            }

            #if DEBUG
                NetworkLogger.log(data: data, response: httpResponse, error: nil)
            #endif

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try await Task.detached(priority: .userInitiated) {
                        try decoder.decode(responseModel, from: data)
                    }.value
                } catch {
                    // Preserve which field failed to decode so consumers can log/report it.
                    let context = (error as? DecodingError).map(DecodingFailureContext.init)
                    throw RequestError.decode(context)
                }

            default:
                try await handleErrorResponse(data: data, decoder: decoder)
            }
        } catch is NetworkingTimeoutError {
            throw RequestError.connectionError(URLError(.timedOut))
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw error
        }
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        let nanoseconds = safeNanoseconds(from: seconds)

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: nanoseconds)
                throw NetworkingTimeoutError.timedOut
            }

            guard let result = try await group.next() else {
                throw NetworkingTimeoutError.timedOut
            }

            group.cancelAll()
            return result
        }
    }

    private func safeNanoseconds(from seconds: TimeInterval) -> UInt64 {
        guard seconds.isFinite, seconds > 0 else {
            return UInt64(60 * 1_000_000_000)
        }
        let maxSeconds: TimeInterval = 3600
        let clampedSeconds = min(seconds, maxSeconds)
        return UInt64(clampedSeconds * 1_000_000_000)
    }

    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 30.0
        let delay = baseDelay * pow(2.0, Double(attempt - 1))
        return min(delay, maxDelay)
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
