//
//  SubtitleRankingEngine.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

public struct RankingBreakdown {
  public let score: Int
  public let matchReasons: [String]
}

public final class SubtitleRankingEngine {

  public static func calculateScore(
    subtitle: SubtitleResult,
    request: SubtitleSearchRequest
  ) -> RankingBreakdown {
    var score = 0
    var matchReasons: [String] = []

    let registry = SubtitleLanguageRegistry.shared
    let targetLangNorm = registry.normalize(request.language)
    let subLangNorm = registry.normalize(subtitle.languageCode.isEmpty ? subtitle.language : subtitle.languageCode)

    // 1. Language matching (+20 pts)
    if subLangNorm == targetLangNorm {
      score += 20
      let langName = registry.language(for: subLangNorm)?.name ?? subtitle.language
      matchReasons.append("✓ \(langName)")
    } else {
      score -= 50
      matchReasons.append("✗ Language Mismatch (\(subtitle.language))")
    }

    // 2. Title matching (+25 pts)
    let subTitleClean = subtitle.title.lowercased().filter { $0.isLetter || $0.isNumber }
    let reqTitleClean = request.cleanTitle.lowercased().filter { $0.isLetter || $0.isNumber }

    if !subTitleClean.isEmpty && !reqTitleClean.isEmpty {
      if subTitleClean == reqTitleClean {
        score += 25
        matchReasons.append("✓ Title Match")
      } else if subTitleClean.contains(reqTitleClean) || reqTitleClean.contains(subTitleClean) {
        score += 18
        matchReasons.append("✓ Title Similar")
      }
    }

    // 3. TV Season and Episode Matching (+20 + 20 = +40 pts)
    if request.isEpisode, let reqSeason = request.season, let reqEpisode = request.episode {
      if let subSeason = subtitle.season, let subEpisode = subtitle.episode {
        if subSeason == reqSeason && subEpisode == reqEpisode {
          score += 40
          matchReasons.append(String(format: "✓ S%02dE%02d", reqSeason, reqEpisode))
        } else if subSeason == reqSeason && subEpisode != reqEpisode {
          score -= 40
          matchReasons.append("✗ Episode \(subEpisode) (Wanted E\(reqEpisode))")
        } else {
          score -= 60
          matchReasons.append("✗ S\(subSeason)E\(subEpisode) Mismatch")
        }
      } else {
        // TV episode without season/episode tags
        score -= 20
      }
    } else if let reqYear = request.year, !request.isEpisode {
      // 4. Movie release year matching (+10 pts)
      let yearStr = String(reqYear)
      if subtitle.title.contains(yearStr) || (subtitle.release?.contains(yearStr) ?? false) {
        score += 10
        matchReasons.append("✓ Year \(reqYear)")
      }
    }

    // 5. Release / Source matching (+10 pts)
    let fullSubText = "\(subtitle.title) \(subtitle.release ?? "")".uppercased()
    if let reqSource = request.source?.uppercased() {
      if (reqSource.contains("WEB") && (fullSubText.contains("WEB-DL") || fullSubText.contains("WEBRIP") || fullSubText.contains("WEB"))) ||
         (reqSource.contains("BLURAY") && (fullSubText.contains("BLURAY") || fullSubText.contains("BDRIP") || fullSubText.contains("BRRIP"))) ||
         (reqSource.contains("HDTV") && fullSubText.contains("HDTV")) {
        score += 10
        matchReasons.append("✓ \(request.source ?? "")")
      }
    }

    // 6. Resolution matching (+3 pts)
    if let reqRes = request.resolution?.lowercased() {
      if fullSubText.lowercased().contains(reqRes) {
        score += 3
        matchReasons.append("✓ \(request.resolution ?? "")")
      }
    }

    // 7. FPS matching (+2 pts)
    if let reqFPS = request.fps, let subFPS = subtitle.fps {
      if abs(reqFPS - subFPS) < 0.05 {
        score += 2
        matchReasons.append(String(format: "✓ %.2f fps", subFPS))
      }
    }

    // Rating / Popularity bonus (+1 to +5)
    if subtitle.rating > 0 {
      score += min(Int(round(subtitle.rating / 2.0)), 5)
    }

    let finalScore = max(0, min(100, score))
    return RankingBreakdown(score: finalScore, matchReasons: matchReasons)
  }
}
