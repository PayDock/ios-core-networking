//
//  ErrorRes.swift
//  NetworkingLib
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import Foundation

public struct ErrorRes: Codable {
    public let status: Int
    public let error: ErrorObj?
    public let resource: Resource?
    public let errorSummary: ErrorSummary?
}

public struct ErrorObj: Codable {
    public let message: String?
    public let code: String?
    public let details: ErrorDetails?
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
}

public struct ErrorDetails: Codable {
    public let path: String?
    public let messages: [ErrorMessage]?
}

public struct ErrorMessage: Codable {
    public let gatewaySpecificCode: String?
    public let gatewaySpecificDescription: String?
    public let description: String?
    public let statusCode: String?
    public let statusCodeDescription: String?
}
