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

NetworkKit is configured via:
- `APIClientConfiguration` — client-level settings (retry policy, session, coders, cache)
- `RequestConfiguration` — per-request settings (base URL, auth, cache policy, timeout)

### APIClient Configuration
```swift
let client = APIClient(configuration: APIClientConfiguration(
    retryPolicy: .default,                 // default policy; override per call if needed
    urlSessionConfiguration: .default,     // timeouts, TLS, etc.
    decoder: .iso8601,                     // JSON decoder
    encoder: .iso8601,                     // JSON encoder
    cache: .shared                         // URLCache
))
```

### Request Configuration
```swift
let requestConfig = RequestConfiguration(
    baseURL: URL(string: "https://api.example.com"),
    timeoutInterval: 30,
    cachePolicy: .reloadIgnoringLocalCacheData,
    authenticationProvider: .none
)
```

Using these together lets you set reliable defaults at the client level while customizing behavior per request.

## Basic Usage

### Simple Request
```swift
// Make a GET request
 let userData: UserData = try await apiClient.send(
    Request<UserData>(method: .get, path: "/user", configuration: requestConfig)
 )

// POST request with body
let createUser = Request<UserResponse>(
    method: .post,
    path: "/users",
    body: UserData(name: "John", email: "john@example.com"),
    configuration: requestConfig
)
let response = try await apiClient.send(createUser)

// DELETE request with no response data
let deleteUser = Request<EmptyResponse>(
    method: .delete,
    path: "/users/123",
    configuration: requestConfig
)
_ = try await apiClient.send(deleteUser)

// Request with absolute URL
let request = Request<UserData>(
    method: .get,
    absoluteURL: URL(string: "https://api.example.com/users/123")!,
    configuration: RequestConfiguration()
)
```

### Authentication
NetworkKit supports custom authentication through the `AuthenticationProvider` protocol:

```swift
final class BearerTokenProvider: AuthenticationProvider {
    private var token: String
    
    func authenticate(_ request: inout URLRequest) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    func reauthenticate() async throws {
        // Refresh token logic here
    }
}

// Use with request via RequestConfiguration
let authConfig = RequestConfiguration(
    baseURL: URL(string: "https://api.example.com"),
    authenticationProvider: BearerTokenProvider()
)
let request = Request<UserData>(method: .get, path: "/protected/resource", configuration: authConfig)
```

For endpoints that don't require authentication, you can use the built-in `NoAuthProvider`:

```swift
// Using the static property (recommended)
let publicConfig = RequestConfiguration(
    baseURL: URL(string: "https://api.example.com"),
    authenticationProvider: .none
)
let request = Request<PublicData>(method: .get, path: "/public/data", configuration: publicConfig)

// Using the type directly
let request2 = Request<PublicData>(
    method: .get,
    path: "/public/data",
    configuration: RequestConfiguration(baseURL: URL(string: "https://api.example.com"), authenticationProvider: NoAuthProvider())
)

// Or rely on the default `.none` provider
let request3 = Request<PublicData>(method: .get, path: "/public/data", configuration: RequestConfiguration(baseURL: URL(string: "https://api.example.com")))
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
// Per-call override
let response = try await apiClient.send(request, retryPolicy: .default)

// Set a default at the client level
let client = APIClient(configuration: APIClientConfiguration(retryPolicy: .default))
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
        request: URLRequest,
        response: HTTPURLResponse,
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
    Request<CacheableData>(method: .get, path: "/cached-data", configuration: requestConfig),
    cached: true
)
```

### File Upload
```swift
let imageData = // ... your image data ...
let uploadRequest = Request<UploadResponse>(method: .post, path: "/upload", configuration: requestConfig)
let response = try await apiClient.upload(for: uploadRequest, from: imageData)
```

### Multipart Form Data
NetworkKit supports multipart form data for file uploads and form submissions:

```swift
let imageData = /* your image data */
let fields: [MultipartDataField] = [
    MultipartDataField(
        parameters: ["name": "avatar", "filename": "profile.jpg"],
        data: imageData,
        mimeType: "image/jpeg"
    ),
    MultipartDataField(
        parameters: ["name": "username"],
        data: Data("john_doe".utf8),
        mimeType: nil
    )
]

let request = Request<UploadResponse>(
    method: .post,
    path: "/upload",
    contentType: .multipartData(fields),
    configuration: requestConfig
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
