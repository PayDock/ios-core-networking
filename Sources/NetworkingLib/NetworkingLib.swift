//
//  NetworkingLib.swift
//  NetworkingLib
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

public class NetworkingLib {

    public static let shared = NetworkingLib()

    private var _publicKeyHash: String?

    public var publicKeyHash: String? {
        get {
            return _publicKeyHash
        }
        set {
            let oldValue = _publicKeyHash
            _publicKeyHash = newValue

            // Reset shared session if SSL pinning configuration changed
            if oldValue != newValue {
                resetSharedSession()
            }
        }
    }

    public var host: String = ""
}
