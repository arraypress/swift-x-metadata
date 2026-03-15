//
//  PostMetadata.swift
//  XMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Metadata about an X (formerly Twitter) post.
///
/// Aggregated from multiple X endpoints (oembed, syndication, video config)
/// into a single unified struct. No authentication required.
///
/// ```swift
/// let post = try await XMetadata.fetch("https://x.com/user/status/123")
/// print("\(post.author) (@\(post.authorHandle))")
/// print(post.text)
/// print("Likes: \(post.formattedLikeCount)")
/// ```
public struct PostMetadata: Sendable {

    /// The post/tweet ID.
    public let id: String

    /// The full URL of the post.
    public let url: String

    /// The text content of the post.
    public let text: String

    /// The author's display name.
    public let author: String

    /// The author's handle (without @).
    public let authorHandle: String

    /// The author's profile URL.
    public let authorUrl: String

    /// The language code of the post (e.g., `"en"`).
    public let language: String?

    /// Number of likes/favorites.
    public let likeCount: Int?

    /// When the post was created.
    public let createdAt: Date?

    /// Hashtags used in the post.
    public let hashtags: [String]

    /// User mentions in the post (handles without @).
    public let mentions: [String]

    /// URLs included in the post text.
    public let urls: [String]

    /// Video metadata, if the post contains a video.
    public let video: VideoInfo?

    /// Photos attached to the post.
    ///
    /// Empty if the post has no images, or only has video.
    public let photos: [PhotoInfo]

    /// The like count formatted with locale-appropriate grouping separators.
    ///
    /// Returns `nil` if the like count is unavailable.
    public var formattedLikeCount: String? {
        guard let count = likeCount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count))
    }

    /// The creation date formatted as a readable string.
    ///
    /// Returns `nil` if the creation date is unavailable.
    public var formattedDate: String? {
        guard let date = createdAt else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    
}
