//
//  RequestError.swift
//  NetworkingLib
//
//  Created by Domagoj Grizelj on 02.10.2023..
//  Copyright © 2023 Paydock Ltd. All rights reserved.
//

import Foundation

public enum RequestError: Error {
    case connectionError(_ urlError: URLError)
    case decode
    case invalidRequest(_ urlError: URLError)
    case invalidURL
    case noResponse
    case serverError(_ urlError: URLError)
    case unexpectedErrorModel
    case requestError(_ errorResponse: ErrorRes)
    case unknown(_ urlError: URLError)

    var customMessage: String {
        switch self {
        case .connectionError(let urlError): return urlError.localizedDescription ?? "Connection error - please check your internet connection"
        case .decode: return "Error while mapping a JSON response"
        case .invalidRequest(let urlError): return urlError.localizedDescription ?? "Invalid request - please check your request parameters"
        case .invalidURL: return "Invalid URL - please try again later"
        case .noResponse: return "No response received - - please try again later"
        case .serverError(let urlError): return urlError.localizedDescription ?? "Server error - please try again later"
        case .unexpectedErrorModel: return "Unexpected error model - unable to decode JSON"
        case .requestError(let errorRes): return errorRes.error?.message ?? "Request error - please try again later"
        case .unknown(let urlError): return urlError.localizedDescription ?? "Unknown error - please try again later"
        }
    }
}
