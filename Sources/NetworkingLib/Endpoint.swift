//
//  Endpoint.swift
//  NetworkingLib
//
//  Created by Domagoj Grizelj on 02.10.2023..
//  Copyright © 2023 Paydock Ltd. All rights reserved.
//

import Foundation

public protocol Endpoint {

    var scheme: String { get }
    var host: String { get }
    var path: String { get }
    var method: RequestMethod { get }
    var header: [String: String]? { get }
    var body: Data? { get }
    var parameters: [URLQueryItem] { get }
    var encoder: JSONEncoder { get }
    var mockFile: String? { get }
    var bundle: Bundle? { get }

}

public extension Endpoint {

    var scheme: String {
        return "https"
    }

    var host: String {
        return NetworkingLib.shared.host
    }

    var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

}
