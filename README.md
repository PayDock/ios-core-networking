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
    case .decode:
        // Handle JSON decoding errors
        print("Failed to decode response")
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
    
    func sendRequest<T: Decodable>(
        endpoint: Endpoint,
        responseModel: T.Type
    ) async throws -> T
}
```

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
- `.decode` - JSON decoding failures
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

The library includes comprehensive test coverage with 53+ tests covering:

- ✅ HTTP client functionality and request/response handling
- ✅ Error handling and error types
- ✅ Endpoint configuration
- ✅ Request methods (GET, POST, PUT, PATCH, DELETE)
- ✅ Query parameters, headers, and body handling
- ✅ JSON decoding with snake_case conversion
- ✅ SSL pinning manager initialization
- ✅ Network configuration

To run tests:

```bash
swift test
```

Or in Xcode:
1. Press `Cmd+U` to run tests
2. Or use Product → Test


## Configuration

### URLSession Configuration

The default `URLSession` configuration includes:

- `waitsForConnectivity = true`
- `timeoutIntervalForRequest = 60` seconds
- `timeoutIntervalForResource = 300` seconds

You can override the `session` property in your `HTTPClient` implementation to customize these settings.

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
