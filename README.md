# Swift X Metadata

A Swift library for fetching metadata from X (formerly Twitter) posts. No API key, developer account, or authentication required — uses X's public endpoints.

## Features

- 🎯 **Simple API** — fetch post metadata with a single async call
- 📊 **Rich metadata** — text, author, likes, date, language, hashtags, mentions, URLs
- 🎬 **Video info** — duration, view count, HLS playback URL, direct MP4 download URLs
- 🖼️ **Photo support** — direct image URLs with dimensions for photo posts
- 🔒 **No API key required** — uses public oembed, syndication, and guest token endpoints
- 🍎 **Cross-platform** — macOS, iOS, tvOS, watchOS
- ⚡ **Async/await** native — built for modern Swift concurrency
- 🛡️ **Typed error handling** — specific errors for every failure case
- 🔗 **Flexible input** — supports `x.com`, `twitter.com`, and raw post IDs

## Requirements

- macOS 13.0+ / iOS 16.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-x-metadata.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Choose version requirements

## Usage

### Fetch Post Metadata

```swift
import XMetadata

let post = try await XMetadata.fetch("https://x.com/ladbible/status/1100414780655906816")

print(post.text)
print("\(post.author) (@\(post.authorHandle))")
print("Likes: \(post.formattedLikeCount ?? "N/A")")
print("Date: \(post.formattedDate ?? "N/A")")
print("Language: \(post.language ?? "N/A")")
```

### Video Info

```swift
let post = try await XMetadata.fetch("https://x.com/user/status/123")

if let video = post.video {
    print("Duration: \(video.formattedDuration)")
    print("Views: \(video.viewCount ?? "N/A")")
    print("HLS URL: \(video.playbackUrl)")
    print("Loops: \(video.shouldLoop)")

    // Direct MP4 download (best quality) — use this for downloading/transcribing
    if let mp4Url = video.bestMp4Url {
        print("Download: \(mp4Url)")
    }

    // All available variants
    for variant in video.variants {
        print("\(variant.contentType) — \(variant.bitrate ?? 0)bps — \(variant.url)")
    }
}
```

### Photos

```swift
let post = try await XMetadata.fetch("https://x.com/user/status/123")

for photo in post.photos {
    print("\(photo.url) (\(photo.width)x\(photo.height))")
}
```

### Post Entities

```swift
let post = try await XMetadata.fetch("https://x.com/user/status/123")

print("Hashtags: \(post.hashtags)")    // ["swift", "ios"]
print("Mentions: \(post.mentions)")    // ["apple", "xcode"]
print("URLs: \(post.urls)")            // ["https://example.com"]
```

### URL Formats

All common X/Twitter URL formats are supported:

```swift
// x.com
let post = try await XMetadata.fetch("https://x.com/user/status/123")

// twitter.com (legacy)
let post = try await XMetadata.fetch("https://twitter.com/user/status/123")

// With tracking parameters (stripped automatically)
let post = try await XMetadata.fetch("https://x.com/user/status/123?s=46&t=abc123")

// Raw post ID
let post = try await XMetadata.fetch("1100414780655906816")
```

### Error Handling

```swift
do {
    let post = try await XMetadata.fetch(url)
    print(post.text)
} catch XMetadataError.postNotFound {
    print("Post doesn't exist or was deleted")
} catch XMetadataError.rateLimited {
    print("Too many requests — try again later")
} catch XMetadataError.invalidPostId {
    print("Couldn't extract a post ID from the URL")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## Models

### `PostMetadata`

The main result struct containing all post data.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Post/tweet ID |
| `url` | `String` | Full post URL |
| `text` | `String` | Post text content |
| `author` | `String` | Author's display name |
| `authorHandle` | `String` | Author's handle (without @) |
| `authorUrl` | `String` | Author's profile URL |
| `language` | `String?` | Language code (e.g., "en") |
| `likeCount` | `Int?` | Number of likes |
| `formattedLikeCount` | `String?` | Likes with grouping separators |
| `createdAt` | `Date?` | Creation date |
| `formattedDate` | `String?` | Readable date string |
| `hashtags` | `[String]` | Hashtags in the post |
| `mentions` | `[String]` | User mentions (without @) |
| `urls` | `[String]` | URLs in the post text |
| `video` | `VideoInfo?` | Video metadata (if present) |
| `photos` | `[PhotoInfo]` | Photos attached to the post |

### `VideoInfo`

Video-specific metadata (only present for video posts).

| Property | Type | Description |
|----------|------|-------------|
| `contentId` | `String` | X's internal video ID |
| `durationMs` | `Int` | Duration in milliseconds |
| `durationSeconds` | `Double` | Duration in seconds |
| `formattedDuration` | `String` | Duration as `"M:SS"` or `"H:MM:SS"` |
| `playbackUrl` | `String` | HLS `.m3u8` playback URL |
| `viewCount` | `String?` | Pre-formatted view count (e.g., "91.1K") |
| `shouldLoop` | `Bool` | Whether the video loops |
| `variants` | `[VideoVariant]` | Available formats (MP4s at different bitrates, HLS) |
| `bestMp4Url` | `URL?` | Highest-bitrate direct MP4 download URL |

### `VideoVariant`

A single video format variant.

| Property | Type | Description |
|----------|------|-------------|
| `url` | `String` | Direct URL to this variant |
| `contentType` | `String` | MIME type (`"video/mp4"` or `"application/x-mpegURL"`) |
| `bitrate` | `Int?` | Bitrate in bps (`nil` for HLS) |

### `PhotoInfo`

A photo attached to a post.

| Property | Type | Description |
|----------|------|-------------|
| `url` | `String` | Direct image URL |
| `width` | `Int` | Width in pixels |
| `height` | `Int` | Height in pixels |

## How It Works

The library queries three public X endpoints and merges the results:

1. **oembed** (`publish.twitter.com/oembed`) — author name, handle, post URL. No auth needed.
2. **syndication** (`cdn.syndication.twimg.com/tweet-result`) — full text, like count, creation date, language, hashtags, mentions, media info, video MP4 variants, photo URLs. No auth needed.
3. **video config** (`api.twitter.com/1.1/videos/tweet/config`) — video duration, view count, HLS playback URL. Uses a public guest token (fetched automatically).

The video config endpoint is only called when the syndication response indicates the post contains video. For text-only posts, only two requests are made.

## Limitations

- **Rate limiting** — X may rate-limit requests from IPs making too many calls. Reduce frequency if you encounter `rateLimited` errors.
- **No transcript/captions** — X video captions are burned into the video frames, not served as separate text tracks.
- **Guest token** — The video config endpoint requires a guest token which is fetched automatically. These tokens expire, but a fresh one is obtained for each request.
- **Endpoint stability** — These are unofficial endpoints that X may change at any time. Updates will be provided as needed.

## Testing

```bash
swift test
```

The test suite includes unit tests for ID extraction, formatting, and error handling, plus integration tests that hit X's live endpoints.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
