//
//  WyzieProvider.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

public final class WyzieProvider: SubtitleProvider {
  public let id = "wyzie"
  public let name = "Wyzie"

  private let endpoint = "https://sub.wyzie.io/search"

  public var isAvailable: Bool { true }

  public init() {}

  public func search(request: SubtitleSearchRequest) async throws -> [SubtitleResult] {
    guard let apiKey = request.providerKeys["wyzie"], !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw NSError(domain: "Wyzie", code: 401, userInfo: [NSLocalizedDescriptionKey: "Wyzie requires an API key in Preferences (free from store.wyzie.io)"])
    }

    let registry = SubtitleLanguageRegistry.shared
    let langCode = registry.normalize(request.language)
    let langIso1 = registry.toIso639_1(langCode)

    var queryItems = [URLQueryItem]()
    queryItems.append(URLQueryItem(name: "query", value: request.cleanTitle))
    queryItems.append(URLQueryItem(name: "language", value: langIso1))

    if let season = request.season { queryItems.append(URLQueryItem(name: "season", value: String(season))) }
    if let episode = request.episode { queryItems.append(URLQueryItem(name: "episode", value: String(episode))) }
    if let year = request.year { queryItems.append(URLQueryItem(name: "year", value: String(year))) }

    var components = URLComponents(string: endpoint)!
    components.queryItems = queryItems

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue(apiKey.trimmingCharacters(in: .whitespaces), forHTTPHeaderField: "x-api-key")

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      throw NSError(domain: "Wyzie", code: code, userInfo: [NSLocalizedDescriptionKey: "Wyzie returned HTTP \(code)"])
    }

    var subtitlesArray: [[String: Any]] = []

    if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
      subtitlesArray = array
    } else if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      subtitlesArray = (dict["subtitles"] as? [[String: Any]]) ?? (dict["results"] as? [[String: Any]]) ?? []
    }

    var results: [SubtitleResult] = []

    for sub in subtitlesArray {
      let rawLang = sub["language"] as? String ?? sub["lang"] as? String ?? langCode
      let normalizedLang = registry.normalize(rawLang)
      let langObj = registry.language(for: normalizedLang)

      let title = sub["title"] as? String ?? sub["name"] as? String ?? request.cleanTitle
      let release = sub["release"] as? String ?? sub["filename"] as? String
      let format = sub["format"] as? String ?? "srt"
      let hi = sub["hi"] as? Bool ?? sub["hearingImpaired"] as? Bool ?? false

      var downloadURL: URL? = nil
      if let urlStr = sub["url"] as? String ?? sub["downloadUrl"] as? String {
        downloadURL = URL(string: urlStr)
      }

      let item = SubtitleResult(
        id: "wyzie-\(sub["id"] ?? UUID().uuidString)",
        providerID: id,
        providerName: name,
        language: langObj != nil ? "\(langObj!.flag) \(langObj!.name)" : rawLang,
        languageCode: normalizedLang,
        title: title,
        release: release,
        season: sub["season"] as? Int ?? request.season,
        episode: sub["episode"] as? Int ?? request.episode,
        format: format,
        hearingImpaired: hi,
        downloadURL: downloadURL
      )

      results.append(item)
    }

    return results
  }

  public func download(result: SubtitleResult) async throws -> URL {
    guard let downloadURL = result.downloadURL else {
      throw NSError(domain: "Wyzie", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing download URL for Wyzie subtitle"])
    }

    let (fileData, fileResp) = try await URLSession.shared.data(from: downloadURL)
    guard (fileResp as? HTTPURLResponse)?.statusCode == 200, !fileData.isEmpty else {
      throw NSError(domain: "Wyzie", code: -2, userInfo: [NSLocalizedDescriptionKey: "Downloaded subtitle file is empty or invalid"])
    }

    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let fileName = "\(result.title).\(result.format)"
    let sanitizedName = fileName.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "_")
    let targetURL = tempDir.appendingPathComponent(sanitizedName)

    try fileData.write(to: targetURL, options: .atomic)
    return targetURL
  }
}
