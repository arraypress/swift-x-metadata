//
//  XMetadataError.swift
//  XMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Errors that can occur when fetching X post metadata.
///
/// ```swift
/// do {
///     let post = try await XMetadata.fetch(url)
/// } catch XMetadataError.invalidUrl {
///     print("Not a valid X/Twitter URL")
/// } catch XMetadataError.postNotFound {
///     print("Post doesn't exist or was deleted")
/// } catch {
///     print(error.localizedDescription)
/// }
/// ```
public enum XMetadataError: Error, LocalizedError, Equatable, Sendable {

    /// The provided URL is not a valid X/Twitter post URL.
    case invalidUrl

    /// Could not extract a post ID from the URL.
    case invalidPostId

    /// The post was not found (deleted, private, or suspended).
    case postNotFound

    /// X is rate-limiting requests from this IP.
    case rateLimited

    /// A network request failed.
    case networkError(String)

    /// Failed to parse response data.
    case parsingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid X/Twitter URL. Provide a URL like https://x.com/user/status/1234567890"
        case .invalidPostId:
            return "Could not extract a post ID from the URL."
        case .postNotFound:
            return "Post not found. It may have been deleted or set to private."
        case .rateLimited:
            return "X is rate-limiting requests. Try again later."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        }
    }
    
}
