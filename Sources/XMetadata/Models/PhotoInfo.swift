//
//  PhotoInfo.swift
//  XMetadata
//
//  Created by David Sherlock on 3/15/26.
//

import Foundation

/// A photo attached to an X post.
public struct PhotoInfo: Sendable {

    /// The direct image URL.
    public let url: String

    /// Image width in pixels.
    public let width: Int

    /// Image height in pixels.
    public let height: Int
    
}
