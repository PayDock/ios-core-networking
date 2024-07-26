//
//  MockEndpoint.swift
//  NetworkingLibTests
//
//  Copyright © 2024 Paydock Ltd.
//  Created by Domagoj Grizelj on 18.07.2024..
//

import Foundation
import NetworkingLib

struct MockEndpoint: Endpoint {
    var scheme: String = "https"
    var host: String = "example.com"
    var path: String = "/test"
    var method: RequestMethod = .get
    var header: [String: String]? = nil
    var body: Data? = nil
    var parameters: [URLQueryItem] = []
    var encoder: JSONEncoder = JSONEncoder()
}
