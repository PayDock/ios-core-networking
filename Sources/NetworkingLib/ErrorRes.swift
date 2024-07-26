//
//  ErrorRes.swift
//  NetworkingLib
//
//  Created by Domagoj Grizelj on 02.10.2023..
//  Copyright © 2023 Paydock Ltd. All rights reserved.
//

import Foundation

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

