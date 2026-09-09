//
//  SubDLProvider.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

public final class SubDLProvider: SubtitleProvider {
  public let id = "subdl"
  public let name = "SubDL"

  private let defaultApiKey = "subdl_n-HMWshIn4Lewsa1Co6ZZiqjQOw_7lEYDFz7WMikVzs"
  private let endpoint = "https://api.subdl.com/api/v1/subtitles"
  private let downloadBase = "https://dl.subdl.com"

  public var isAvailable: Bool { true }

  public init() {}

  public func search(request: SubtitleSearchRequest) async throws -> [SubtitleResult] {
    let rawKey = request.providerKeys["subdl"]?.trimmingCharacters(in: .whitespaces) ?? ""
    let apiKey = rawKey.isEmpty ? defaultApiKey : rawKey

    let registry = SubtitleLanguageRegistry.shared
    let langCode = registry.normalize(request.language)
    let langIso1 = registry.toIso639_1(langCode).uppercased()

    var queryItems = [URLQueryItem]()
    queryItems.append(URLQueryItem(name: "api_key", value: apiKey.trimmingCharacters(in: .whitespaces)))
    queryItems.append(URLQueryItem(name: "film_name", value: request.cleanTitle))
    queryItems.append(URLQueryItem(name: "languages", value: langIso1))

    if request.isEpisode {
      queryItems.append(URLQueryItem(name: "type", value: "tv"))
      if let season = request.season { queryItems.append(URLQueryItem(name: "season_number", value: String(season))) }
      if let episode = request.episode { queryItems.append(URLQueryItem(name: "episode_number", value: String(episode))) }
    } else {
      queryItems.append(URLQueryItem(name: "type", value: "movie"))
      if let year = request.year { queryItems.append(URLQueryItem(name: "year", value: String(year))) }
    }

    var components = URLComponents(string: endpoint)!
    components.queryItems = queryItems

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      throw NSError(domain: "SubDL", code: code, userInfo: [NSLocalizedDescriptionKey: "SubDL returned HTTP \(code)"])
    }

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return []
    }

    if let status = json["status"] as? Bool, !status {
      let errorMsg = json["error"] as? String ?? "SubDL returned error status"
      throw NSError(domain: "SubDL", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
    }

    guard let subtitles = json["subtitles"] as? [[String: Any]] else {
      return []
    }

    var results: [SubtitleResult] = []

    for sub in subtitles {
      let rawLang = sub["language_code"] as? String ?? sub["language"] as? String ?? langCode
      let normalizedLang = registry.normalize(rawLang)
      let langObj = registry.language(for: normalizedLang)

      let title = sub["name"] as? String ?? request.cleanTitle
      let subUrl = sub["url"] as? String ?? ""

      var fullUrl: URL? = nil
      if subUrl.hasPrefix("http") {
        fullUrl = URL(string: subUrl)
      } else {
        let prefix = subUrl.hasPrefix("/") ? "" : "/"
        fullUrl = URL(string: "\(downloadBase)\(prefix)\(subUrl)")
      }

      let fps = (sub["fps"] as? String).flatMap { Double($0) }
      let hi = sub["hi"] as? Bool ?? false
      let format = sub["format"] as? String ?? (subUrl.hasSuffix(".zip") ? "zip" : "srt")

      let item = SubtitleResult(
        id: "subdl-\(sub["id"] ?? UUID().uuidString)",
        providerID: id,
        providerName: name,
        language: langObj != nil ? "\(langObj!.flag) \(langObj!.name)" : rawLang,
        languageCode: normalizedLang,
        title: title,
        release: title,
        season: request.season,
        episode: request.episode,
        format: format,
        fps: fps,
        hearingImpaired: hi,
        downloadURL: fullUrl
      )

      results.append(item)
    }

    return results
  }

  public func download(result: SubtitleResult) async throws -> URL {
    guard let downloadURL = result.downloadURL else {
      throw NSError(domain: "SubDL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing download URL for SubDL"])
    }

    let (fileData, fileResp) = try await URLSession.shared.data(from: downloadURL)
    guard (fileResp as? HTTPURLResponse)?.statusCode == 200, !fileData.isEmpty else {
      throw NSError(domain: "SubDL", code: -2, userInfo: [NSLocalizedDescriptionKey: "Downloaded subtitle file is empty or invalid"])
    }

    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let fileName = "\(result.title).\(result.format)"
    let sanitizedName = fileName.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "_")
    let targetURL = tempDir.appendingPathComponent(sanitizedName)

    try fileData.write(to: targetURL, options: .atomic)
    return targetURL
  }
}
