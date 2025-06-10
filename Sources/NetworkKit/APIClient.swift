import Foundation

/// Interface defining the APIClient's capabilities for dependency injection.
///
/// This protocol allows for easier testing by defining the required
/// functionality that can be mocked.
public protocol APIClientProtocol: Sendable {
    /// Sends a network request and decodes the response.
    func send<T: Decodable & Sendable>(_ request: Request<T>, retryPolicy: RetryPolicy, cached: Bool) async throws -> T

    /// Uploads data with a network request and decodes the response.
    func upload<T: Decodable & Sendable>(for request: Request<T>, from data: Data, retryPolicy: RetryPolicy) async throws -> T

    /// Downloads data from a URL with retry support.
    func data(for request: Request<Data>, retryPolicy: RetryPolicy) async throws -> Data

    /// Downloads data from a raw URL with retry support.
    func data(for url: URL, retryPolicy: RetryPolicy, authenticationProvider: AuthenticationProvider) async throws -> Data
}

/// An actor that handles network requests with built-in retry and authentication support.
///
/// APIClient provides a type-safe way to make network requests with automatic
/// JSON encoding/decoding, authentication, caching, and retry capabilities.
///
/// Example usage:
/// ```swift
/// let client = APIClient()
/// let response: UserData = try await client.send(
///     Request<UserData>(method: .get, path: "/user")
/// )
/// ```
public actor APIClient: APIClientProtocol {
    /// The URLSession used for network requests
    ///
    /// Created lazily with the current configuration settings
    private var session: URLSession {
        URLSession(configuration: NetworkManager.configuration.urlSessionConfiguration)
    }

    /// JSON decoder used for parsing responses
    private var decoder: JSONDecoder { NetworkManager.configuration.decoder }

    /// JSON encoder used for request bodies
    private var encoder: JSONEncoder { NetworkManager.configuration.encoder }

    /// Cache for storing and retrieving responses
    private var cache: URLCache { NetworkManager.configuration.cache }

    /// Creates a new APIClient with the specified configuration.
    public init() {}

    /// Sends a network request and decodes the response.
    ///
    /// - Parameters:
    ///   - request: The typed request to send
    ///   - retryPolicy: Policy determining retry behavior for failed requests
    ///   - cached: Whether to use cached responses if available
    /// - Returns: The decoded response of type T
    /// - Throws: APIError or any error from the network request or decoding
    @discardableResult
    public func send<T: Decodable & Sendable>(
        _ request: Request<T>,
        retryPolicy: RetryPolicy = NetworkManager.configuration.retryPolicy,
        cached: Bool = false
    ) async throws -> T {
        let urlRequest = try await request.asURLRequest()

        let (data, response) = try await fetchResponse(for: urlRequest, useCaching: cached)

        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        return try await handleResponse(response, data: data, for: request, cached: cached, retryPolicy: retryPolicy)
    }

    /// Uploads data with a network request and decodes the response.
    ///
    /// - Parameters:
    ///   - request: The typed request to send
    ///   - data: The data to upload
    ///   - retryPolicy: Policy determining retry behavior for failed requests
    /// - Returns: The decoded response of type T
    /// - Throws: APIError or any error from the network request or decoding
    @discardableResult
    public func upload<T: Decodable & Sendable>(
        for request: Request<T>,
        from data: Data,
        retryPolicy: RetryPolicy = NetworkManager.configuration.retryPolicy
    ) async throws -> T {
        let urlRequest = try await request.asURLRequest()
        let (responseData, response) = try await session.upload(for: urlRequest, from: data)

        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        return try await handleResponse(response, data: responseData, for: request, cached: false, retryPolicy: retryPolicy)
    }

    /// Downloads data from a URL with retry support.
    ///
    /// - Parameters:
    ///   - request: The request for raw data
    ///   - retryPolicy: Policy determining retry behavior for failed requests
    /// - Returns: The downloaded data
    /// - Throws: APIError or any network request error
    public func data(for request: Request<Data>, retryPolicy: RetryPolicy = NetworkManager.configuration.retryPolicy) async throws -> Data {
        let urlRequest = try await request.asURLRequest()
        let (data, response) = try await session.data(for: urlRequest)

        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        return try await handleResponse(response, data: data, for: request, cached: false, retryPolicy: retryPolicy)
    }

    /// Downloads data from a raw URL with retry support.
    ///
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - retryPolicy: Policy determining retry behavior for failed requests
    /// - Returns: The downloaded data
    /// - Throws: APIError or any network request error
    public func data(
        for url: URL,
        retryPolicy: RetryPolicy = NetworkManager.configuration.retryPolicy,
        authenticationProvider: AuthenticationProvider = NetworkManager.configuration.authProvider
    ) async throws -> Data {
        let urlRequest = URLRequest(url: url)
        let (data, response) = try await session.data(for: urlRequest)

        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200 ... 299 ~= response.statusCode else {
            guard try await retryPolicy.shouldRetry(
                request: urlRequest,
                response: response,
                data: data,
                authenticationProvider: authenticationProvider
            ) else {
                throw APIError.httpError(response: response, data: data)
            }

            return try await self.data(for: url, retryPolicy: retryPolicy)
        }

        return data
    }

    private func fetchResponse(for request: URLRequest, useCaching: Bool) async throws -> (Data, URLResponse) {
        if useCaching, let cachedResponse = cache.cachedResponse(for: request) {
            return (cachedResponse.data, cachedResponse.response)
        }

        let (data, response) = try await session.data(for: request)

        if useCaching {
            cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
        }

        return (data, response)
    }

    private func handleResponse<T: Decodable & Sendable>(
        _ response: HTTPURLResponse,
        data: Data,
        for request: Request<T>,
        cached: Bool,
        retryPolicy: RetryPolicy
    ) async throws -> T {
        guard 200 ... 299 ~= response.statusCode else {
            guard try await retryPolicy.shouldRetry(
                request: try await request.asURLRequest(),
                response: response,
                data: data,
                authenticationProvider: request.authenticationProvider
            ) else {
                throw APIError.httpError(response: response, data: data)
            }

            return try await send(request, cached: cached)
        }

        guard T.self != EmptyResponse.self else {
            return EmptyResponse() as! T
        }

        return try decoder.decode(T.self, from: data)
    }
}
