//
//  VideoVariant.swift
//  XMetadata
//
//  Created by David Sherlock on 3/15/26.
//

import Foundation

/// A single video format variant (MP4 at a specific bitrate, or HLS stream).
public struct VideoVariant: Sendable {

    /// The direct URL to this variant.
    public let url: String

    /// The MIME type (e.g., `"video/mp4"`, `"application/x-mpegURL"`).
    public let contentType: String

    /// The bitrate in bits per second. `nil` for HLS streams.
    public let bitrate: Int?
    
}
