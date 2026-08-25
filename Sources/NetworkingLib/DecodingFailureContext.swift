//
//  DecodingFailureContext.swift
//  NetworkingLib
//
//  Copyright © 2026 Paydock Ltd. All rights reserved.

import Foundation

/// Structured, loggable detail about a response body that failed to decode into the expected model.
///
/// This is a stable shape — independent of Foundation's `DecodingError` — that consumers can log and
/// report back so the offending field/mismatch can be pinpointed. It is `Sendable` (all stored
/// values are value types), so it can safely ride along inside `RequestError` across concurrency
/// boundaries. Build one from a `DecodingError` via `init(_:)`.
public struct DecodingFailureContext: Sendable, Equatable {

    /// The kind of decoding mismatch, mirroring `DecodingError`'s cases.
    public enum Kind: String, Sendable {
        case keyNotFound
        case typeMismatch
        case valueNotFound
        case dataCorrupted
        case unknown
    }

    /// The kind of mismatch.
    public let kind: Kind

    /// Dot-path to the offending field, e.g. `"resource.data.temp_token"`. Empty when at the root.
    public let codingPath: String

    /// Human-readable one-line summary, e.g. `"keyNotFound 'temp_token' at resource.data"`.
    public let summary: String

    /// The underlying decoder's debug description, for deeper local debugging.
    public let debugDescription: String

    public init(kind: Kind, codingPath: String, summary: String, debugDescription: String) {
        self.kind = kind
        self.codingPath = codingPath
        self.summary = summary
        self.debugDescription = debugDescription
    }
}

public extension DecodingFailureContext {

    /// Builds a stable context from a Foundation `DecodingError`, extracting the failing field and
    /// its location in the payload.
    init(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            self.init(kind: .keyNotFound, missingKey: key, context: context)
        case .typeMismatch(_, let context):
            self.init(kind: .typeMismatch, missingKey: nil, context: context)
        case .valueNotFound(_, let context):
            self.init(kind: .valueNotFound, missingKey: nil, context: context)
        case .dataCorrupted(let context):
            self.init(kind: .dataCorrupted, missingKey: nil, context: context)
        @unknown default:
            self.init(kind: .unknown,
                      codingPath: "",
                      summary: "unknown decoding error",
                      debugDescription: String(describing: error))
        }
    }

    /// Shared builder. For `.keyNotFound` the offending key is supplied separately (it is not part
    /// of `context.codingPath`); for the other cases the offending field is the last element of the
    /// coding path.
    private init(kind: Kind, missingKey: CodingKey?, context: DecodingError.Context) {
        let containerPath = context.codingPath.map { $0.stringValue }
        let fieldName = missingKey?.stringValue ?? containerPath.last
        let fullPath = (missingKey != nil) ? (containerPath + [missingKey!.stringValue]) : containerPath

        let field = fieldName.map { " '\($0)'" } ?? ""
        let location = containerPath.joined(separator: ".")
        let at = location.isEmpty ? "" : " at \(location)"

        self.init(kind: kind,
                  codingPath: fullPath.joined(separator: "."),
                  summary: "\(kind.rawValue)\(field)\(at)",
                  debugDescription: context.debugDescription)
    }
}
