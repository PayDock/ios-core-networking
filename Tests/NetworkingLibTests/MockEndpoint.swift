//
//  MockEndpoint.swift
//  NetworkingLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import Foundation
import NetworkingLib

struct MockEndpoint: Endpoint {
    var scheme: String = "https"
    var host: String = "example.com"
    var path: String = "/test"
    var method: RequestMethod = .get
    var header: [String: String]?
    var body: Data?
    var parameters: [URLQueryItem] = []
    var encoder: JSONEncoder = JSONEncoder()
    var mockFile: String?
    var bundle: Bundle?
}
