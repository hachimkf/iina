//
//  SubtitleDeduplicator.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

public final class SubtitleDeduplicator {

  public static func deduplicate(_ subtitles: [SubtitleResult]) -> [SubtitleResult] {
    var map: [String: SubtitleResult] = [:]
    let registry = SubtitleLanguageRegistry.shared

    for sub in subtitles {
      let lang = registry.normalize(sub.languageCode.isEmpty ? sub.language : sub.languageCode)
      let titleClean = sub.title.lowercased().filter { $0.isLetter || $0.isNumber }
      let season = sub.season ?? 0
      let episode = sub.episode ?? 0
      let relClean = (sub.release ?? sub.format).lowercased().filter { $0.isLetter || $0.isNumber }

      let key = "\(titleClean)|\(season)|\(episode)|\(lang)|\(relClean)"

      if var existing = map[key] {
        // Merge sources
        var currentSources = existing.sources
        if !currentSources.contains(sub.providerName) {
          currentSources.append(sub.providerName)
        }
        existing.sources = currentSources

        // If new subtitle has higher score or more downloads, use its primary data
        if sub.score > existing.score || (sub.score == existing.score && sub.downloads > existing.downloads) {
          let updated = SubtitleResult(
            id: sub.id,
            providerID: sub.providerID,
            providerName: sub.providerName,
            language: sub.language,
            languageCode: sub.languageCode,
            title: sub.title,
            release: sub.release ?? existing.release,
            season: sub.season ?? existing.season,
            episode: sub.episode ?? existing.episode,
            format: sub.format,
            fps: sub.fps ?? existing.fps,
            resolution: sub.resolution ?? existing.resolution,
            hearingImpaired: sub.hearingImpaired || existing.hearingImpaired,
            forced: sub.forced || existing.forced,
            downloads: max(sub.downloads, existing.downloads),
            rating: max(sub.rating, existing.rating),
            uploader: sub.uploader ?? existing.uploader,
            downloadURL: sub.downloadURL ?? existing.downloadURL,
            fileId: sub.fileId ?? existing.fileId,
            score: sub.score,
            matchReasons: sub.matchReasons,
            sources: currentSources,
            extraData: sub.extraData.merging(existing.extraData) { current, _ in current }
          )
          map[key] = updated
        } else {
          map[key] = existing
        }
      } else {
        var newSub = sub
        newSub.sources = [sub.providerName]
        map[key] = newSub
      }
    }

    return Array(map.values)
  }
}
