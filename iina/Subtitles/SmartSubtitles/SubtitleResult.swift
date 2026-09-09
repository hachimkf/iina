//
//  SubtitleResult.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

/// Unified model representing a subtitle found from any provider.
public struct SubtitleResult: Identifiable, Equatable {
  public let id: String
  public let providerID: String
  public let providerName: String
  public let language: String
  public let languageCode: String // Normalized ISO 639-2 code, e.g. "fra"
  public let title: String
  public let release: String?
  public let season: Int?
  public let episode: Int?
  public let format: String
  public let fps: Double?
  public let resolution: String?
  public let hearingImpaired: Bool
  public let forced: Bool
  public let downloads: Int
  public let rating: Double
  public let uploader: String?
  public let downloadURL: URL?
  public let fileId: String?
  public var score: Int
  public var matchReasons: [String]
  public var sources: [String]
  public var extraData: [String: String]

  public init(
    id: String,
    providerID: String,
    providerName: String,
    language: String,
    languageCode: String,
    title: String,
    release: String? = nil,
    season: Int? = nil,
    episode: Int? = nil,
    format: String = "srt",
    fps: Double? = nil,
    resolution: String? = nil,
    hearingImpaired: Bool = false,
    forced: Bool = false,
    downloads: Int = 0,
    rating: Double = 0.0,
    uploader: String? = nil,
    downloadURL: URL? = nil,
    fileId: String? = nil,
    score: Int = 0,
    matchReasons: [String] = [],
    sources: [String] = [],
    extraData: [String: String] = [:]
  ) {
    self.id = id
    self.providerID = providerID
    self.providerName = providerName
    self.language = language
    self.languageCode = languageCode
    self.title = title
    self.release = release
    self.season = season
    self.episode = episode
    self.format = format
    self.fps = fps
    self.resolution = resolution
    self.hearingImpaired = hearingImpaired
    self.forced = forced
    self.downloads = downloads
    self.rating = rating
    self.uploader = uploader
    self.downloadURL = downloadURL
    self.fileId = fileId
    self.score = score
    self.matchReasons = matchReasons
    self.sources = sources.isEmpty ? [providerName] : sources
    self.extraData = extraData
  }

  public static func == (lhs: SubtitleResult, rhs: SubtitleResult) -> Bool {
    return lhs.id == rhs.id && lhs.providerID == rhs.providerID
  }
}
