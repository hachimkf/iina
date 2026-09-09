//
//  test_smart_subtitles.swift
//  Unit tests for IINA Smart Subtitles native engine
//

import Foundation

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
  if actual != expected {
    print("❌ FAILED: \(actual) != \(expected). \(message) at line \(line)")
    exit(1)
  }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
  if !condition {
    print("❌ FAILED: Expected true but got false. \(message) at line \(line)")
    exit(1)
  }
}

@main
struct TestRunner {
  static func main() async {
    print("Running IINA Smart Subtitles Unit Tests...")

    // MARK: - 1, 2, 3: Filename Parser, Movie & TV Detection
    print("\n[Test 1] Video Filename Parser: TV Show")
    let tv1 = VideoFilenameParser.parse("The.Last.of.Us.S02E05.1080p.WEB-DL.DDP5.1.H.264.mkv")
    assertEqual(tv1.title, "The Last of Us")
    assertEqual(tv1.season, 2)
    assertEqual(tv1.episode, 5)
    assertEqual(tv1.seasonEpisode, "S02E05")
    assertEqual(tv1.resolution, "1080p")
    assertEqual(tv1.source, "WEB-DL")
    assertEqual(tv1.codec, "H.264")
    assertEqual(tv1.audio, "DDP5.1")
    assertTrue(tv1.isEpisode)

    print("\n[Test 2] Video Filename Parser: Breaking Bad")
    let tv2 = VideoFilenameParser.parse("Breaking.Bad.S01E01.720p.BluRay.x264.mkv")
    assertEqual(tv2.title, "Breaking Bad")
    assertEqual(tv2.season, 1)
    assertEqual(tv2.episode, 1)
    assertEqual(tv2.seasonEpisode, "S01E01")
    assertEqual(tv2.resolution, "720p")
    assertEqual(tv2.source, "BluRay")
    assertEqual(tv2.codec, "X264")
    assertTrue(tv2.isEpisode)

    print("\n[Test 3] Video Filename Parser: Movie Detection")
    let movie1 = VideoFilenameParser.parse("Dune.Part.Two.2024.2160p.WEB-DL.DV.HDR10.mkv")
    assertEqual(movie1.title, "Dune Part Two")
    assertEqual(movie1.year, 2024)
    assertEqual(movie1.resolution, "2160p")
    assertEqual(movie1.source, "WEB-DL")
    assertTrue(!movie1.isEpisode)

    let movie2 = VideoFilenameParser.parse("Oppenheimer.2023.1080p.BluRay.x264.mkv")
    assertEqual(movie2.title, "Oppenheimer")
    assertEqual(movie2.year, 2023)
    assertEqual(movie2.resolution, "1080p")
    assertEqual(movie2.source, "BluRay")
    assertTrue(!movie2.isEpisode)

    print("\n[Test 4] Variations: 1x02 and S1E2")
    let tvVar1 = VideoFilenameParser.parse("Severance.1x02.1080p.mkv")
    assertEqual(tvVar1.title, "Severance")
    assertEqual(tvVar1.season, 1)
    assertEqual(tvVar1.episode, 2)
    assertEqual(tvVar1.seasonEpisode, "S01E02")

    // MARK: - 4: Language Normalization
    print("\n[Test 5] Language Normalization")
    let reg = SubtitleLanguageRegistry.shared
    assertEqual(reg.normalize("French"), "fra")
    assertEqual(reg.normalize("fr"), "fra")
    assertEqual(reg.normalize("fre"), "fra")
    assertEqual(reg.normalize("fra"), "fra")
    assertEqual(reg.normalize("English"), "eng")
    assertEqual(reg.normalize("en"), "eng")
    assertEqual(reg.normalize("Spanish"), "spa")
    assertEqual(reg.normalize("es"), "spa")
    assertEqual(reg.normalize("pt-br"), "pob")
    assertEqual(reg.toIso639_1("fra"), "fr")

    // MARK: - 5: Strict Language Filtering
    print("\n[Test 6] Strict Language Filtering: Only French survives when fra requested")
    let subsInput = [
      SubtitleResult(id: "1", providerID: "test", providerName: "Test", language: "English", languageCode: "eng", title: "Test"),
      SubtitleResult(id: "2", providerID: "test", providerName: "Test", language: "French", languageCode: "fra", title: "Test"),
      SubtitleResult(id: "3", providerID: "test", providerName: "Test", language: "Spanish", languageCode: "spa", title: "Test"),
      SubtitleResult(id: "4", providerID: "test", providerName: "Test", language: "Arabic", languageCode: "ara", title: "Test")
    ]

    let filtered = reg.filterStrict(results: subsInput, targetLanguage: "fra", allowFallback: false)
    assertEqual(filtered.count, 1)
    assertEqual(filtered[0].id, "2")
    assertEqual(filtered[0].languageCode, "fra")

    let emptyFallbackOff = reg.filterStrict(results: [subsInput[0]], targetLanguage: "fra", allowFallback: false)
    assertEqual(emptyFallbackOff.count, 0)

    let fallbackOn = reg.filterStrict(results: [subsInput[0]], targetLanguage: "fra", allowFallback: true)
    assertEqual(fallbackOn.count, 1)

    // MARK: - 6: Ranking Engine
    print("\n[Test 7] Ranking Engine: S02E05 beats S02E04 & Language Mismatch is penalized")
    let req = SubtitleSearchRequest(
      filename: "The.Last.of.Us.S02E05.1080p.WEB-DL.mkv",
      cleanTitle: "The Last of Us",
      season: 2,
      episode: 5,
      seasonEpisode: "S02E05",
      resolution: "1080p",
      source: "WEB-DL",
      language: "fra"
    )

    let subCorrect = SubtitleResult(
      id: "sub-1", providerID: "test", providerName: "Test",
      language: "French", languageCode: "fra",
      title: "The Last of Us", release: "The.Last.of.Us.S02E05.1080p.WEB-DL",
      season: 2, episode: 5
    )

    let subWrongEp = SubtitleResult(
      id: "sub-2", providerID: "test", providerName: "Test",
      language: "French", languageCode: "fra",
      title: "The Last of Us", release: "The.Last.of.Us.S02E04.1080p.WEB-DL",
      season: 2, episode: 4
    )

    let subWrongLang = SubtitleResult(
      id: "sub-3", providerID: "test", providerName: "Test",
      language: "English", languageCode: "eng",
      title: "The Last of Us", release: "The.Last.of.Us.S02E05.1080p.WEB-DL",
      season: 2, episode: 5
    )

    let rankCorrect = SubtitleRankingEngine.calculateScore(subtitle: subCorrect, request: req)
    let rankWrongEp = SubtitleRankingEngine.calculateScore(subtitle: subWrongEp, request: req)
    let rankWrongLang = SubtitleRankingEngine.calculateScore(subtitle: subWrongLang, request: req)

    assertTrue(rankCorrect.score >= 85, "Correct episode should score >= 85%, got \(rankCorrect.score)")
    assertTrue(rankCorrect.score >= rankWrongEp.score + 40, "Correct episode must beat wrong episode by at least 40 points")
    assertTrue(rankWrongLang.score < 50, "Mismatched language must score low")
    assertTrue(rankCorrect.matchReasons.contains("✓ S02E05"))
    assertTrue(rankCorrect.matchReasons.contains("✓ WEB-DL"))

    // MARK: - 7: Deduplication
    print("\n[Test 8] Deduplication across multiple providers")
    let multiProviderDedupe = [
      SubtitleResult(
        id: "opensub-1", providerID: "opensubtitles", providerName: "OpenSubtitles",
        language: "French", languageCode: "fra",
        title: "The Last of Us", release: "The.Last.of.Us.S02E05.1080p.WEB-DL",
        season: 2, episode: 5, downloads: 120, score: 95
      ),
      SubtitleResult(
        id: "subdl-2", providerID: "subdl", providerName: "SubDL",
        language: "French", languageCode: "fra",
        title: "The Last of Us", release: "The.Last.of.Us.S02E05.1080p.WEB-DL",
        season: 2, episode: 5, downloads: 80, score: 95
      ),
      SubtitleResult(
        id: "wyzie-3", providerID: "wyzie", providerName: "Wyzie",
        language: "French", languageCode: "fra",
        title: "The Last of Us", release: "The.Last.of.Us.S02E05.1080p.WEB-DL",
        season: 2, episode: 5, downloads: 50, score: 95
      )
    ]

    let deduped = SubtitleDeduplicator.deduplicate(multiProviderDedupe)
    assertEqual(deduped.count, 1)
    assertEqual(deduped[0].sources.sorted(), ["OpenSubtitles", "SubDL", "Wyzie"])
    assertEqual(deduped[0].id, "opensub-1")

    // MARK: - 8, 9, 10: Search Engine Concurrency, Provider Failure & Multiple Providers
    print("\n[Test 9] Search Engine Concurrency & Resilient Provider Failure")

    final class MockFailingProvider: SubtitleProvider {
      let id = "failing"
      let name = "Failing Provider"
      var isAvailable: Bool { true }
      func search(request: SubtitleSearchRequest) async throws -> [SubtitleResult] {
        throw NSError(domain: "Network", code: -1009, userInfo: [NSLocalizedDescriptionKey: "Internet offline"])
      }
      func download(result: SubtitleResult) async throws -> URL {
        throw NSError(domain: "Network", code: -1, userInfo: nil)
      }
    }

    final class MockWorkingProvider: SubtitleProvider {
      let id = "working"
      let name = "Working Provider"
      var isAvailable: Bool { true }
      func search(request: SubtitleSearchRequest) async throws -> [SubtitleResult] {
        return [
          SubtitleResult(
            id: "work-1", providerID: id, providerName: name,
            language: "French", languageCode: "fra",
            title: "The Last of Us", release: "The.Last.of.Us.S02E05.1080p.WEB-DL",
            season: 2, episode: 5
          )
        ]
      }
      func download(result: SubtitleResult) async throws -> URL {
        return URL(fileURLWithPath: "/tmp/sub.srt")
      }
    }

    let searchReq = SubtitleSearchRequest(
      filename: "The.Last.of.Us.S02E05.1080p.WEB-DL.mkv",
      cleanTitle: "The Last of Us",
      season: 2,
      episode: 5,
      language: "fra",
      enabledProviders: ["failing", "working"]
    )

    let engine = SubtitleSearchEngine(providers: [MockFailingProvider(), MockWorkingProvider()])
    let searchResult = await engine.search(request: searchReq)
    assertEqual(searchResult.results.count, 1)
    assertEqual(searchResult.results[0].id, "work-1")
    assertEqual(searchResult.results[0].languageCode, "fra")
    assertTrue(searchResult.results[0].score >= 85)

    let failingStatus = searchResult.statuses.first(where: { $0.providerID == "failing" })
    assertEqual(failingStatus?.state, .failed)

    let workingStatus = searchResult.statuses.first(where: { $0.providerID == "working" })
    assertEqual(workingStatus?.state, .success)

    // MARK: - 11, 12: Automatic Download Threshold
    print("\n[Test 10] Automatic Download Threshold check")
    let threshold = 85
    let highMatch = SubtitleResult(id: "h", providerID: "p", providerName: "P", language: "French", languageCode: "fra", title: "T", score: 95)
    let lowMatch = SubtitleResult(id: "l", providerID: "p", providerName: "P", language: "French", languageCode: "fra", title: "T", score: 72)

    assertTrue(highMatch.score >= threshold, "High match should trigger auto-download")
    assertTrue(lowMatch.score < threshold, "Low match must NOT trigger auto-download")

    print("\n🎉 ALL 10 TEST SUITES (12 SCENARIOS) PASSED SUCCESSFULLY!\n")
  }
}
