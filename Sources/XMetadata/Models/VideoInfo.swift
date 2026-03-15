//
//  VideoInfo.swift
//  XMetadata
//
//  Created by David Sherlock on 3/15/26.
//

import Foundation

/// Metadata about a video attached to an X post.
public struct VideoInfo: Sendable {

    /// The video's content ID on X's platform.
    public let contentId: String

    /// Video duration in milliseconds.
    public let durationMs: Int

    /// The HLS playback URL (`.m3u8`).
    public let playbackUrl: String

    /// View count as a formatted string (e.g., `"91.1K"`).
    ///
    /// X returns this pre-formatted rather than as a raw number.
    public let viewCount: String?

    /// Whether the video should loop on playback.
    public let shouldLoop: Bool

    /// Available video format variants (MP4s at different bitrates, HLS).
    ///
    /// Extracted from the syndication response's `mediaDetails.video_info.variants`.
    /// Use ``bestMp4Url`` for the highest quality direct download.
    public let variants: [VideoVariant]

    /// The highest-bitrate direct MP4 download URL.
    ///
    /// This is the URL you want for downloading/transcribing — not the HLS `.m3u8`.
    /// Returns `nil` if no MP4 variants are available.
    public var bestMp4Url: URL? {
        variants
            .filter { $0.contentType == "video/mp4" }
            .sorted { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }
            .first
            .flatMap { URL(string: $0.url) }
    }

    /// Video duration in seconds.
    public var durationSeconds: Double {
        Double(durationMs) / 1000.0
    }

    /// The duration formatted as `"M:SS"` or `"H:MM:SS"`.
    public var formattedDuration: String {
        let total = Int(durationSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
    
}
