//
//  OpenSubtitlesProvider.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

public final class OpenSubtitlesProvider: SubtitleProvider {
  public let id = "opensubtitles"
  public let name = "OpenSubtitles"

  private let defaultApiKey = "02WzVTIcNbbJ0IOQH3vZIATriQj9slZx"
  private let endpoint = "https://api.opensubtitles.com/api/v1"

  public var isAvailable: Bool { true }

  public init() {}

  public func search(request: SubtitleSearchRequest) async throws -> [SubtitleResult] {
    let registry = SubtitleLanguageRegistry.shared
    let langCode = registry.normalize(request.language)

    var queryItems = [URLQueryItem]()
    queryItems.append(URLQueryItem(name: "languages", value: langCode))

    if !request.cleanTitle.isEmpty {
      queryItems.append(URLQueryItem(name: "query", value: request.cleanTitle))
    }

    if let season = request.season, let episode = request.episode {
      queryItems.append(URLQueryItem(name: "season_number", value: String(season)))
      queryItems.append(URLQueryItem(name: "episode_number", value: String(episode)))
    } else if let year = request.year, !request.isEpisode {
      queryItems.append(URLQueryItem(name: "year", value: String(year)))
    }

    if let hash = request.videoHash, !hash.isEmpty {
      queryItems.append(URLQueryItem(name: "moviehash", value: hash))
    }

    var components = URLComponents(string: "\(endpoint)/subtitles")!
    components.queryItems = queryItems

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("IINA Smart Subtitles v1.0", forHTTPHeaderField: "User-Agent")

    let apiKey = request.providerKeys["opensubtitles"] ?? defaultApiKey
    urlRequest.setValue(apiKey, forHTTPHeaderField: "Api-Key")

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      throw NSError(domain: "OpenSubtitles", code: code, userInfo: [NSLocalizedDescriptionKey: "OpenSubtitles returned HTTP \(code)"])
    }

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let items = json["data"] as? [[String: Any]] else {
      return []
    }

    var results: [SubtitleResult] = []

    for item in items {
      let attr = item["attributes"] as? [String: Any] ?? [:]
      let files = attr["files"] as? [[String: Any]] ?? []
      let firstFile = files.first

      let fileId = firstFile?["file_id"] != nil ? "\(firstFile!["file_id"]!)" : nil
      let rawLang = attr["language"] as? String ?? langCode
      let normalizedLang = registry.normalize(rawLang)
      let langObj = registry.language(for: normalizedLang)

      let featureDetails = attr["feature_details"] as? [String: Any]
      let title = featureDetails?["title"] as? String ?? attr["release"] as? String ?? request.cleanTitle
      let releaseName = attr["release"] as? String ?? firstFile?["file_name"] as? String

      let downloads = attr["download_count"] as? Int ?? 0
      let rating = attr["ratings"] as? Double ?? 0.0
      let format = attr["format"] as? String ?? "srt"
      let fps = attr["fps"] as? Double
      let hearingImpaired = attr["hearing_impaired"] as? Bool ?? false
      let forced = attr["foreign_parts_only"] as? Bool ?? false

      let seasonNum = featureDetails?["season_number"] as? Int ?? request.season
      let episodeNum = featureDetails?["episode_number"] as? Int ?? request.episode

      let sub = SubtitleResult(
        id: "opensub-\(item["id"] ?? UUID().uuidString)",
        providerID: id,
        providerName: name,
        language: langObj != nil ? "\(langObj!.flag) \(langObj!.name)" : rawLang,
        languageCode: normalizedLang,
        title: title,
        release: releaseName,
        season: seasonNum,
        episode: episodeNum,
        format: format,
        fps: fps,
        resolution: request.resolution,
        hearingImpaired: hearingImpaired,
        forced: forced,
        downloads: downloads,
        rating: rating,
        uploader: (attr["uploader"] as? [String: Any])?["name"] as? String,
        fileId: fileId
      )

      results.append(sub)
    }

    return results
  }

  public func download(result: SubtitleResult) async throws -> URL {
    guard let fileIdStr = result.fileId, let fileId = Int(fileIdStr) else {
      throw NSError(domain: "OpenSubtitles", code: -1, userInfo: [NSLocalizedDescriptionKey: "Subtitle result missing fileId for download"])
    }

    let downloadEndpoint = URL(string: "\(endpoint)/download")!
    var urlRequest = URLRequest(url: downloadEndpoint)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("IINA Smart Subtitles v1.0", forHTTPHeaderField: "User-Agent")
    urlRequest.setValue(defaultApiKey, forHTTPHeaderField: "Api-Key")

    let bodyData = try JSONSerialization.data(withJSONObject: ["file_id": fileId])
    urlRequest.httpBody = bodyData

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let linkStr = json["link"] as? String,
          let linkURL = URL(string: linkStr) else {
      throw NSError(domain: "OpenSubtitles", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL from OpenSubtitles"])
    }

    let fileName = json["file_name"] as? String ?? "\(result.title).\(result.format)"

    // Download actual subtitle file data
    let (fileData, fileResp) = try await URLSession.shared.data(from: linkURL)
    guard (fileResp as? HTTPURLResponse)?.statusCode == 200, !fileData.isEmpty else {
      throw NSError(domain: "OpenSubtitles", code: -3, userInfo: [NSLocalizedDescriptionKey: "Downloaded subtitle file is empty or invalid"])
    }

    // Save to temp folder
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let sanitizedName = fileName.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "_")
    let targetURL = tempDir.appendingPathComponent(sanitizedName)

    try fileData.write(to: targetURL, options: .atomic)
    return targetURL
  }
}
