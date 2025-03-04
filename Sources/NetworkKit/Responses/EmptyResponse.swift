import Foundation

/// Represents an empty response from an API endpoint.
///
/// Used when an API call succeeds but returns no data,
/// typically for DELETE operations or status-only endpoints.
///
/// Example usage:
/// ```swift
/// let request = Request<EmptyResponse>(method: .delete, path: "/users/123")
/// let response = try await client.send(request)
/// ```
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
