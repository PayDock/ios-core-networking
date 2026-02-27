//
//  MockURLProtocol.swift
//  NetworkLibTests
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import Foundation

class MockURLProtocol: URLProtocol {

    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var delay: TimeInterval = 0
    private var isCancelled = false

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func stopLoading() {
        isCancelled = true
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
        }

        let delay = MockURLProtocol.delay
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }

        guard !isCancelled else { return }

        do {
            let (response, data)  = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    static func reset() {
        requestHandler = nil
        delay = 0
    }
}
