# NetworkKit

NetworkKit is a networking module that's part of the ShipKit framework. It provides networking utilities and components for Swift applications.

## Features

- Type-safe network requests with automatic JSON encoding/decoding
- Built-in authentication support with customizable providers
- Configurable retry policies with exponential backoff
- Request caching capabilities
- Multipart form data support
- Comprehensive error handling with localized messages
- Support for uploads and downloads
- Modern async/await API

## Requirements

- iOS 15.0+
- macOS 12.0+
- tvOS 15.0+
- watchOS 8.0+
- visionOS 1.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add NetworkKit to your project through Xcode's Swift Package Manager:

1. In Xcode, select "File" → "Add Packages..."
2. Enter the repository URL: `https://github.com/ysmaliak/NetworkKit.git`
3. Select the version you want to use

Or add it to your `Package.swift` file:
```swift
dependencies: [
    .package(url: "https://github.com/ysmaliak/NetworkKit.git", from: "1.0.0")
]
```

## Configuration

NetworkKit can be configured globally using the `NetworkManager`. You can configure it in several ways:

### Default Configuration
```swift
// Use default settings (no base URL, default session config, ISO8601 JSON coding)
NetworkManager.configure()
```

### Custom Configuration
```swift
// Configure with individual settings
NetworkManager.configure(
    baseURL: URL(string: "https://api.example.com"),
    retryPolicy: .default,
    authProvider: .none,
    urlSessionConfiguration: .default,
    decoder: .iso8601,
    encoder: .iso8601,
    cache: .shared,
    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
    timeoutInterval: 30
)

// Or use a configuration object
var config = NetworkKit.Configuration(
    baseURL: URL(string: "https://api.example.com"),
    retryPolicy: .default,
    authProvider: .none,
    urlSessionConfiguration: .default,
    decoder: .iso8601,
    encoder: .iso8601,
    cache: .shared,
    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
    timeoutInterval: 30
)

NetworkManager.configure(with: config)
```

The configuration allows you to customize:
- Base URL for all requests
- Retry policy for failed requests
- Authentication provider for all requests
- URLSession configuration (timeouts, connection limits, TLS settings)
- JSON encoding/decoding strategies
- Response caching behavior and policy
- Default timeout interval

## Basic Usage

### Simple Request
```swift
let apiClient = APIClient()

// Make a GET request
let userData: UserData = try await apiClient.send(
    Request<UserData>(method: .get, path: "/user")
)

// POST request with body
let createUser = Request<UserResponse>(
    method: .post,
    path: "/users",
    body: UserData(name: "John", email: "john@example.com")
)
let response = try await apiClient.send(createUser)

// DELETE request with no response data
let deleteUser = Request<EmptyResponse>(
    method: .delete, 
    path: "/users/123"
)
_ = try await apiClient.send(deleteUser)

// Request with absolute URL
let request = Request<UserData>(
    method: .get,
    absoluteURL: URL(string: "https://api.example.com/users/123")!
)
```

### Authentication
NetworkKit supports custom authentication through the `AuthenticationProvider` protocol:

```swift
class BearerTokenProvider: AuthenticationProvider {
    private var token: String
    
    func authenticate(_ request: inout URLRequest) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    func reauthenticate() async throws {
        // Refresh token logic here
    }
}

// Use with request
let request = Request<UserData>(
    method: .get,
    path: "/protected/resource",
    authenticationProvider: BearerTokenProvider()
)
```

For endpoints that don't require authentication, you can use the built-in `NoAuthProvider`:

```swift
// Using the static property (recommended)
let request = Request<PublicData>(
    method: .get,
    path: "/public/data",
    authenticationProvider: .none
)

// Using the type directly
let request = Request<PublicData>(
    method: .get,
    path: "/public/data",
    authenticationProvider: NoAuthProvider()
)

// Or omit the authenticationProvider parameter to use NoAuthProvider by default
let request = Request<PublicData>(method: .get, path: "/public/data")
```

The `NoAuthProvider` is the default authentication provider and implements a no-op authentication strategy, meaning it:
- Performs no modifications to the request during `authenticate`
- Does nothing during `reauthenticate`
- Is suitable for public endpoints or when authentication is handled elsewhere

### Retry Policies
NetworkKit includes built-in retry support with configurable policies. The framework provides three built-in policies:

1. `DefaultRetryPolicy`: Implements exponential backoff with authentication handling
2. `NoRetryPolicy`: Never retries requests
3. Custom policies through the `RetryPolicy` protocol

#### Built-in Policies

##### Default Retry Policy
The `DefaultRetryPolicy` provides:
- Maximum of 3 retry attempts
- Automatic handling of authentication failures (401, 403) with reauthentication
- Retry for transient errors (408, 500, 502, 503, 504) with exponential backoff
- Base delay of 0.3 seconds between retries

```swift
// Using static property (recommended)
let response = try await apiClient.send(request, retryPolicy: .default)

// Using type directly
let response = try await apiClient.send(request, retryPolicy: DefaultRetryPolicy())
```

##### No Retry Policy
Use when you want to explicitly disable retries:

```swift
// Using static property (recommended)
let response = try await apiClient.send(request, retryPolicy: .none)

// Using type directly
let response = try await apiClient.send(request, retryPolicy: NoRetryPolicy())
```

#### Custom Retry Policies
You can create custom retry policies by implementing the `RetryPolicy` protocol:

```swift
final actor CustomRetryPolicy: RetryPolicy {
    private var currentAttempt = 0
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let retryableStatusCodes: Set<Int>
    
    init(maxRetries: Int = 5, baseDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.retryableStatusCodes = [429, 503, 504] // Rate limit and server errors
    }
    
    func shouldRetry(
        for response: HTTPURLResponse,
        data: Data,
        authenticationProvider: AuthenticationProvider
    ) async throws -> Bool {
        guard currentAttempt < maxRetries else { return false }
        currentAttempt += 1
        
        if retryableStatusCodes.contains(response.statusCode) {
            // Exponential backoff with jitter
            let delay = baseDelay * pow(2.0, Double(currentAttempt - 1))
            let jitter = Double.random(in: 0...0.3)
            try await Task.sleep(nanoseconds: UInt64((delay + jitter) * Double(NSEC_PER_SEC)))
            return true
        }
        
        return false
    }
}

// Use custom retry policy
let customPolicy = CustomRetryPolicy(maxRetries: 5, baseDelay: 1.0)
let response = try await apiClient.send(request, retryPolicy: customPolicy)
```

When implementing a custom retry policy, consider:
- Maximum number of retries
- Delay between attempts (fixed, exponential, or custom)
- Which HTTP status codes should trigger retries
- Adding jitter to prevent thundering herd problems
- Handling of specific error responses
- Integration with authentication if needed

### Caching
Enable response caching for GET requests:

```swift
let cachedResponse = try await apiClient.send(
    Request<CacheableData>(method: .get, path: "/cached-data"),
    cached: true
)
```

### File Upload
```swift
let imageData = // ... your image data ...
let response = try await apiClient.upload(
    for: Request<UploadResponse>(method: .post, path: "/upload"),
    from: imageData
)
```

### Multipart Form Data
NetworkKit supports multipart form data for file uploads and form submissions:

```swift
let imageData = // ... your image data ...
let fields: [MultipartDataField] = [
    .file(name: "avatar", filename: "profile.jpg", data: imageData, contentType: "image/jpeg"),
    .text(name: "username", value: "john_doe")
]

let request = Request<UploadResponse>(
    method: .post,
    path: "/upload",
    contentType: .multipartData(fields)
)
let response = try await apiClient.send(request)
```

### Error Handling
NetworkKit provides comprehensive error handling with localized error messages in multiple languages:

```swift
do {
    let response = try await apiClient.send(request)
} catch let error as APIError {
    switch error {
    case .invalidResponse:
        // Handle invalid response
        print(error.localizedDescription) // "Unable to process server response"
        print(error.failureReason) // "The response contained unexpected data"
    case .httpError(let response, let data):
        // Handle HTTP error with response and data
        print(error.localizedDescription) // "Request failed"
        print(error.failureReason) // "The server could not process the request"
    }
}
```

## License

NetworkKit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Author

Yan Smaliak
