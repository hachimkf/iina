//
//  SubtitleSearchEngine.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

public struct ProviderSearchStatus: Identifiable {
  public var id: String { providerID }
  public let providerID: String
  public let providerName: String
  public var state: State
  public var message: String?
  public var resultsCount: Int

  public enum State {
    case idle
    case searching
    case success
    case failed
    case unconfigured
  }

  public init(providerID: String, providerName: String, state: State, message: String? = nil, resultsCount: Int = 0) {
    self.providerID = providerID
    self.providerName = providerName
    self.state = state
    self.message = message
    self.resultsCount = resultsCount
  }
}

public struct SubtitleSearchResult {
  public let results: [SubtitleResult]
  public let statuses: [ProviderSearchStatus]
}

public final class SubtitleSearchEngine {
  public static let shared = SubtitleSearchEngine()

  private var providers: [String: SubtitleProvider] = [:]

  public init(providers: [SubtitleProvider] = [
    OpenSubtitlesProvider(),
    SubDLProvider(),
    WyzieProvider()
  ]) {
    for p in providers {
      self.providers[p.id] = p
    }
  }

  public func register(provider: SubtitleProvider) {
    providers[provider.id] = provider
  }

  public func provider(for id: String) -> SubtitleProvider? {
    return providers[id]
  }

  public var allProviders: [SubtitleProvider] {
    return Array(providers.values)
  }

  /// Executes concurrent search across enabled providers with strict language filtering, deduplication, and ranking.
  public func search(
    request: SubtitleSearchRequest,
    onProgress: (@Sendable (ProviderSearchStatus) -> Void)? = nil
  ) async -> SubtitleSearchResult {
    let activeProviders = providers.values.filter { request.enabledProviders.contains($0.id) }

    if activeProviders.isEmpty {
      return SubtitleSearchResult(results: [], statuses: [])
    }

    var statuses: [String: ProviderSearchStatus] = [:]
    for p in activeProviders {
      let st = ProviderSearchStatus(providerID: p.id, providerName: p.name, state: .searching)
      statuses[p.id] = st
      onProgress?(st)
    }

    typealias ProviderOutcome = (providerID: String, name: String, results: [SubtitleResult]?, error: Error?)

    let outcomes: [ProviderOutcome] = await withTaskGroup(of: ProviderOutcome.self) { group in
      for provider in activeProviders {
        group.addTask {
          do {
            let res = try await provider.search(request: request)
            return (provider.id, provider.name, res, nil)
          } catch {
            return (provider.id, provider.name, nil, error)
          }
        }
      }

      var collected: [ProviderOutcome] = []
      for await item in group {
        collected.append(item)
      }
      return collected
    }

    var rawResults: [SubtitleResult] = []

    for outcome in outcomes {
      if let results = outcome.results {
        rawResults.append(contentsOf: results)
        let st = ProviderSearchStatus(
          providerID: outcome.providerID,
          providerName: outcome.name,
          state: .success,
          message: "\(results.count) found",
          resultsCount: results.count
        )
        statuses[outcome.providerID] = st
        onProgress?(st)
      } else {
        let errDesc = outcome.error?.localizedDescription ?? "Failed"
        let st = ProviderSearchStatus(
          providerID: outcome.providerID,
          providerName: outcome.name,
          state: .failed,
          message: errDesc,
          resultsCount: 0
        )
        statuses[outcome.providerID] = st
        onProgress?(st)
      }
    }

    // 1. Strict Language Filtering:
    // Any subtitle not matching the requested language is removed
    let langFiltered = SubtitleLanguageRegistry.shared.filterStrict(
      results: rawResults,
      targetLanguage: request.language,
      allowFallback: request.allowFallback
    )

    // 2. Ranking & Scoring:
    var ranked: [SubtitleResult] = []
    for var sub in langFiltered {
      let breakdown = SubtitleRankingEngine.calculateScore(subtitle: sub, request: request)
      sub.score = breakdown.score
      sub.matchReasons = breakdown.matchReasons
      ranked.append(sub)
    }

    // 3. Deduplication:
    let deduplicated = SubtitleDeduplicator.deduplicate(ranked)

    // 4. Sort descending by score, then downloads
    let sorted = deduplicated.sorted { a, b in
      if a.score != b.score {
        return a.score > b.score
      }
      return a.downloads > b.downloads
    }

    return SubtitleSearchResult(results: sorted, statuses: Array(statuses.values))
  }
}
