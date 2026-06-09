//
//  XMetadataTests.swift
//  XMetadata
//
//  Created by David Sherlock on 2026.
//

import XCTest
@testable import XMetadata

final class XMetadataTests: XCTestCase {

    // MARK: - Post ID Extraction

    func testExtractFromXUrl() throws {
        let id = try PostID.extract(from: "https://x.com/ladbible/status/1100414780655906816")
        XCTAssertEqual(id, "1100414780655906816")
    }

    func testExtractFromTwitterUrl() throws {
        let id = try PostID.extract(from: "https://twitter.com/ladbible/status/1100414780655906816")
        XCTAssertEqual(id, "1100414780655906816")
    }

    func testExtractFromUrlWithParams() throws {
        let id = try PostID.extract(from: "https://x.com/ladbible/status/1100414780655906816?s=46&t=MKzV8g6iaFM_3WabaWjh1g")
        XCTAssertEqual(id, "1100414780655906816")
    }

    func testExtractFromRawId() throws {
        let id = try PostID.extract(from: "1100414780655906816")
        XCTAssertEqual(id, "1100414780655906816")
    }

    func testExtractWithWhitespace() throws {
        let id = try PostID.extract(from: "  1100414780655906816  ")
        XCTAssertEqual(id, "1100414780655906816")
    }

    func testExtractInvalidThrows() {
        XCTAssertThrowsError(try PostID.extract(from: "not-a-valid-url")) { error in
            XCTAssertEqual(error as? XMetadataError, .invalidPostId)
        }
    }

    func testExtractEmptyStringThrows() {
        XCTAssertThrowsError(try PostID.extract(from: "")) { error in
            XCTAssertEqual(error as? XMetadataError, .invalidPostId)
        }
    }

    // MARK: - Handle Extraction

    func testExtractHandleFromXUrl() {
        let handle = PostID.extractHandle(from: "https://x.com/ladbible/status/1100414780655906816")
        XCTAssertEqual(handle, "ladbible")
    }

    func testExtractHandleFromTwitterUrl() {
        let handle = PostID.extractHandle(from: "https://twitter.com/elonmusk/status/1234567890")
        XCTAssertEqual(handle, "elonmusk")
    }

    func testExtractHandleFromInvalidUrl() {
        let handle = PostID.extractHandle(from: "https://example.com/test")
        XCTAssertNil(handle)
    }

    // MARK: - VideoInfo

    func testVideoFormattedDuration() {
        let video = VideoInfo(contentId: "test", durationMs: 87133, playbackUrl: "", viewCount: "91.1K", shouldLoop: false, variants: [])
        XCTAssertEqual(video.formattedDuration, "1:27")
        XCTAssertEqual(video.durationSeconds, 87.133, accuracy: 0.001)
    }

    func testVideoFormattedDurationHours() {
        let video = VideoInfo(contentId: "test", durationMs: 3661000, playbackUrl: "", viewCount: nil, shouldLoop: false, variants: [])
        XCTAssertEqual(video.formattedDuration, "1:01:01")
    }

    func testVideoFormattedDurationShort() {
        let video = VideoInfo(contentId: "test", durationMs: 15000, playbackUrl: "", viewCount: nil, shouldLoop: true, variants: [])
        XCTAssertEqual(video.formattedDuration, "0:15")
        XCTAssertTrue(video.shouldLoop)
    }

    func testBestMp4Url() {
        let variants = [
            VideoVariant(url: "https://example.com/low.mp4", contentType: "video/mp4", bitrate: 832000),
            VideoVariant(url: "https://example.com/hls.m3u8", contentType: "application/x-mpegURL", bitrate: nil),
            VideoVariant(url: "https://example.com/high.mp4", contentType: "video/mp4", bitrate: 2176000),
            VideoVariant(url: "https://example.com/mid.mp4", contentType: "video/mp4", bitrate: 1280000),
        ]
        let video = VideoInfo(contentId: "test", durationMs: 10000, playbackUrl: "", viewCount: nil, shouldLoop: false, variants: variants)
        XCTAssertEqual(video.bestMp4Url?.absoluteString, "https://example.com/high.mp4")
    }

    func testBestMp4UrlNoMp4() {
        let variants = [
            VideoVariant(url: "https://example.com/hls.m3u8", contentType: "application/x-mpegURL", bitrate: nil),
        ]
        let video = VideoInfo(contentId: "test", durationMs: 10000, playbackUrl: "", viewCount: nil, shouldLoop: false, variants: variants)
        XCTAssertNil(video.bestMp4Url)
    }

    func testBestMp4UrlEmpty() {
        let video = VideoInfo(contentId: "test", durationMs: 10000, playbackUrl: "", viewCount: nil, shouldLoop: false, variants: [])
        XCTAssertNil(video.bestMp4Url)
    }

    // MARK: - PostMetadata Convenience

    func testFormattedLikeCount() {
        let post = PostMetadata(
            id: "1", url: "", text: "", author: "", authorHandle: "",
            authorUrl: "", language: nil, likeCount: 1594, createdAt: nil,
            hashtags: [], mentions: [], urls: [], video: nil, photos: []
        )
        XCTAssertNotNil(post.formattedLikeCount)
        XCTAssertTrue(post.formattedLikeCount!.contains("1"))
    }

    func testFormattedLikeCountNil() {
        let post = PostMetadata(
            id: "1", url: "", text: "", author: "", authorHandle: "",
            authorUrl: "", language: nil, likeCount: nil, createdAt: nil,
            hashtags: [], mentions: [], urls: [], video: nil, photos: []
        )
        XCTAssertNil(post.formattedLikeCount)
    }

    func testFormattedDate() {
        let date = Date(timeIntervalSince1970: 1710412072) // 2024-03-14
        let post = PostMetadata(
            id: "1", url: "", text: "", author: "", authorHandle: "",
            authorUrl: "", language: nil, likeCount: nil, createdAt: date,
            hashtags: [], mentions: [], urls: [], video: nil, photos: []
        )
        XCTAssertNotNil(post.formattedDate)
    }

    func testFormattedDateNil() {
        let post = PostMetadata(
            id: "1", url: "", text: "", author: "", authorHandle: "",
            authorUrl: "", language: nil, likeCount: nil, createdAt: nil,
            hashtags: [], mentions: [], urls: [], video: nil, photos: []
        )
        XCTAssertNil(post.formattedDate)
    }

    // MARK: - Syndication Token

    func testSyndicationTokenStripsDotsAndZeros() {
        let token = XMetadata.generateSyndicationToken("1100414780655906816")
        XCTAssertFalse(token.isEmpty)
        XCTAssertFalse(token.contains("."), "Token must not contain dots")
        XCTAssertFalse(token.contains("0"), "Token must not contain zeros")
    }

    func testSyndicationTokenIsDeterministic() {
        XCTAssertEqual(
            XMetadata.generateSyndicationToken("1234567890"),
            XMetadata.generateSyndicationToken("1234567890")
        )
    }

    // MARK: - PostMetadata Author Fields

    func testAuthorFieldsDefaultWhenOmitted() {
        let post = PostMetadata(
            id: "1", url: "", text: "", author: "", authorHandle: "",
            authorUrl: "", language: nil, likeCount: nil, createdAt: nil,
            hashtags: [], mentions: [], urls: [], video: nil, photos: []
        )
        XCTAssertNil(post.authorId)
        XCTAssertFalse(post.authorVerified)
        XCTAssertNil(post.authorProfileImageUrl)
        XCTAssertNil(post.replyCount)
        XCTAssertNil(post.viewCount)
    }

    func testAuthorFieldsPopulated() {
        let post = PostMetadata(
            id: "1", url: "", text: "", author: "", authorHandle: "",
            authorUrl: "", language: nil, likeCount: nil, createdAt: nil,
            hashtags: [], mentions: [], urls: [], video: nil, photos: [],
            authorId: "44196397", authorVerified: true,
            authorProfileImageUrl: "https://pbs.twimg.com/x.jpg",
            replyCount: 128, viewCount: 91100
        )
        XCTAssertEqual(post.authorId, "44196397")
        XCTAssertTrue(post.authorVerified)
        XCTAssertEqual(post.authorProfileImageUrl, "https://pbs.twimg.com/x.jpg")
        XCTAssertEqual(post.replyCount, 128)
        XCTAssertEqual(post.viewCount, 91100)
    }

    // MARK: - Error Descriptions

    func testAllErrorsHaveDescriptions() {
        let errors: [XMetadataError] = [
            .invalidUrl,
            .invalidPostId,
            .postNotFound,
            .rateLimited,
            .networkError("timeout"),
            .parsingError("bad json"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testErrorEquatable() {
        XCTAssertEqual(XMetadataError.invalidUrl, .invalidUrl)
        XCTAssertEqual(XMetadataError.postNotFound, .postNotFound)
        XCTAssertNotEqual(XMetadataError.invalidUrl, .postNotFound)
    }

    // MARK: - Integration Tests (require network)

    func testFetchLadBiblePost() async throws {
        let post = try await XMetadata.fetch("https://x.com/ladbible/status/1100414780655906816")

        XCTAssertEqual(post.id, "1100414780655906816")
        XCTAssertFalse(post.text.isEmpty)
        XCTAssertFalse(post.author.isEmpty)
        XCTAssertEqual(post.authorHandle, "ladbible")
        XCTAssertNotNil(post.likeCount)
        XCTAssertGreaterThan(post.likeCount ?? 0, 0)
        XCTAssertNotNil(post.createdAt)
        XCTAssertEqual(post.language, "en")
    }

    func testFetchVideoPost() async throws {
        let post = try await XMetadata.fetch("https://x.com/ladbible/status/1100414780655906816")

        // This post has a video
        XCTAssertNotNil(post.video)
        if let video = post.video {
            XCTAssertGreaterThan(video.durationMs, 0)
            XCTAssertFalse(video.playbackUrl.isEmpty)
            XCTAssertNotNil(video.viewCount)

            // Variants should include MP4s from syndication
            XCTAssertFalse(video.variants.isEmpty, "Should have video variants")

            let mp4Variants = video.variants.filter { $0.contentType == "video/mp4" }
            XCTAssertFalse(mp4Variants.isEmpty, "Should have MP4 variants")

            // bestMp4Url should return highest bitrate
            XCTAssertNotNil(video.bestMp4Url, "Should have a best MP4 URL")
            if let url = video.bestMp4Url {
                XCTAssertTrue(url.absoluteString.contains(".mp4"), "Best URL should be MP4")
            }
        }
    }

    func testFetchWithTwitterDomain() async throws {
        let post = try await XMetadata.fetch("https://twitter.com/ladbible/status/1100414780655906816")

        XCTAssertEqual(post.id, "1100414780655906816")
        XCTAssertFalse(post.text.isEmpty)
    }

    func testFetchWithTrackingParams() async throws {
        let post = try await XMetadata.fetch("https://x.com/ladbible/status/1100414780655906816?s=46&t=MKzV8g6iaFM_3WabaWjh1g")

        XCTAssertEqual(post.id, "1100414780655906816")
        XCTAssertFalse(post.text.isEmpty)
    }
    
}
