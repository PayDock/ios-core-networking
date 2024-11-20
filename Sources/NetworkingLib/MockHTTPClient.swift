//
//  MockHTTPClient.swift
//  NetworkingLib
//
//  Created by Domagoj Grizelj on 08.10.2024..
//

import Foundation

public protocol MockHTTPClient: HTTPClient {

    func loadJSON<T: Decodable>(filename: String?, bundle: Bundle?, type: T.Type) -> T

}

public extension MockHTTPClient {

    func loadJSON<T: Decodable>(filename: String?, bundle: Bundle?, type: T.Type) -> T {
        guard let filename = filename else {
            fatalError("No filename provided for a mock response!")
        }
        guard let path = bundle?.url(forResource: filename, withExtension: "json") else {
            fatalError("Failed to load JSON")
        }

        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decodedObject = try decoder.decode(type, from: data)

            return decodedObject

        } catch {
            fatalError("Failed to decode loaded JSON")
        }
    }

}

public extension MockHTTPClient {
    
    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type) async throws -> T {
        return loadJSON(filename: endpoint.mockFile, bundle: endpoint.bundle, type: responseModel.self)
    }
    
}
