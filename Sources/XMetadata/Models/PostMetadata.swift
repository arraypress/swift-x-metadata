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

    /// The author's numeric user ID, when available from syndication.
    public let authorId: String?

    /// Whether the author is verified (blue check or legacy verified).
    public let authorVerified: Bool

    /// The author's profile image URL (HTTPS), when available from syndication.
    public let authorProfileImageUrl: String?

    /// The language code of the post (e.g., `"en"`).
    public let language: String?

    /// Number of likes/favorites.
    public let likeCount: Int?

    /// Number of replies (X's conversation count), when available.
    public let replyCount: Int?

    /// View count as a raw integer, when available from syndication.
    ///
    /// Complements ``VideoInfo/viewCount`` — a pre-formatted string from the
    /// video config endpoint — with a raw integer when X's syndication
    /// response provides one.
    public let viewCount: Int?

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

    /// Creates post metadata.
    ///
    /// The author identity, reply count, and integer view count are sourced
    /// from X's syndication response and default to empty when unavailable, so
    /// existing call sites need not provide them.
    public init(
        id: String,
        url: String,
        text: String,
        author: String,
        authorHandle: String,
        authorUrl: String,
        language: String?,
        likeCount: Int?,
        createdAt: Date?,
        hashtags: [String],
        mentions: [String],
        urls: [String],
        video: VideoInfo?,
        photos: [PhotoInfo],
        authorId: String? = nil,
        authorVerified: Bool = false,
        authorProfileImageUrl: String? = nil,
        replyCount: Int? = nil,
        viewCount: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.text = text
        self.author = author
        self.authorHandle = authorHandle
        self.authorUrl = authorUrl
        self.authorId = authorId
        self.authorVerified = authorVerified
        self.authorProfileImageUrl = authorProfileImageUrl
        self.language = language
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.viewCount = viewCount
        self.createdAt = createdAt
        self.hashtags = hashtags
        self.mentions = mentions
        self.urls = urls
        self.video = video
        self.photos = photos
    }

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
