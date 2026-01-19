//
//  MockEndpoint.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import Foundation
@testable import NetworkingLib

class HTTPClientTestable: HTTPClient {

    var session: URLSession {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: sessionConfiguration)
    }
}
