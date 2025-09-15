import Foundation

/// Configuration values that control how an `APIClient` performs requests.
public struct APIClientConfiguration: Sendable {
    /// Default retry policy used when a call-site does not supply one explicitly.
    public let retryPolicy: RetryPolicy

    /// The `URLSessionConfiguration` used to construct the underlying `URLSession`.
    public let urlSessionConfiguration: URLSessionConfiguration

    /// Decoder used to decode response payloads.
    public let decoder: JSONDecoder

    /// Encoder used to encode request bodies.
    public let encoder: JSONEncoder

    /// Cache used for storing and retrieving cached responses.
    public let cache: URLCache

    /// Creates a new configuration.
    ///
    /// - Parameters:
    ///   - retryPolicy: Default retry behavior for requests. Use `.default` for
    ///     exponential backoff with auth handling or `.none` to disable retries.
    ///   - urlSessionConfiguration: Session configuration (timeouts, TLS, caching).
    ///   - decoder: JSON decoder for response decoding. Defaults to `.iso8601`.
    ///   - encoder: JSON encoder for request bodies. Defaults to `.iso8601`.
    ///   - cache: Cache used for response caching. Defaults to `.shared`.
    public init(
        retryPolicy: RetryPolicy = .default,
        urlSessionConfiguration: URLSessionConfiguration = .default,
        decoder: JSONDecoder = .iso8601,
        encoder: JSONEncoder = .iso8601,
        cache: URLCache = .shared
    ) {
        self.retryPolicy = retryPolicy
        self.urlSessionConfiguration = urlSessionConfiguration
        self.decoder = decoder
        self.encoder = encoder
        self.cache = cache
    }
}

// No nested alias; prefer top-level `APIClientConfiguration` directly.
