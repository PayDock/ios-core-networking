# NetworkingLib

A modern, Swift-based networking library for iOS applications that provides a clean, protocol-oriented API for making HTTP requests with support for SSL pinning, error handling, and network logging.

## Features

- 🚀 **Protocol-Oriented Design**: Clean, testable architecture using protocols
- 🔒 **SSL Pinning**: Built-in SSL certificate pinning support for enhanced security
- 📝 **Network Logging**: Debug logging for requests and responses (DEBUG builds only)
- 🎯 **Type-Safe**: Generic request/response handling with Codable support
- ⚡ **Async/Await**: Modern Swift concurrency support
- 🛡️ **Error Handling**: Comprehensive error types for different failure scenarios
- 🔧 **Configurable**: Customizable URLSession configuration and timeouts
- ⏱️ **Timeout Control**: Configurable request timeouts that apply to the entire operation
- 🔄 **Automatic Retry**: Built-in retry logic with exponential backoff for connection errors

## Requirements

- iOS 16.0+
- macOS 12.0+
- Swift 5.10+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://gitlab.com/paydock/bounded-contexts/mobile/mobile-lib-networking-ios.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Packages...
2. Enter the repository URL
3. Select the version you want to use

## Usage

### Basic Setup

First, configure the shared `NetworkingLib` instance:

```swift
import NetworkingLib

// Set the base host
NetworkingLib.shared.host = "api.example.com"

// Optionally configure SSL pinning
NetworkingLib.shared.publicKeyHash = "your-public-key-hash"
```

### Creating an Endpoint

Create an endpoint by conforming to the `Endpoint` protocol:

```swift
struct GetUserEndpoint: Endpoint {
    let userId: String
    
    var path: String {
        return "/users/\(userId)"
    }
    
    var method: RequestMethod {
        return .get
    }
    
    var header: [String: String]? {
        return [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
    }
    
    var parameters: [URLQueryItem] {
        return [
            URLQueryItem(name: "include", value: "profile")
        ]
    }
}
```

### Making Requests

Create a class that conforms to `HTTPClient`:

```swift
class APIClient: HTTPClient {
    // Default implementations are provided by the protocol extension
}

let client = APIClient()
let endpoint = GetUserEndpoint(userId: "123")

do {
    let user: User = try await client.sendRequest(
        endpoint: endpoint,
        responseModel: User.self
    )
    print("User: \(user)")
} catch let error as RequestError {
    print("Error: \(error.customMessage)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Request with Custom Timeout

You can specify a custom timeout for individual requests. The timeout applies to the entire operation, including any time spent waiting for network connectivity:

```swift
do {
    let user: User = try await client.sendRequest(
        endpoint: endpoint,
        responseModel: User.self,
        timeout: 30.0  // 30 second timeout
    )
} catch let error as RequestError {
    if case .connectionError(let urlError) = error, urlError.code == .timedOut {
        print("Request timed out")
    }
}
```

### Request with Retry Logic

For unreliable network conditions, you can enable automatic retry with exponential backoff. Retries are only performed for connection errors (network unavailable, timeout, connection lost, etc.):

```swift
do {
    let user: User = try await client.sendRequest(
        endpoint: endpoint,
        responseModel: User.self,
        timeout: 30.0,
        maxRetries: 3  // Will attempt up to 4 times (1 initial + 3 retries)
    )
} catch {
    print("Request failed after all retry attempts")
}
```

**Retry behavior:**
- Only connection errors trigger retries (e.g., `notConnectedToInternet`, `timedOut`, `networkConnectionLost`)
- HTTP errors (4xx, 5xx) do **not** trigger retries
- Exponential backoff: 1s, 2s, 4s, 8s... (max 30s between retries)

### POST Request Example

```swift
struct CreateUserEndpoint: Endpoint {
    let userData: UserData
    
    var path: String {
        return "/users"
    }
    
    var method: RequestMethod {
        return .post
    }
    
    var header: [String: String]? {
        return ["Content-Type": "application/json"]
    }
    
    var body: Data? {
        return try? encoder.encode(userData)
    }
    
    var parameters: [URLQueryItem] {
        return []
    }
}
```

### Error Handling

The library provides comprehensive error handling through `RequestError`:

```swift
do {
    let result = try await client.sendRequest(endpoint: endpoint, responseModel: Model.self)
} catch let error as RequestError {
    switch error {
    case .connectionError(let urlError):
        // Handle network connection issues
        print("Connection error: \(urlError.localizedDescription)")
    case .decode(let context):
        // Handle JSON decoding errors. `context` (when available) identifies the offending field.
        print("Failed to decode response: \(context?.summary ?? "unknown field")")
    case .invalidURL:
        // Handle invalid URL construction
        print("Invalid URL")
    case .requestError(let errorRes):
        // Handle API error responses
        print("API error: \(errorRes.error?.message ?? "Unknown error")")
    case .serverError(let urlError):
        // Handle server errors
        print("Server error: \(urlError.localizedDescription)")
    default:
        print("Error: \(error.customMessage)")
    }
}
```

## API Reference

### Protocols

#### `HTTPClient`

The main protocol for making HTTP requests.

```swift
protocol HTTPClient {
    var session: URLSession { get }
    var decoder: JSONDecoder { get }
    var sslPinningManager: SSLPinningManager? { get }
    
    // Basic request (60 second default timeout, no retries)
    func sendRequest<T: Decodable>(
        endpoint: Endpoint,
        responseModel: T.Type
    ) async throws -> T
    
    // Request with custom timeout
    func sendRequest<T: Decodable>(
        endpoint: Endpoint,
        responseModel: T.Type,
        timeout: TimeInterval
    ) async throws -> T
    
    // Request with custom timeout and retry logic
    func sendRequest<T: Decodable>(
        endpoint: Endpoint,
        responseModel: T.Type,
        timeout: TimeInterval,
        maxRetries: Int
    ) async throws -> T
}
```

| Method | Timeout | Retries | Use Case |
|--------|---------|---------|----------|
| `sendRequest(endpoint:responseModel:)` | 60s | 0 | Standard requests |
| `sendRequest(endpoint:responseModel:timeout:)` | Custom | 0 | Time-sensitive operations |
| `sendRequest(endpoint:responseModel:timeout:maxRetries:)` | Custom | Custom | Unreliable network conditions |

#### `Endpoint`

Protocol for defining API endpoints.

```swift
protocol Endpoint {
    var scheme: String { get }           // Default: "https"
    var host: String { get }            // Default: NetworkingLib.shared.host
    var path: String { get }
    var method: RequestMethod { get }
    var header: [String: String]? { get }
    var body: Data? { get }
    var parameters: [URLQueryItem] { get }
    var encoder: JSONEncoder { get }    // Default: JSONEncoder()
}
```

### Enums

#### `RequestMethod`

HTTP methods supported by the library:

- `.get`
- `.post`
- `.put`
- `.patch`
- `.delete`

#### `RequestError`

Error types for different failure scenarios:

- `.connectionError(URLError)` - Network connectivity issues
- `.decode(DecodingFailureContext?)` - JSON decoding failures; the context identifies the offending
  field (kind, coding path, summary) when the underlying error was a `DecodingError`
- `.invalidRequest(URLError)` - Invalid request configuration
- `.invalidURL` - URL construction failures
- `.noResponse` - Missing HTTP response
- `.serverError(URLError)` - Server-side errors
- `.unexpectedErrorModel` - Unexpected error response format
- `.requestError(ErrorRes)` - API error responses
- `.unknown(URLError)` - Unknown errors

### Classes

#### `NetworkingLib`

Singleton for library configuration:

```swift
NetworkingLib.shared.host = "api.example.com"
NetworkingLib.shared.publicKeyHash = "base64-encoded-hash"
```

#### `SSLPinningManager`

Handles SSL certificate pinning. Automatically enabled when `publicKeyHash` is set.

## SSL Pinning

SSL pinning is automatically enabled when you set `NetworkingLib.shared.publicKeyHash`. The library uses RSA 2048 public key pinning with SHA-256 hashing.

To get your server's public key hash:

1. Extract the certificate from your server
2. Get the public key from the certificate
3. Calculate the SHA-256 hash with RSA 2048 ASN.1 header
4. Base64 encode the hash

## Network Logging

Network logging is automatically enabled in DEBUG builds. It logs:
- Request URL, method, headers, and body
- Response status code, headers, and body
- Errors (if any)

Logs are printed to the console using `print()`.

## Testing

The library includes comprehensive test coverage with 69+ tests covering:

- ✅ HTTP client functionality and request/response handling
- ✅ Error handling and error types
- ✅ Endpoint configuration
- ✅ Request methods (GET, POST, PUT, PATCH, DELETE)
- ✅ Query parameters, headers, and body handling
- ✅ JSON decoding with snake_case conversion
- ✅ SSL pinning manager initialization
- ✅ Network configuration
- ✅ Timeout behavior and custom timeouts
- ✅ Retry logic with exponential backoff

To run tests:

```bash
swift test
```

Or in Xcode:
1. Press `Cmd+U` to run tests
2. Or use Product → Test


## Configuration

### Timeout Configuration

The library provides two levels of timeout control:

**1. Per-Request Timeout (Recommended)**

Use the `timeout` parameter in `sendRequest` to set a timeout for individual requests. This timeout applies to the **entire operation**, including any time spent waiting for network connectivity:

```swift
// 30 second timeout for this specific request
let result = try await client.sendRequest(
    endpoint: endpoint,
    responseModel: Model.self,
    timeout: 30.0
)
```

**2. URLSession Configuration**

The default `URLSession` configuration includes:

- `waitsForConnectivity = true` - Waits for network connectivity before starting
- `timeoutIntervalForRequest = 60` seconds - Time between data packets
- `timeoutIntervalForResource = 300` seconds - Total time for resource transfer

**Important**: The per-request `timeout` parameter wraps the entire operation and will trigger even while waiting for connectivity. This prevents requests from hanging indefinitely when `waitsForConnectivity` is enabled.

You can override the `session` property in your `HTTPClient` implementation to customize the URLSession settings.

### JSON Encoding and Decoding

#### Decoding (Responses)

The default `JSONDecoder` uses `.convertFromSnakeCase` key decoding strategy. This means that JSON keys like `user_id` and `created_at` are automatically converted to Swift property names like `userId` and `createdAt`.

#### Encoding (Requests)

The default `JSONEncoder` in the `Endpoint` protocol uses `.convertToSnakeCase` key encoding strategy. This means that Swift property names like `userId` and `createdAt` are automatically converted to JSON keys like `user_id` and `created_at` when encoding request bodies.

**Example:**

```swift
struct CreateUserEndpoint: Endpoint {
    let userData: UserData
    
    var path: String {
        return "/users"
    }
    
    var method: RequestMethod {
        return .post
    }
    
    var body: Data? {
        // UserData has properties: userId, userName, createdAt
        // These will be encoded as: user_id, user_name, created_at
        return try? encoder.encode(userData)
    }
}

struct UserData: Codable {
    let userId: Int
    let userName: String
    let createdAt: String
}
```

When this endpoint is used, the request body will be automatically encoded in snake_case:
```json
{
    "user_id": 123,
    "user_name": "testuser",
    "created_at": "2024-01-01"
}
```

#### Custom Encoding/Decoding

**Important**: If your model needs to handle special fields that don't follow snake_case convention (like `_id` or `_3ds`), you can use explicit `CodingKeys`:

```swift
struct MyModel: Codable {
    let id: String
    let userName: String
    let threeDS: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userName = "user_name"  // Still need to map snake_case fields
        case threeDS = "_3ds"
    }
}
```

**Note**: When you define `CodingKeys`, you must provide mappings for ALL properties. The snake_case conversion is ignored when `CodingKeys` are present, so you need to explicitly map all fields including snake_case ones.

#### Overriding Default Behavior

You can override the `encoder` property in your `Endpoint` implementation to customize encoding behavior:

```swift
struct CustomEndpoint: Endpoint {
    var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys  // Use camelCase instead
        return encoder
    }
    // ... other properties
}
```

Similarly, you can override the `decoder` property in your `HTTPClient` implementation to customize decoding behavior.

## License

Copyright © 2026 Paydock Ltd. All rights reserved.

## Contributing

Contributions are welcome! Please ensure:

1. All tests pass
2. New code includes appropriate tests
3. Code follows Swift style guidelines
4. Documentation is updated for new features

## Support

For issues, questions, or contributions, please open an issue on the repository.
