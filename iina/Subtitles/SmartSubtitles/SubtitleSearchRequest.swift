//
//  SubtitleSearchRequest.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

/// Request payload sent to subtitle providers.
public struct SubtitleSearchRequest {
  public let mediaURL: URL?
  public let filename: String
  public let cleanTitle: String
  public let year: Int?
  public let season: Int?
  public let episode: Int?
  public let seasonEpisode: String?
  public let resolution: String?
  public let source: String?
  public let codec: String?
  public let audio: String?
  public let releaseGroup: String?
  public let fps: Double?
  public let videoHash: String?
  public let fileSize: UInt64?
  public let language: String // Normalized ISO 639-2 (e.g. "fra")
  public let allowFallback: Bool
  public let enabledProviders: Set<String>
  public let providerKeys: [String: String]

  public var isEpisode: Bool {
    return season != nil && episode != nil
  }

  public init(
    mediaURL: URL? = nil,
    filename: String,
    cleanTitle: String,
    year: Int? = nil,
    season: Int? = nil,
    episode: Int? = nil,
    seasonEpisode: String? = nil,
    resolution: String? = nil,
    source: String? = nil,
    codec: String? = nil,
    audio: String? = nil,
    releaseGroup: String? = nil,
    fps: Double? = nil,
    videoHash: String? = nil,
    fileSize: UInt64? = nil,
    language: String,
    allowFallback: Bool = false,
    enabledProviders: Set<String> = [],
    providerKeys: [String: String] = [:]
  ) {
    self.mediaURL = mediaURL
    self.filename = filename
    self.cleanTitle = cleanTitle
    self.year = year
    self.season = season
    self.episode = episode
    self.seasonEpisode = seasonEpisode
    self.resolution = resolution
    self.source = source
    self.codec = codec
    self.audio = audio
    self.releaseGroup = releaseGroup
    self.fps = fps
    self.videoHash = videoHash
    self.fileSize = fileSize
    self.language = language
    self.allowFallback = allowFallback
    self.enabledProviders = enabledProviders
    self.providerKeys = providerKeys
  }
}
