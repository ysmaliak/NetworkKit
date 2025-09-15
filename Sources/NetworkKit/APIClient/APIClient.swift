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
/// // Configure the client (retry policy, session, coders, cache)
/// let client = APIClient(configuration: APIClientConfiguration(
///     retryPolicy: .default,
///     urlSessionConfiguration: .default,
///     decoder: .iso8601,
///     encoder: .iso8601,
///     cache: .shared
/// ))
///
/// // Configure the request (base URL, auth, cache policy, timeout)
/// let requestConfig = RequestConfiguration(
///     baseURL: URL(string: "https://api.example.com"),
///     timeoutInterval: 30,
///     cachePolicy: .reloadIgnoringLocalCacheData,
///     authenticationProvider: .none
/// )
///
/// // Build and send a request
/// let response: UserData = try await client.send(
///     Request<UserData>(method: .get, path: "/user", configuration: requestConfig)
/// )
/// ```
public actor APIClient: APIClientProtocol {
    /// The retry policy for the APIClient
    private let retryPolicy: RetryPolicy

    /// The URLSession used for network requests
    private let session: URLSession

    /// JSON decoder used for parsing responses
    private let decoder: JSONDecoder

    /// JSON encoder used for request bodies
    private let encoder: JSONEncoder

    /// Cache for storing and retrieving responses
    private let cache: URLCache

    /// Creates a new APIClient with the specified configuration.
    ///
    /// - Parameter configuration: Settings controlling retry policy, URLSession,
    ///   JSON encoding/decoding, and caching behavior for requests issued by this client.
    public init(configuration: APIClientConfiguration) {
        retryPolicy = configuration.retryPolicy
        session = URLSession(configuration: configuration.urlSessionConfiguration)
        decoder = configuration.decoder
        encoder = configuration.encoder
        cache = configuration.cache
    }

    /// Sends a network request and decodes the response using the client's default retry policy.
    ///
    /// To override the retry behavior for a single request, use the overload that takes a
    /// `retryPolicy` parameter.
    ///
    /// - Parameters:
    ///   - request: The typed request to send.
    ///   - cached: Whether to use cached responses if available. Defaults to `false`.
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `APIError` or any error from the network request or decoding.
    @discardableResult
    public func send<T: Decodable & Sendable>(_ request: Request<T>, cached: Bool = false) async throws -> T {
        try await send(request, retryPolicy: retryPolicy, cached: cached)
    }

    /// Sends a network request and decodes the response.
    ///
    /// - Parameters:
    ///   - request: The typed request to send
    ///   - retryPolicy: Policy determining retry behavior for failed requests
    ///   - cached: Whether to use cached responses if available. Defaults to `false`.
    /// - Returns: The decoded response of type T
    /// - Throws: APIError or any error from the network request or decoding
    @discardableResult
    public func send<T: Decodable & Sendable>(
        _ request: Request<T>,
        retryPolicy: RetryPolicy,
        cached: Bool = false
    ) async throws -> T {
        let urlRequest = try await request.asURLRequest(encoder: encoder)

        let (data, response) = try await fetchResponse(for: urlRequest, useCaching: cached)

        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        return try await handleResponse(response, data: data, for: request, cached: cached, retryPolicy: retryPolicy)
    }

    /// Uploads data for a request using the client's default retry policy.
    ///
    /// To override retry behavior for this upload only, use the overload that takes a
    /// `retryPolicy` parameter.
    ///
    /// - Parameters:
    ///   - request: The typed request to send.
    ///   - data: The data to upload as the HTTP body.
    /// - Returns: The decoded response of type `T`.
    /// - Throws: `APIError` or any error from the network request or decoding.
    @discardableResult
    public func upload<T: Decodable & Sendable>(for request: Request<T>, from data: Data) async throws -> T {
        try await upload(for: request, from: data, retryPolicy: retryPolicy)
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
        retryPolicy: RetryPolicy
    ) async throws -> T {
        let urlRequest = try await request.asURLRequest(encoder: encoder)
        let (responseData, response) = try await session.upload(for: urlRequest, from: data)

        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        return try await handleResponse(response, data: responseData, for: request, cached: false, retryPolicy: retryPolicy)
    }

    /// Downloads raw data for a typed request using the client's default retry policy.
    ///
    /// - Parameter request: The request describing the resource to fetch.
    /// - Returns: The downloaded data.
    /// - Throws: `APIError` or any network request error.
    public func data(for request: Request<Data>) async throws -> Data {
        try await data(for: request, retryPolicy: retryPolicy)
    }

    /// Downloads data from a URL with retry support.
    ///
    /// - Parameters:
    ///   - request: The request for raw data
    ///   - retryPolicy: Policy determining retry behavior for failed requests
    /// - Returns: The downloaded data
    /// - Throws: APIError or any network request error
    public func data(for request: Request<Data>, retryPolicy: RetryPolicy) async throws -> Data {
        let urlRequest = try await request.asURLRequest(encoder: encoder)
        let (data, response) = try await session.data(for: urlRequest)

        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        return try await handleResponse(response, data: data, for: request, cached: false, retryPolicy: retryPolicy)
    }

    /// Downloads raw data from a URL using the client's default retry policy.
    ///
    /// - Parameters:
    ///   - url: The absolute URL to download from.
    ///   - authenticationProvider: Provider used to authenticate the request.
    /// - Returns: The downloaded data.
    /// - Throws: `APIError` or any network request error.
    public func data(for url: URL, authenticationProvider: AuthenticationProvider) async throws -> Data {
        try await data(for: url, retryPolicy: retryPolicy, authenticationProvider: authenticationProvider)
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
        retryPolicy: RetryPolicy,
        authenticationProvider: AuthenticationProvider
    ) async throws -> Data {
        var urlRequest = URLRequest(url: url)
        try await authenticationProvider.authenticate(&urlRequest)
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

            return try await self.data(for: url, retryPolicy: retryPolicy, authenticationProvider: authenticationProvider)
        }

        return data
    }

    private func fetchResponse(for request: URLRequest, useCaching: Bool) async throws -> (Data, URLResponse) {
        let isGet = request.httpMethod?.uppercased() == "GET"

        if useCaching, isGet, let cachedResponse = cache.cachedResponse(for: request) {
            return (cachedResponse.data, cachedResponse.response)
        }

        let (data, response) = try await session.data(for: request)

        if useCaching, isGet {
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
                request: await request.asURLRequest(encoder: encoder),
                response: response,
                data: data,
                authenticationProvider: request.authenticationProvider
            ) else {
                throw APIError.httpError(response: response, data: data)
            }

            // Preserve the per-call retry policy on recursive retry attempts
            return try await send(request, retryPolicy: retryPolicy, cached: cached)
        }

        guard T.self != EmptyResponse.self else {
            return EmptyResponse() as! T
        }

        return try decoder.decode(T.self, from: data)
    }
}
