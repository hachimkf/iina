//
//  VideoFilenameParser.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

public struct ParsedVideoInfo {
  public let rawFilename: String
  public let title: String
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
  public let isEpisode: Bool

  public init(
    rawFilename: String,
    title: String,
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
    isEpisode: Bool = false
  ) {
    self.rawFilename = rawFilename
    self.title = title
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
    self.isEpisode = isEpisode
  }
}

public final class VideoFilenameParser {

  private static let resolutions = ["2160p", "4k", "uhd", "1080p", "1080i", "720p", "576p", "480p"]
  private static let sources = ["web-dl", "webdl", "web-rip", "webrip", "bluray", "bdrip", "brrip", "hdtv", "dvdrip"]
  private static let codecs = ["x264", "h264", "h.264", "avc", "x265", "h265", "h.265", "hevc", "av1", "xvid", "divx"]
  private static let audios = ["ddp5.1", "ddp5 1", "dd5.1", "dd5 1", "atmos", "truehd", "dts-hd", "dts", "aac2.0", "aac", "ac3", "flac"]

  public static func parse(_ input: String) -> ParsedVideoInfo {
    let cleanPath = input.removingPercentEncoding ?? input
    let filenameWithExt = URL(fileURLWithPath: cleanPath).lastPathComponent
    let base = (filenameWithExt as NSString).deletingPathExtension

    var year: Int?
    var season: Int?
    var episode: Int?
    var seasonEpisode: String?
    var resolution: String?
    var source: String?
    var codec: String?
    var audio: String?
    var releaseGroup: String?

    // 1. Match TV season & episode: S01E02, 1x02, Season 1 Episode 2
    var tvCutIndex = base.count

    if let match = firstMatch(in: base, pattern: #"(?i)(?:^|[._\s-])[sS](\d{1,2})[eE](\d{1,3})(?:[._\s-]|$)"#) {
      if match.captures.count >= 2, let s = Int(match.captures[0]), let e = Int(match.captures[1]) {
        season = s
        episode = e
        tvCutIndex = match.range.location
      }
    } else if let match = firstMatch(in: base, pattern: #"(?i)(?:^|[._\s-])(\d{1,2})x(\d{1,3})(?:[._\s-]|$)"#) {
      if match.captures.count >= 2, let s = Int(match.captures[0]), let e = Int(match.captures[1]) {
        season = s
        episode = e
        tvCutIndex = match.range.location
      }
    } else if let match = firstMatch(in: base, pattern: #"(?i)(?:^|[._\s-])season[._\s-]*(\d{1,2})[._\s-]*episode[._\s-]*(\d{1,3})"#) {
      if match.captures.count >= 2, let s = Int(match.captures[0]), let e = Int(match.captures[1]) {
        season = s
        episode = e
        tvCutIndex = match.range.location
      }
    }

    if let s = season, let e = episode {
      seasonEpisode = String(format: "S%02dE%02d", s, e)
    }

    // 2. Match movie release year: 19xx or 20xx
    var yearCutIndex = base.count
    if let match = firstMatch(in: base, pattern: #"(?:^|[._\s-(])(19\d{2}|20\d{2})(?:[._\s-)]|$)"#) {
      if let y = Int(match.captures[0]) {
        year = y
        yearCutIndex = match.range.location
      }
    }

    let lower = base.lowercased()

    // 3. Technical tags: Resolution
    for res in resolutions {
      if lower.contains(res) {
        resolution = (res == "4k" || res == "uhd") ? "2160p" : res
        break
      }
    }

    // Source
    for src in sources {
      if lower.contains(src) {
        if src.contains("web") { source = "WEB-DL" }
        else if src.contains("bluray") || src.contains("bdrip") || src.contains("brrip") { source = "BluRay" }
        else if src.contains("hdtv") { source = "HDTV" }
        else { source = src.uppercased() }
        break
      }
    }

    // Codec
    for c in codecs {
      if lower.contains(c) {
        codec = c.uppercased().replacingOccurrences(of: "H264", with: "H.264").replacingOccurrences(of: "H265", with: "H.265")
        break
      }
    }

    // Audio
    for a in audios {
      if lower.contains(a) {
        audio = a.uppercased()
        break
      }
    }

    // Release group (at end of filename after dash)
    if let match = firstMatch(in: base, pattern: #"-([a-zA-Z0-9]+)$"#), match.captures.count >= 1 {
      let cand = match.captures[0]
      if !resolutions.contains(cand.lowercased()) && !codecs.contains(cand.lowercased()) {
        releaseGroup = cand
      }
    }

    // 4. Extract Clean Title
    var cutIndex = base.count
    if tvCutIndex < cutIndex {
      cutIndex = tvCutIndex
    }
    if yearCutIndex < cutIndex && season == nil {
      cutIndex = yearCutIndex
    }

    // Also cut before any technical tokens
    let tags = resolutions + sources + codecs
    for tag in tags {
      if let range = base.range(of: tag, options: .caseInsensitive) {
        let idx = base.distance(from: base.startIndex, to: range.lowerBound)
        if idx > 0 && idx < cutIndex {
          cutIndex = idx
        }
      }
    }

    let rawTitle = String(base.prefix(cutIndex))
    let clean = rawTitle
      .replacingOccurrences(of: ".", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .trimmingCharacters(in: CharacterSet(charactersIn: " .-–_"))
      .components(separatedBy: .whitespaces)
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    let finalTitle = clean.isEmpty ? base : clean

    return ParsedVideoInfo(
      rawFilename: filenameWithExt,
      title: finalTitle,
      cleanTitle: finalTitle,
      year: year,
      season: season,
      episode: episode,
      seasonEpisode: seasonEpisode,
      resolution: resolution,
      source: source,
      codec: codec,
      audio: audio,
      releaseGroup: releaseGroup,
      isEpisode: season != nil && episode != nil
    )
  }

  private struct MatchResult {
    let range: NSRange
    let captures: [String]
  }

  private static func firstMatch(in string: String, pattern: String) -> MatchResult? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
    let nsString = string as NSString
    guard let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)) else {
      return nil
    }

    var captures: [String] = []
    if match.numberOfRanges > 1 {
      for i in 1..<match.numberOfRanges {
        let r = match.range(at: i)
        if r.location != NSNotFound {
          captures.append(nsString.substring(with: r))
        }
      }
    }
    return MatchResult(range: match.range, captures: captures)
  }
}
