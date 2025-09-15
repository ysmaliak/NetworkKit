import Foundation

/// Configuration values that control how a `Request` is constructed.
public struct RequestConfiguration: Sendable {
    /// Base URL used with the `path` to build the request URL.
    ///
    /// Note: When a `Request` is constructed with an `absoluteURL`, that value is used and this
    /// base URL is ignored. Use `nil` if you always provide absolute URLs.
    public let baseURL: URL?

    /// Optional timeout interval for the request.
    public let timeoutInterval: TimeInterval?

    /// Cache policy applied to the constructed `URLRequest`.
    public let cachePolicy: URLRequest.CachePolicy

    /// Authentication provider used to authenticate the request.
    public let authenticationProvider: AuthenticationProvider

    /// Creates a new configuration.
    /// - Parameters:
    ///   - baseURL: Base URL for relative-path requests. Ignored when a `Request` uses `absoluteURL`.
    ///     Defaults to `nil`.
    ///   - timeoutInterval: Timeout in seconds; pass `nil` to use the system default.
    ///     Defaults to `30`.
    ///   - cachePolicy: Cache policy for the request.
    ///     Defaults to `.reloadIgnoringLocalCacheData`.
    ///   - authenticationProvider: Provider used to authenticate the request.
    ///     Defaults to `.none`.
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
