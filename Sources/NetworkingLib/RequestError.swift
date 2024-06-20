//
//  RequestError.swift
//  NetworkingLib
//
//  Created by Domagoj Grizelj on 02.10.2023..
//  Copyright © 2023 Paydock Ltd. All rights reserved.
//

import Foundation

public enum RequestError: Error {
    case decode
    case invalidURL
    case noResponse
    case unauthorized
    case unexpectedStatusCode
    case unexpectedErrorModel
    case requestError(_ errorResponse: ErrorRes)
    case unknown

    var customMessage: String {
        switch self {
        case .decode: return "Error while mapping a JSON response"
        case .invalidURL: return "Invalid URL"
        case .noResponse: return "Response timeout"
        case .unauthorized: return "Unauthorized - missing or invalid access key"
        case .unexpectedStatusCode: return "Unexpected status code received"
        case .unexpectedErrorModel: return "Unexpected error model - unable to decode JSON"
        case .requestError(let errorRes): return errorRes.error?.message ?? "Request error"
        case .unknown: return "Unknown error"
        }
    }
}

public struct ErrorRes: Codable {

    public let status: Int
    public let error: ErrorObj?
    public let resource: Resource?
    public let errorSummary: ErrorSummary?

    public struct ErrorObj: Codable {
        public let message: String?
        public let code: String?
    }

    public struct Resource: Codable {
        public let type: String?
    }

    public struct ErrorSummary: Codable {
        public let message: String?
        public let code: String?
        public let statusCode: String?
        public let statusCodeDescription: String?
        public let details: ErrorDetails?

        public struct ErrorDetails: Codable {
            public let gatewaySpecificCode: String?
            public let gatewaySpecificDescription: String?
            public let messages: [String]?
        }
    }

}

