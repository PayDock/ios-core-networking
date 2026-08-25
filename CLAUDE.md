# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Part of the **SDKDev** workspace — see the [workspace overview](../CLAUDE.md) for how this repo relates to the other Paydock SDK repos. This is the Swift-native `NetworkingLib` (`ios-core-networking`) that **the iOS SDK actually uses today**. The Android KMP repo `mobile-lib-networking-android` also publishes an iOS binary, but that target is **not currently used** — so this repo is the live source of truth for iOS networking.

## What this is

`NetworkingLib` is a standalone, protocol-oriented Swift networking library (SPM package) providing a small, testable HTTP client with SSL public-key pinning, async/await, Codable request/response handling, per-request timeouts, and automatic retry with exponential backoff. It is consumed by the iOS MobileSDK (`mobile-sdk-ios`) and its `Data*` modules. Targets **iOS 16.0+ / macOS 12.0+**, **Swift 5.10+**, **Xcode 15.0+** (CI runs on newer Xcode; see below).

## Toolchain & setup

- **Package manager:** Swift Package Manager (`Package.swift`, `swift-tools-version: 5.10`). Single library product `NetworkingLib` (target `NetworkingLib`) + test target `NetworkingLibTests`. No external package dependencies.
- **Lint:** SwiftLint, configured by `.swiftlint.yml` (line length warning 140, `todo`/`inclusive_language` rules disabled, `.build` excluded, relaxed complexity/length thresholds).
- **Ruby/fastlane:** `Gemfile` pins fastlane `~> 2.229`; `scripts/setup_bundler.sh` bootstraps Bundler (with Ruby 3.4 `nkf`/`kconv` circular-dependency workarounds) in CI. Fastlane lanes live in `fastlane/Fastfile`.
- **No git hooks or branch-name enforcement** are set up in this repo (unlike `mobile-sdk-ios`); there is no `make setup`.

## Common commands

```bash
swift build                                   # build the library
swift test                                    # run all tests
swift test --filter HTTPClientTimeoutRetryTests   # run one test class/suite
swift test --filter NetworkingLibTests.EndpointTests   # module-qualified filter

swiftlint --config .swiftlint.yml             # lint locally (brew install swiftlint)
bundle exec fastlane lint                     # CI lint lane (strict, codeclimate reporter)
bundle exec fastlane testPackage              # CI test lane (run_tests via xcodebuild on a simulator)
```

CI (`.gitlab-ci.yml`, GitLab, `saas-macos-large-m2pro` runners on the `macos-26-xcode-26` image) has two stages: `quality` (`runLint` → `fastlane lint`) and `test` (`run_NetworkingLib_tests` → `fastlane testPackage`, then `xccov` coverage converted to Cobertura via `scripts/xccov-to-cobertura.py` and HTML via `scripts/generate-coverage-html.py`, published to GitLab Pages on the default branch). `fastlane testPackage` targets a simulator by device name only (`platform=iOS Simulator,name=iPhone 17`, deliberately **not** OS-version-pinned) — an exact `OS=` pin previously drifted out of sync repeatedly as the `macos-26-xcode-26` CI image's bundled simulator runtimes updated (and the same happens locally as Xcode ships new runtimes), causing "Unable to find a device matching the provided destination specifier" failures. If `iPhone 17` itself is ever removed/renamed in a future Xcode simulator lineup, update the device `name` in `fastlane/Fastfile`; check `xcrun simctl list devices available` to see what's currently installed.

## Architecture

Everything lives in `Sources/NetworkingLib/`. The design is protocol-oriented: consumers describe *what* to call (`Endpoint`) and get a client (`HTTPClient`) whose behaviour is supplied entirely by a protocol extension, so a conforming type usually needs zero method bodies.

### `Endpoint` (`Endpoint.swift`)
A protocol describing one request: `scheme`, `host`, `path`, `method: RequestMethod`, `header: [String:String]?`, `body: Data?`, `parameters: [URLQueryItem]`, `encoder: JSONEncoder`, plus `mockFile: String?` and `bundle: Bundle?` (used only by `MockHTTPClient`). Default implementations: `scheme` = `"https"`, `host` = `NetworkingLib.shared.host`, and `encoder` = a `JSONEncoder` with `.convertToSnakeCase` key encoding. A consumer conforms a struct and typically only sets `path`, `method`, `header`, `parameters`, and (for writes) `body`. Note the README's `Endpoint` summary omits `mockFile`/`bundle` — the source is authoritative.

### `RequestMethod` (`RequestMethod.swift`)
`String` enum: `.get` `.post` `.put` `.patch` `.delete` (raw values are the uppercased HTTP verbs).

### `HTTPClient` (`HTTPClient.swift`)
The core protocol: `session: URLSession`, `decoder: JSONDecoder`, `sslPinningManager: SSLPinningManager?`, and three overloads of the generic
`sendRequest<T: Decodable>(endpoint:responseModel:[timeout:][maxRetries:]) async throws -> T`.

A single protocol `extension` provides all defaults, so `class APIClient: HTTPClient {}` is a complete client:
- **`session` / `sslPinningManager`** come from a private `SharedSessionManager` singleton that lazily builds and caches one `URLSession` (config: `waitsForConnectivity = true`, `timeoutIntervalForRequest = 60`, `timeoutIntervalForResource = 300`) wired to the SSL pinning delegate. Tests override `session` to inject a `MockURLProtocol` (see `Tests/.../HTTPClientTestable.swift`).
- **`decoder`** defaults to `JSONDecoder` with `.convertFromSnakeCase`.
- **Overload chain:** `sendRequest(endpoint:responseModel:)` → `timeout: 60, maxRetries: 0`; the `timeout:` overload → `maxRetries: 0`; the full overload does the work.
- **Request flow (`performRequest`):** builds a `URLComponents` from `scheme`/`host`/`path`/`parameters` (throws `.invalidURL` on failure), sets method/headers/body, logs in DEBUG, then awaits `session.data(for:)` wrapped in `withTimeout`. `200...299` decodes `responseModel` off a detached task (decode failure → `.decode(DecodingFailureContext?)`, wrapping any `DecodingError` in a `DecodingFailureContext` so the offending field is preserved); any other status decodes an `ErrorRes` (→ `.requestError`, or `.unexpectedErrorModel` if that fails).
- **Timeout (`withTimeout`):** races the network call against a `Task.sleep` in a `withThrowingTaskGroup`; the timer firing throws `NetworkingTimeoutError.timedOut`, remapped to `RequestError.connectionError(URLError(.timedOut))`. This wraps the **entire** operation, so it fires even while `waitsForConnectivity` is waiting. `safeNanoseconds` clamps the timeout to `(0, 3600]s` and falls back to 60s for non-finite/non-positive values.
- **Retry:** only `RequestError.connectionError` is retried, up to `maxRetries` extra attempts. `calculateRetryDelay` is exponential backoff `1s, 2s, 4s, …` capped at `30s`. HTTP 4xx/5xx are **not** retried.
- **Error mapping (`mapURLError`):** `URLError` codes are bucketed into `.connectionError` (`notConnectedToInternet`, `timedOut`, `cannotFindHost`, `cannotConnectToHost`, `networkConnectionLost`, `secureConnectionFailed`), `.invalidRequest` (`unsupportedURL`, `badURL`), `.serverError` (`badServerResponse`, `resourceUnavailable`, `httpTooManyRedirects`), else `.unknown`.

`resetSharedSession()` (both a free function and `HTTPClient.resetSharedSession()` static) invalidates and clears the cached session and pinning manager.

### `NetworkingLib` (`NetworkingLib.swift`)
The shared config singleton, `NetworkingLib.shared`: mutable `host: String` (default `""`) and `publicKeyHash: String?`. Setting `publicKeyHash` to a new value automatically calls `resetSharedSession()` so pinning takes effect. Configure before making requests, e.g. `NetworkingLib.shared.host = "api.example.com"`.

### `SSLPinningManager` (`SSLPinningManager.swift`)
`URLSessionDelegate` performing RSA-2048 public-key pinning: extracts the server certificate's public key, prepends the RSA-2048 ASN.1 header, SHA-256 hashes it (via `CommonCrypto`), base64-encodes, and compares to `NetworkingLib.shared.publicKeyHash`. Match → `.useCredential`; mismatch or any extraction failure → `.cancelAuthenticationChallenge`. It is only instantiated when `publicKeyHash != nil`, so **pinning is opt-in** — no hash means a normal (unpinned) session.

### `RequestError` / `ErrorRes` / `DecodingFailureContext` (`RequestError.swift`, `ErrorRes.swift`, `DecodingFailureContext.swift`)
`RequestError` enum cases: `.connectionError(URLError)`, `.decode(DecodingFailureContext?)`, `.invalidRequest(URLError)`, `.invalidURL`, `.noResponse`, `.serverError(URLError)`, `.unexpectedErrorModel`, `.requestError(ErrorRes)`, `.unknown(URLError)`, each with a `customMessage` (for `.decode`, the message appends the context's `summary` when present). `ErrorRes` is the Codable shape of Paydock API error bodies (`status`, `error`, `resource`, `errorSummary`, nested `ErrorObj`/`ErrorDetails`/`ErrorMessage`/`ErrorSummary`).

`DecodingFailureContext` (added on `feature/v1.3.0` — "Expose decoding issue detail to integrator") is a public `Sendable, Equatable` struct that surfaces *which* field failed to decode to the integrator, without leaking Foundation's `DecodingError`. Fields: `kind: Kind` (a `String` enum — `keyNotFound`, `typeMismatch`, `valueNotFound`, `dataCorrupted`, `unknown`, mirroring `DecodingError`'s cases), `codingPath: String` (dot-path to the offending field, e.g. `"resource.data.temp_token"`), `summary: String` (one-line human-readable, e.g. `"keyNotFound 'temp_token' at resource.data"`), and `debugDescription: String` (the decoder's raw debug text). Built from a `DecodingError` via `init(_:)`; `HTTPClient` populates it on a `200...299` decode failure, so `.decode` may carry `nil` only when the thrown error was not a `DecodingError`.

### `MockHTTPClient` (`MockHTTPClient.swift`)
A shipped `HTTPClient` sub-protocol whose `sendRequest` overloads ignore the network and `loadJSON` a fixture from `endpoint.mockFile` in `endpoint.bundle` (missing file/decode → `fatalError`). This is why `Endpoint` carries `mockFile`/`bundle`. Consumers use it to stub responses in host-app/test builds.

### `NetworkLogger` (`NetworkLogger.swift`)
`print()`-based request/response logger; only invoked from `#if DEBUG` blocks in `HTTPClient`.

## Conventions & gotchas

- **DEBUG-only logging:** request/response bodies, headers, and status are printed via `NetworkLogger` only under `#if DEBUG`. No logging (and no PII exposure) in release builds. It uses `print()`, not a logging framework.
- **SSL pinning is opt-in and RSA-2048/SHA-256 specific.** Set `NetworkingLib.shared.publicKeyHash` (base64 of the SHA-256 over the RSA-2048 ASN.1 header + public key) to enable it; changing it resets the shared session automatically. The pinning code assumes an RSA-2048 key — a different key type/size will not match.
- **Shared, cached URLSession.** All default `HTTPClient` instances share one `URLSession`. If pinning/session config changes outside of the `publicKeyHash` setter, call `resetSharedSession()`. To use a custom session (e.g. mock protocol in tests), override the `session` property on your conforming type.
- **Snake_case by default both ways:** responses decode with `.convertFromSnakeCase`, request bodies encode with `.convertToSnakeCase`. If a model uses explicit `CodingKeys`, you must map *every* property (including snake_case ones) — the automatic conversion is bypassed. Override `encoder` (on `Endpoint`) or `decoder` (on `HTTPClient`) to change strategy.
- **Timeouts wrap the whole call**, so they fire even during connectivity waits; the fallback timeout is 60s and values are clamped to at most 3600s.
- **Do not confuse the two networking repos.** This is the native Swift `NetworkingLib`, and it is the one the iOS SDK uses today. `mobile-lib-networking-android` is a Kotlin Multiplatform library that *also* publishes an iOS binary (`PaydockNetworking`), but **that KMP iOS target is not currently used**, so its `Endpoint`/`HTTPClient` are not in play for iOS — this repo is the live iOS networking API.
- **CODEOWNERS:** everything is owned by `@paydock/codeowners/mobile-codeowners`; `.gitlab-ci.yml` additionally by platform/security codeowners.
