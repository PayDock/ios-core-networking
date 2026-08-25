//
//  SSLPinningManager.swift
//  NetworkingLib
//
//  Created by Domagoj Grizelj on 02.10.2023..
//  Copyright © 2023 Paydock Ltd. All rights reserved.
//

import Foundation
import CommonCrypto

final public class SSLPinningManager: NSObject {

    // MARK: - Properties

    private let publicKeyHash =  NetworkingLib.shared.publicKeyHash
    private let rsa2048Asn1Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]

    // MARK: - Helpers

    private func sha256(data: Data) -> String {
        var keyWithHeader = Data(rsa2048Asn1Header)
        keyWithHeader.append(data)

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyWithHeader.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress!, CC_LONG(buffer.count), &hash)
        }

        return Data(hash).base64EncodedString()
    }
}

// MARK: - URLSessionDelegate

extension SSLPinningManager: URLSessionDelegate {

    @available(iOS 16.0, macOS 12.0, *)
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Public-key pinning below is a check *in addition to* standard trust evaluation, not a
        // replacement for it — without this, a certificate that fails ordinary chain-of-trust,
        // expiry, or hostname validation could still be accepted as long as its key matched the pin.
        guard SecTrustEvaluateWithError(serverTrust, nil) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let certs = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let serverCertificate = certs.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let serverPublicKey = SecCertificateCopyKey(serverCertificate),
              let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, nil) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let data: Data = serverPublicKeyData as Data
        let serverHashKey = sha256(data: data)
        let publicKeyLocal = publicKeyHash

        if serverHashKey == publicKeyLocal {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
