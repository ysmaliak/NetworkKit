import Foundation

/// Default implementation of RetryPolicy with exponential backoff
///
/// This policy implements a retry strategy with the following characteristics:
/// - Maximum of 3 retry attempts
/// - Authentication retries (401, 403): Triggers reauthentication immediately
/// - General retries (408, 500, 502, 503, 504): Uses exponential backoff starting at 0.3 seconds
///
/// The retry flow works as follows:
/// 1. If max retries reached (3 attempts), no more retries
/// 2. For auth errors, attempts reauthentication before retry
/// 3. For general errors, waits with exponential backoff before retry
/// 4. All other status codes are not retried
public final actor DefaultRetryPolicy: RetryPolicy {
    /// Current retry attempt number (0-based)
    private var currentAttempt = 0

    /// Maximum number of retry attempts allowed
    private let maxRetries = 3

    /// Base delay in seconds for exponential backoff
    private let baseDelay: TimeInterval = 0.3

    /// HTTP status codes that trigger authentication retry
    private let authRetryableStatusCodes: Set<Int> = [401, 403]

    /// HTTP status codes that trigger general retry with backoff
    private let generalRetryableStatusCodes: Set<Int> = [408, 500, 502, 503, 504]

    /// Initializes a new DefaultRetryPolicy instance.
    ///
    /// This policy is used to handle retries with exponential backoff and authentication handling.
    public init() {}

    /// This method implements the retry logic with exponential backoff and authentication handling.
    ///
    /// - Parameters:
    ///   - response: The HTTPURLResponse from the request
    ///   - data: The data returned from the request
    ///   - authenticationProvider: The authentication provider
    /// - Returns: A boolean indicating whether to retry the request
    public func shouldRetry(
        for response: HTTPURLResponse,
        data _: Data,
        authenticationProvider: AuthenticationProvider
    ) async throws -> Bool {
        guard currentAttempt < maxRetries else { return false }
        currentAttempt += 1

        guard !authRetryableStatusCodes.contains(response.statusCode) else {
            try await authenticationProvider.reauthenticate()
            return true
        }

        guard !generalRetryableStatusCodes.contains(response.statusCode) else {
            try await Task.sleep(nanoseconds: UInt64(baseDelay * Double(NSEC_PER_SEC)))
            return true
        }

        return false
    }
}

extension RetryPolicy where Self == DefaultRetryPolicy {
    /// A static property that returns a DefaultRetryPolicy instance.
    /// Provides exponential backoff with authentication handling.
    ///
    /// Example:
    /// ```swift
    /// let request = Request<Data>(
    ///     method: .get,
    ///     path: "/data",
    ///     retryPolicy: .default
    /// )
    /// ```
    public static var `default`: DefaultRetryPolicy { DefaultRetryPolicy() }
}
