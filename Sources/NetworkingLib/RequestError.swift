//
//  RequestError.swift
//  NetworkingLib
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import Foundation

public enum RequestError: Error {
    case connectionError(_ urlError: URLError)
    /// The response body could not be mapped to the expected model. Carries a
    /// `DecodingFailureContext` (when the underlying error was a `DecodingError`) identifying the
    /// offending field, so consumers can log/report exactly what failed to decode.
    case decode(_ context: DecodingFailureContext?)
    case invalidRequest(_ urlError: URLError)
    case invalidURL
    case noResponse
    case serverError(_ urlError: URLError)
    case unexpectedErrorModel
    case requestError(_ errorResponse: ErrorRes)
    case unknown(_ urlError: URLError)

    var customMessage: String {
        switch self {
        case .connectionError(let urlError): return urlError.localizedDescription
        case .decode(let context):
            let base = "Error while mapping a JSON response"
            return context.map { "\(base): \($0.summary)" } ?? base
        case .invalidRequest(let urlError): return urlError.localizedDescription
        case .invalidURL: return "Invalid URL - please try again later"
        case .noResponse: return "No response received - - please try again later"
        case .serverError(let urlError): return urlError.localizedDescription
        case .unexpectedErrorModel: return "Unexpected error model - unable to decode JSON"
        case .requestError(let errorRes): return errorRes.error?.message ?? "Request error - please try again later"
        case .unknown(let urlError): return urlError.localizedDescription
        }
    }
}
