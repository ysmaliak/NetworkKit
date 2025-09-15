import Foundation

/// Represents errors that can occur during API operations
public enum APIError: Error, LocalizedError {
    /// Indicates the response received was invalid or couldn't be parsed
    case invalidResponse

    /// Indicates an HTTP error occurred with associated response and data
    /// - response: The HTTP response containing status code and headers
    /// - data: Raw response data that might contain error details
    case httpError(response: HTTPURLResponse, data: Data)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            String(localized: "apiErrorInvalidResponseDescription", bundle: .module)
        case .httpError:
            String(localized: "apiErrorHttpErrorDescription", bundle: .module)
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidResponse:
            String(localized: "apiErrorInvalidResponseReason", bundle: .module)
        case .httpError:
            String(localized: "apiErrorHttpErrorReason", bundle: .module)
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidResponse:
            String(localized: "apiErrorInvalidResponseSuggestion", bundle: .module)
        case .httpError:
            String(localized: "apiErrorHttpErrorSuggestion", bundle: .module)
        }
    }
}
