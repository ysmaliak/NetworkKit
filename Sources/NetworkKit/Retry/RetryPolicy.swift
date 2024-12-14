import Foundation

/// Defines the retry behavior for network requests that fail.
///
/// Implement this protocol to create custom retry strategies for handling
/// failed network requests, such as authentication failures or rate limiting.
///
/// Example implementation:
/// ```swift
/// struct BasicRetryPolicy: RetryPolicy {
///     func shouldRetry(
///         for response: HTTPURLResponse,
///         data: Data,
///         authenticationProvider: AuthenticationProvider
///     ) async throws -> Bool {
///         return response.statusCode == 429 // Retry on rate limit
///     }
/// }
/// ```
public protocol RetryPolicy: Sendable {
    /// Determines if a retry should be attempted for a failed request
    /// - Parameters:
    ///   - response: The HTTP response from the failed request
    ///   - data: Response data from the failed request
    ///   - authenticationProvider: The authentication provider for handling auth-related retries
    /// - Returns: `true` if the request should be retried, `false` otherwise
    func shouldRetry(for response: HTTPURLResponse, data: Data, authenticationProvider: AuthenticationProvider) async throws -> Bool
}
