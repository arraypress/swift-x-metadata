//
//  XMetadata.swift
//  XMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetch metadata from X (formerly Twitter) posts without authentication.
///
/// `XMetadata` aggregates data from three public X endpoints — oembed, syndication,
/// and video config — to build a comprehensive metadata response. No API key,
/// developer account, or authentication is required.
///
/// ## Quick Start
///
/// ```swift
/// import XMetadata
///
/// let post = try await XMetadata.fetch("https://x.com/ladbible/status/1100414780655906816")
///
/// print(post.text)
/// print("\(post.author) (@\(post.authorHandle))")
/// print("Likes: \(post.formattedLikeCount ?? "N/A")")
///
/// if let video = post.video {
///     print("Duration: \(video.formattedDuration)")
///     print("Views: \(video.viewCount ?? "N/A")")
/// }
/// ```
///
/// ## How It Works
///
/// Three public endpoints are queried and merged:
///
/// 1. **oembed** (`publish.twitter.com/oembed`) — author name, handle, post URL
/// 2. **syndication** (`cdn.syndication.twimg.com/tweet-result`) — full text, likes, date,
///    hashtags, mentions, language, video MP4 variants, photo URLs
/// 3. **video config** (`api.twitter.com/1.1/videos/tweet/config`) — video duration, view
///    count, HLS playback URL (only called for video posts)
public enum XMetadata {
    
    // MARK: - Configuration
    
    /// X/Twitter's public bearer token, used for guest token activation and video config requests.
    ///
    /// This is the same token embedded in Twitter's web application JavaScript and is used
    /// by all major scraping libraries. It is not a personal or secret credential.
    private static let bearerToken = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"
    
    /// The User-Agent header sent with all requests.
    ///
    /// Uses a Chrome UA string as it represents the most common browser traffic globally,
    /// providing the best anonymity for scraping requests.
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    // MARK: - Public API
    
    /// Fetches metadata for an X/Twitter post.
    ///
    /// Queries up to three public endpoints in parallel and merges the results into a single
    /// ``PostMetadata`` struct. The video config endpoint is only called when the syndication
    /// response indicates the post contains video media.
    ///
    /// Supports all common URL formats:
    /// - `https://x.com/user/status/123`
    /// - `https://twitter.com/user/status/123` (legacy domain)
    /// - `https://x.com/user/status/123?s=46&t=abc` (tracking params stripped automatically)
    /// - `"1100414780655906816"` (raw numeric post ID)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let post = try await XMetadata.fetch("https://x.com/ladbible/status/1100414780655906816")
    ///
    /// // Basic info
    /// print(post.text)
    /// print(post.author)
    /// print(post.formattedLikeCount ?? "N/A")
    ///
    /// // Video download URL (highest quality MP4)
    /// if let mp4Url = post.video?.bestMp4Url {
    ///     print("Download: \(mp4Url)")
    /// }
    ///
    /// // Photos
    /// for photo in post.photos {
    ///     print("\(photo.url) (\(photo.width)x\(photo.height))")
    /// }
    ///
    /// // Entities
    /// print(post.hashtags)
    /// print(post.mentions)
    /// print(post.urls)
    /// ```
    ///
    /// - Parameter input: An X/Twitter post URL or numeric post ID.
    /// - Throws: ``XMetadataError`` if the metadata cannot be retrieved.
    /// - Returns: A ``PostMetadata`` with all available fields populated.
    public static func fetch(_ input: String) async throws -> PostMetadata {
        let postId = try PostID.extract(from: input)
        let handleFromUrl = PostID.extractHandle(from: input)
        
        // Fetch oembed and syndication in parallel
        async let oembedTask = fetchOembed(postId: postId, input: input)
        async let syndicationTask = fetchSyndication(postId: postId)
        
        let oembed = try? await oembedTask
        let syndication = try? await syndicationTask
        
        // If both failed, the post probably doesn't exist
        if oembed == nil && syndication == nil {
            throw XMetadataError.postNotFound
        }
        
        // Check if video is present and fetch video config
        var videoInfo: VideoInfo? = nil
        let hasVideo = syndication?.hasVideo ?? false
        
        // Extract video variants from syndication mediaDetails
        var videoVariants: [VideoVariant] = []
        var videoDurationMs: Int = 0
        if let mediaDetails = syndication?.mediaDetails {
            for media in mediaDetails {
                let mediaType = media["type"] as? String
                if mediaType == "video" || mediaType == "animated_gif" {
                    if let videoInfoDict = media["video_info"] as? [String: Any] {
                        videoDurationMs = videoInfoDict["duration_millis"] as? Int ?? 0
                        
                        if let variants = videoInfoDict["variants"] as? [[String: Any]] {
                            for variant in variants {
                                if let url = variant["url"] as? String,
                                   let contentType = variant["content_type"] as? String {
                                    videoVariants.append(VideoVariant(
                                        url: url,
                                        contentType: contentType,
                                        bitrate: variant["bitrate"] as? Int
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if hasVideo {
            let config = try? await fetchVideoConfig(postId: postId)
            videoInfo = VideoInfo(
                contentId: config?.contentId ?? "",
                durationMs: config?.durationMs ?? videoDurationMs,
                playbackUrl: config?.playbackUrl ?? "",
                viewCount: config?.viewCount,
                shouldLoop: config?.shouldLoop ?? false,
                variants: videoVariants
            )
        }
        
        // Extract photos from syndication mediaDetails
        var photos: [PhotoInfo] = []
        if let mediaDetails = syndication?.mediaDetails {
            for media in mediaDetails {
                if (media["type"] as? String) == "photo" {
                    if let url = media["media_url_https"] as? String {
                        let w = (media["original_info"] as? [String: Any])?["width"] as? Int
                        ?? (media["sizes"] as? [String: Any]).flatMap { ($0["large"] as? [String: Any])?["w"] as? Int }
                        ?? 0
                        let h = (media["original_info"] as? [String: Any])?["height"] as? Int
                        ?? (media["sizes"] as? [String: Any]).flatMap { ($0["large"] as? [String: Any])?["h"] as? Int }
                        ?? 0
                        photos.append(PhotoInfo(url: url, width: w, height: h))
                    }
                }
            }
        }
        
        // Extract entities from syndication
        let entities = syndication?.entities
        let hashtags = extractHashtags(from: entities)
        let mentions = extractMentions(from: entities)
        let urls = extractUrls(from: entities)
        
        // Parse creation date (supports both fractional seconds and standard ISO 8601)
        var createdAt: Date? = nil
        if let dateStr = syndication?.createdAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: dateStr)
            if createdAt == nil {
                formatter.formatOptions = [.withInternetDateTime]
                createdAt = formatter.date(from: dateStr)
            }
        }
        
        // Build the canonical URL
        let handle = oembed?.authorHandle ?? handleFromUrl ?? ""
        let postUrl = oembed?.url ?? "https://x.com/\(handle)/status/\(postId)"

        // Author identity from the syndication user dict (richer than oembed)
        let user = syndication?.user
        let authorId = user?["id_str"] as? String
        let authorVerified = (user?["is_blue_verified"] as? Bool)
            ?? (user?["verified"] as? Bool)
            ?? false
        let authorProfileImageUrl = user?["profile_image_url_https"] as? String

        return PostMetadata(
            id: postId,
            url: postUrl,
            text: syndication?.text ?? oembed?.extractedText ?? "",
            author: oembed?.authorName ?? "",
            authorHandle: handle,
            authorUrl: oembed?.authorUrl ?? "https://x.com/\(handle)",
            language: syndication?.language,
            likeCount: syndication?.favoriteCount,
            createdAt: createdAt,
            hashtags: hashtags,
            mentions: mentions,
            urls: urls,
            video: videoInfo,
            photos: photos,
            authorId: authorId,
            authorVerified: authorVerified,
            authorProfileImageUrl: authorProfileImageUrl,
            replyCount: syndication?.replyCount,
            viewCount: syndication?.viewCount
        )
    }
    
    // MARK: - Oembed Endpoint
    
    /// Internal response from the oembed endpoint.
    private struct OembedResponse {
        let url: String
        let authorName: String
        let authorHandle: String
        let authorUrl: String
        let html: String
        let extractedText: String?
    }
    
    /// Fetches post metadata from X's public oembed endpoint.
    ///
    /// The oembed endpoint (`publish.twitter.com/oembed`) provides the author's display name,
    /// handle, profile URL, and an HTML embed snippet from which the post text can be extracted.
    /// No authentication is required.
    ///
    /// - Parameters:
    ///   - postId: The numeric post/tweet ID.
    ///   - input: The original user-provided URL or ID string, used to construct the oembed request.
    /// - Throws: ``XMetadataError`` on network failure, rate limiting, or if the post is not found.
    /// - Returns: An ``OembedResponse`` containing the author info and extracted text.
    private static func fetchOembed(postId: String, input: String) async throws -> OembedResponse {
        let twitterUrl = input.contains("x.com") || input.contains("twitter.com")
        ? input.components(separatedBy: "?").first ?? input
        : "https://x.com/i/status/\(postId)"
        
        let encodedUrl = twitterUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? twitterUrl
        guard let url = URL(string: "https://publish.twitter.com/oembed?url=\(encodedUrl)") else {
            throw XMetadataError.parsingError("Invalid oembed URL")
        }
        
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 404 { throw XMetadataError.postNotFound }
            if httpResponse.statusCode == 429 { throw XMetadataError.rateLimited }
            if httpResponse.statusCode != 200 { throw XMetadataError.networkError("oembed HTTP \(httpResponse.statusCode)") }
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw XMetadataError.parsingError("Invalid oembed JSON")
        }
        
        let authorUrl = json["author_url"] as? String ?? ""
        let handle = authorUrl.components(separatedBy: "/").last ?? ""
        
        // Extract text from the HTML embed (content between <p> tags, with HTML tags stripped)
        let html = json["html"] as? String ?? ""
        var extractedText: String? = nil
        if let regex = try? NSRegularExpression(pattern: "<p[^>]*>(.*?)</p>", options: .dotMatchesLineSeparators) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, range: range),
               let textRange = Range(match.range(at: 1), in: html) {
                let raw = String(html[textRange])
                extractedText = raw.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&mdash;", with: "—")
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return OembedResponse(
            url: json["url"] as? String ?? "",
            authorName: json["author_name"] as? String ?? "",
            authorHandle: handle,
            authorUrl: authorUrl,
            html: html,
            extractedText: extractedText
        )
    }
    
    // MARK: - Syndication Endpoint
    
    /// Internal response from the syndication endpoint.
    private struct SyndicationResponse {
        let text: String
        let language: String?
        let favoriteCount: Int?
        let replyCount: Int?
        let viewCount: Int?
        let createdAt: String?
        let entities: [String: Any]?
        let user: [String: Any]?
        let hasVideo: Bool
        let mediaDetails: [[String: Any]]?
    }
    
    /// Fetches post metadata from X's public syndication endpoint.
    ///
    /// The syndication endpoint (`cdn.syndication.twimg.com/tweet-result`) provides the richest
    /// data of the three endpoints: full post text, like count, creation date, language, entity
    /// data (hashtags, mentions, URLs), and media details including video variants with direct
    /// MP4 download URLs and photo URLs with dimensions.
    ///
    /// No authentication is required. A request-specific `token` is derived from the post ID
    /// (the same algorithm X's web client uses) and the `Googlebot` User-Agent is sent, both
    /// of which yield fuller, less-frequently-blocked responses than a dummy `token=0`.
    ///
    /// - Parameter postId: The numeric post/tweet ID.
    /// - Throws: ``XMetadataError`` on network failure, rate limiting, or if the post is not found.
    /// - Returns: A ``SyndicationResponse`` containing the post text, engagement data, entities, and media details.
    private static func fetchSyndication(postId: String) async throws -> SyndicationResponse {
        let token = generateSyndicationToken(postId)
        guard let url = URL(string: "https://cdn.syndication.twimg.com/tweet-result?id=\(postId)&token=\(token)") else {
            throw XMetadataError.parsingError("Invalid syndication URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Googlebot", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 404 { throw XMetadataError.postNotFound }
            if httpResponse.statusCode == 429 { throw XMetadataError.rateLimited }
            if httpResponse.statusCode != 200 { throw XMetadataError.networkError("syndication HTTP \(httpResponse.statusCode)") }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw XMetadataError.parsingError("Invalid syndication JSON")
        }

        // Locate media entities — prefer top-level mediaDetails, fall back to entities.media
        let entities = json["entities"] as? [String: Any]
        let mediaEntities = json["mediaDetails"] as? [[String: Any]]
        ?? (entities?["media"] as? [[String: Any]])
        let hasVideo = mediaEntities?.contains(where: {
            ($0["type"] as? String) == "video" || ($0["type"] as? String) == "animated_gif"
        }) ?? false

        // View count lives on the top-level `video` dict and may be an Int or a String
        let videoDict = json["video"] as? [String: Any]
        let viewCount: Int? = {
            if let v = videoDict?["viewCount"] as? Int { return v }
            if let s = videoDict?["viewCount"] as? String { return Int(s) }
            return nil
        }()

        return SyndicationResponse(
            text: json["text"] as? String ?? "",
            language: json["lang"] as? String,
            favoriteCount: json["favorite_count"] as? Int,
            replyCount: json["conversation_count"] as? Int,
            viewCount: viewCount,
            createdAt: json["created_at"] as? String,
            entities: entities,
            user: json["user"] as? [String: Any],
            hasVideo: hasVideo,
            mediaDetails: mediaEntities
        )
    }

    /// Derives the syndication request token from a post ID.
    ///
    /// Ports X's web-client algorithm:
    /// `((Number(id) / 1e15) * Math.PI).toString(36).replace(/(0+|\.)/g, '')`.
    /// The endpoint tolerates `token=0`, but the derived token matches what the
    /// official embed uses and is less likely to be rate-limited or blocked.
    ///
    /// - Parameter postId: The numeric post/tweet ID.
    /// - Returns: The base-36 token string with dots and zeros removed.
    static func generateSyndicationToken(_ postId: String) -> String {
        let digits = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        var value = ((Double(postId) ?? 0) / 1e15) * Double.pi
        var result = ""

        // Integer part
        let intPart = Int(value)
        value -= Double(intPart)
        if intPart == 0 {
            result = "0"
        } else {
            var n = intPart
            var s = ""
            while n > 0 {
                s = String(digits[n % 36]) + s
                n /= 36
            }
            result = s
        }

        // Fractional part
        if value > 0 {
            result += "."
            for _ in 0..<12 {
                value *= 36
                let digit = Int(value)
                result += String(digits[digit])
                value -= Double(digit)
                if value == 0 { break }
            }
        }

        // Remove dots and zeros, matching the JS .replace(/(0+|\.)/g, '')
        return result
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "0", with: "")
    }
    
    // MARK: - Video Config Endpoint
    
    /// Internal response from the video config endpoint.
    private struct VideoConfigResponse {
        let contentId: String
        let durationMs: Int
        let playbackUrl: String
        let viewCount: String?
        let shouldLoop: Bool
    }
    
    /// Fetches video-specific metadata from X's video config endpoint.
    ///
    /// The video config endpoint (`api.twitter.com/1.1/videos/tweet/config`) provides the HLS
    /// playback URL, precise duration in milliseconds, view count (pre-formatted by X), and
    /// loop settings. It requires a guest token, which is fetched automatically via
    /// ``fetchGuestToken()``.
    ///
    /// This method is only called when the syndication response indicates the post contains
    /// video or animated GIF media.
    ///
    /// - Parameter postId: The numeric post/tweet ID.
    /// - Throws: ``XMetadataError`` on network failure, rate limiting, or invalid response.
    /// - Returns: A ``VideoConfigResponse`` containing the video playback details.
    private static func fetchVideoConfig(postId: String) async throws -> VideoConfigResponse {
        let guestToken = try await fetchGuestToken()
        
        guard let url = URL(string: "https://api.twitter.com/1.1/videos/tweet/config/\(postId).json") else {
            throw XMetadataError.parsingError("Invalid video config URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(guestToken, forHTTPHeaderField: "x-guest-token")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 { throw XMetadataError.rateLimited }
            if httpResponse.statusCode != 200 { throw XMetadataError.networkError("video config HTTP \(httpResponse.statusCode)") }
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let track = json["track"] as? [String: Any] else {
            throw XMetadataError.parsingError("Invalid video config JSON")
        }
        
        return VideoConfigResponse(
            contentId: track["contentId"] as? String ?? "",
            durationMs: (track["durationMs"] as? Int) ?? Int(track["durationMs"] as? Double ?? 0),
            playbackUrl: track["playbackUrl"] as? String ?? "",
            viewCount: track["viewCount"] as? String,
            shouldLoop: track["shouldLoop"] as? Bool ?? false
        )
    }
    
    // MARK: - Guest Token
    
    /// Fetches a temporary guest token from X's public activation endpoint.
    ///
    /// Guest tokens are short-lived tokens that allow unauthenticated access to certain
    /// X API endpoints (like video config). A new token is obtained for each request
    /// to avoid expiration issues.
    ///
    /// The request requires the public bearer token in the `Authorization` header.
    ///
    /// - Throws: ``XMetadataError`` on network failure or rate limiting.
    /// - Returns: A guest token string to use in subsequent API requests.
    private static func fetchGuestToken() async throws -> String {
        guard let url = URL(string: "https://api.twitter.com/1.1/guest/activate.json") else {
            throw XMetadataError.parsingError("Invalid guest token URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 { throw XMetadataError.rateLimited }
            if httpResponse.statusCode != 200 { throw XMetadataError.networkError("guest token HTTP \(httpResponse.statusCode)") }
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["guest_token"] as? String else {
            throw XMetadataError.parsingError("Could not extract guest token")
        }
        
        return token
    }
    
    // MARK: - Entity Extraction
    
    /// Extracts hashtag text values from the syndication entities dictionary.
    ///
    /// Looks for the `hashtags` array within the entities dictionary, where each
    /// element is a dictionary containing a `"text"` key with the hashtag value
    /// (without the `#` prefix).
    ///
    /// - Parameter entities: The entities dictionary from the syndication response.
    /// - Returns: An array of hashtag strings, or an empty array if none are found.
    private static func extractHashtags(from entities: [String: Any]?) -> [String] {
        guard let hashtags = entities?["hashtags"] as? [[String: Any]] else { return [] }
        return hashtags.compactMap { $0["text"] as? String }
    }
    
    /// Extracts user mention screen names from the syndication entities dictionary.
    ///
    /// Looks for the `user_mentions` array within the entities dictionary, where each
    /// element is a dictionary containing a `"screen_name"` key with the handle
    /// (without the `@` prefix).
    ///
    /// - Parameter entities: The entities dictionary from the syndication response.
    /// - Returns: An array of screen name strings, or an empty array if none are found.
    private static func extractMentions(from entities: [String: Any]?) -> [String] {
        guard let mentions = entities?["user_mentions"] as? [[String: Any]] else { return [] }
        return mentions.compactMap { $0["screen_name"] as? String }
    }
    
    /// Extracts expanded URLs from the syndication entities dictionary.
    ///
    /// Looks for the `urls` array within the entities dictionary, preferring the
    /// `"expanded_url"` field over `"url"` (which contains the shortened `t.co` form).
    ///
    /// - Parameter entities: The entities dictionary from the syndication response.
    /// - Returns: An array of URL strings, or an empty array if none are found.
    private static func extractUrls(from entities: [String: Any]?) -> [String] {
        guard let urls = entities?["urls"] as? [[String: Any]] else { return [] }
        return urls.compactMap { $0["expanded_url"] as? String ?? $0["url"] as? String }
    }
    
}
