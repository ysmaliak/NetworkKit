import Foundation

/// Configuration values that control how a `Request` is constructed.
public struct RequestConfiguration: Sendable {
    /// Base URL used with the `path` to build the request URL. Use `nil` when providing an `absoluteURL`.
    public let baseURL: URL?

    /// Optional timeout interval for the request.
    public let timeoutInterval: TimeInterval?

    /// Cache policy applied to the constructed `URLRequest`.
    public let cachePolicy: URLRequest.CachePolicy

    /// Authentication provider used to authenticate the request.
    public let authenticationProvider: AuthenticationProvider

    /// Creates a new configuration.
    /// - Parameters:
    ///   - baseURL: Base URL for relative-path requests. Use `nil` for absolute URLs.
    ///   - timeoutInterval: Timeout in seconds; pass `nil` to use the system default.
    ///   - cachePolicy: Cache policy for the request.
    ///   - authenticationProvider: Provider used to authenticate the request; defaults to `.none`.
    public init(
        baseURL: URL? = nil,
        timeoutInterval: TimeInterval? = 30,
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData,
        authenticationProvider: AuthenticationProvider = .none
    ) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = cachePolicy
        self.authenticationProvider = authenticationProvider
    }
}

// No nested alias; prefer top-level `RequestConfiguration` directly.
