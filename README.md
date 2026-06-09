# Swift X Metadata

A dependency-free Swift library for fetching metadata from X (formerly Twitter) posts without authentication. XMetadata aggregates three public X endpoints — oembed, syndication, and video config — into a single unified `PostMetadata` struct. No API key, developer account, or login is required.

## Features

- 🔓 **No authentication** — works against public X endpoints with no API key or developer account
- 🧩 **Unified metadata** — one `XMetadata.fetch(_:)` call merges oembed, syndication, and video config into a single `PostMetadata`
- 🔗 **Flexible input** — accepts `x.com` and legacy `twitter.com` URLs, URLs with tracking params (stripped automatically), and raw numeric post IDs
- 📝 **Rich post data** — full text, language, like count, creation date, hashtags, mentions, and expanded URLs
- 👤 **Author identity** — display name, handle, profile URL, plus `authorId`, `authorVerified`, and `authorProfileImageUrl` from the syndication response
- 📊 **Engagement metrics** — `likeCount`, `replyCount`, and an integer `viewCount` surfaced alongside the video config's formatted view string
- 🎬 **Video downloads** — `VideoInfo` exposes duration, HLS playback URL, and MP4 variants, with `bestMp4Url` for the highest-bitrate direct download
- 🖼️ **Photo metadata** — every attached image with its direct URL and pixel dimensions
- ⚡ **Parallel fetching** — oembed and syndication are requested concurrently; the video config endpoint is only hit for posts that contain video
- 🛡️ **Typed errors** — `XMetadataError` distinguishes invalid URLs, missing posts, rate limiting, network, and parsing failures
- 📦 **Sendable models** — all public types are `Sendable` and safe across concurrency domains

## Requirements

- macOS 13.0+ / iOS 16.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-x-metadata.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies…** and enter `https://github.com/arraypress/swift-x-metadata`.

## Usage

### Fetching post metadata

```swift
import XMetadata

let post = try await XMetadata.fetch("https://x.com/ladbible/status/1100414780655906816")

print(post.text)
print("\(post.author) (@\(post.authorHandle))")
print("Likes: \(post.formattedLikeCount ?? "N/A")")
print("Posted: \(post.formattedDate ?? "N/A")")
```

### Author identity and engagement

```swift
import XMetadata

let post = try await XMetadata.fetch("1100414780655906816") // raw post ID

if post.authorVerified { print("Verified account") }
print("Author ID: \(post.authorId ?? "N/A")")
print("Avatar: \(post.authorProfileImageUrl ?? "N/A")")
print("Replies: \(post.replyCount ?? 0)")
print("Views: \(post.viewCount ?? 0)")
```

### Video downloads

```swift
import XMetadata

let post = try await XMetadata.fetch("https://x.com/user/status/123")

if let video = post.video {
    print("Duration: \(video.formattedDuration)")
    print("Views: \(video.viewCount ?? "N/A")")

    if let mp4 = video.bestMp4Url {
        print("Download: \(mp4)")
    }
}
```

### Photos and entities

```swift
import XMetadata

let post = try await XMetadata.fetch("https://x.com/user/status/123")

for photo in post.photos {
    print("\(photo.url) (\(photo.width)x\(photo.height))")
}

print(post.hashtags)
print(post.mentions)
print(post.urls)
```

### Error handling

```swift
import XMetadata

do {
    let post = try await XMetadata.fetch(input)
} catch XMetadataError.invalidPostId {
    print("Not a valid X/Twitter URL or post ID")
} catch XMetadataError.postNotFound {
    print("Post doesn't exist or was deleted")
} catch XMetadataError.rateLimited {
    print("Rate limited — try again later")
} catch {
    print(error.localizedDescription)
}
```

## How It Works

`XMetadata.fetch(_:)` extracts the numeric post ID, then queries up to three public X endpoints and merges the results:

1. **oembed** (`publish.twitter.com/oembed`) — author display name, handle, profile URL, and an HTML embed from which post text can be extracted.
2. **syndication** (`cdn.syndication.twimg.com/tweet-result`) — the richest source: full text, like and reply counts, view count, creation date, language, entities (hashtags, mentions, URLs), author identity, and media details including MP4 variants and photo URLs. A request token is derived from the post ID using X's own base-36 algorithm.
3. **video config** (`api.twitter.com/1.1/videos/tweet/config`) — only called for video posts; supplies the HLS playback URL, precise duration, formatted view count, and loop setting, using an automatically-fetched guest token.

oembed and syndication are fetched in parallel. If both fail, the post is treated as missing.

## Models

| Type | Kind | Description |
|------|------|-------------|
| `PostMetadata` | struct | Aggregated post data (see field table below) |
| `VideoInfo` | struct | `contentId`, `durationMs`, `playbackUrl`, `viewCount`, `shouldLoop`, `variants`, plus `bestMp4Url`, `durationSeconds`, `formattedDuration` |
| `VideoVariant` | struct | `url`, `contentType`, `bitrate` for a single MP4/HLS variant |
| `PhotoInfo` | struct | `url`, `width`, `height` for an attached photo |
| `PostID` | enum | URL/ID extraction utilities |
| `XMetadataError` | enum | Typed errors with `errorDescription` |

### PostMetadata fields

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | The post/tweet ID |
| `url` | `String` | Canonical post URL |
| `text` | `String` | Full post text |
| `author` | `String` | Author display name |
| `authorHandle` | `String` | Author handle (without `@`) |
| `authorUrl` | `String` | Author profile URL |
| `authorId` | `String?` | Author numeric user ID |
| `authorVerified` | `Bool` | Whether the author is verified (blue or legacy) |
| `authorProfileImageUrl` | `String?` | Author avatar URL (HTTPS) |
| `language` | `String?` | Post language code (e.g. `"en"`) |
| `likeCount` | `Int?` | Number of likes/favorites |
| `replyCount` | `Int?` | Number of replies (conversation count) |
| `viewCount` | `Int?` | Raw integer view count |
| `createdAt` | `Date?` | When the post was created |
| `hashtags` | `[String]` | Hashtags used (without `#`) |
| `mentions` | `[String]` | Mentioned handles (without `@`) |
| `urls` | `[String]` | Expanded URLs in the post |
| `video` | `VideoInfo?` | Video metadata, if present |
| `photos` | `[PhotoInfo]` | Attached photos |

`PostMetadata` also provides computed `formattedLikeCount` and `formattedDate` helpers.

## Use Cases

- Link previews and embeds without the official X API
- Archiving post text, engagement, and media
- Downloading the highest-quality MP4 from video posts for transcription or backup
- Building moderation or analytics tooling over public posts

## Testing

```bash
swift test
```

The test suite exercises URL/ID extraction, the syndication token algorithm, and live metadata fetching across text, photo, and video posts.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
