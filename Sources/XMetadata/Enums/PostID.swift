//
//  PostID.swift
//  XMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Utility for extracting X/Twitter post IDs from various URL formats.
///
/// Supports `x.com` and `twitter.com` domains, with and without
/// tracking parameters.
public enum PostID {
    
    /// Regex patterns for extracting post IDs from X/Twitter URLs.
    private static let patterns = [
        "(?:x\\.com|twitter\\.com)\\/[a-zA-Z0-9_]+\\/status\\/(\\d+)",
    ]
    
    /// Extracts a post ID from a URL string.
    ///
    /// Accepts:
    /// - `https://x.com/user/status/1234567890`
    /// - `https://twitter.com/user/status/1234567890`
    /// - URLs with tracking parameters (stripped automatically)
    /// - Raw numeric post IDs
    ///
    /// - Parameter input: An X/Twitter URL or raw post ID.
    /// - Throws: ``XMetadataError/invalidPostId`` if no valid ID can be extracted.
    /// - Returns: The numeric post ID string.
    static func extract(from input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Raw numeric ID
        if trimmed.allSatisfy(\.isNumber), trimmed.count > 10 {
            return trimmed
        }
        
        // URL patterns
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if let match = regex.firstMatch(in: trimmed, range: range),
                   let idRange = Range(match.range(at: 1), in: trimmed) {
                    return String(trimmed[idRange])
                }
            }
        }
        
        throw XMetadataError.invalidPostId
    }
    
    /// Extracts the author handle from an X/Twitter URL.
    ///
    /// - Parameter input: An X/Twitter URL.
    /// - Returns: The handle (without @), or `nil` if not found.
    static func extractHandle(from input: String) -> String? {
        let pattern = "(?:x\\.com|twitter\\.com)\\/([a-zA-Z0-9_]+)\\/status\\/"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(input.startIndex..., in: input)
        guard let match = regex.firstMatch(in: input, range: range),
              let handleRange = Range(match.range(at: 1), in: input) else { return nil }
        return String(input[handleRange])
    }
    
}
