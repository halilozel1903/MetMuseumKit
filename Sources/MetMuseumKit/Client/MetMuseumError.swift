import Foundation

/// Errors thrown by ``MetMuseumClient``.
public enum MetMuseumError: Error, Equatable, Sendable, LocalizedError {
    /// Nothing exists at this address (HTTP 404), such as an object ID that is not in the
    /// collection. `message` is the API's explanation when it sent one.
    case notFound(message: String?, url: URL)
    /// Any other unsuccessful HTTP status, with the API's message when it sent one.
    case http(statusCode: Int, message: String?, url: URL)
    /// The response was not JSON of the expected shape.
    case decoding(type: String, description: String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse
    /// The request can't be sent as asked, such as a search page past the first 10,000 results.
    case invalidRequest(String)

    public var errorDescription: String? {
        switch self {
        case let .notFound(message, _):
            return message ?? "The Met collection API has nothing at this address."
        case let .http(statusCode, message, _):
            return message.map { "The Met collection API answered with HTTP status \(statusCode): \($0)" }
                ?? "The Met collection API answered with HTTP status \(statusCode)."
        case let .decoding(type, _):
            return "The Met collection API sent data that could not be read as \(type)."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "The Met collection API sent an invalid response."
        case let .invalidRequest(reason):
            return reason
        }
    }

    /// Whether the error is a 404.
    public var isNotFound: Bool {
        if case .notFound = self { return true }
        return false
    }
}

/// The body the API sends with some errors: `{"message":"ObjectID not found"}`.
struct APIErrorBody: Decodable {
    let message: String?
    let error: String?

    var text: String? {
        message?.nonEmpty ?? error?.nonEmpty
    }
}
