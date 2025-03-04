import Foundation

/// A policy that never retries requests
///
/// This policy is useful when you want to disable retries for all requests.
public struct NoRetryPolicy: RetryPolicy {
    public init() {}

    /// This method always returns false, indicating that no retries should be attempted.
    ///
    /// - Parameters:
    ///   - request: The original URLRequest that failed
    ///   - response: The HTTP response from the failed request
    ///   - data: Response data from the failed request
    ///   - authenticationProvider: The authentication provider
    /// - Returns: Always false, indicating no retries
    public func shouldRetry(
        request _: URLRequest,
        response _: HTTPURLResponse,
        data _: Data,
        authenticationProvider _: AuthenticationProvider
    ) async throws -> Bool { false }
}

extension RetryPolicy where Self == NoRetryPolicy {
    /// A static property that returns a NoRetryPolicy instance.
    /// Use when you want to explicitly disable retries.
    ///
    /// Example:
    /// ```swift
    /// let request = Request<Data>(
    ///     method: .get,
    ///     path: "/data",
    ///     retryPolicy: .none
    /// )
    /// ```
    public static var none: NoRetryPolicy { NoRetryPolicy() }
}
