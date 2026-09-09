//
//  SubtitleProvider.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

/// Protocol for all native IINA subtitle providers.
public protocol SubtitleProvider: AnyObject {
  /// Unique identifier of the provider, e.g. "opensubtitles", "subdl", "wyzie"
  var id: String { get }

  /// Human-readable display name, e.g. "OpenSubtitles", "SubDL", "Wyzie"
  var name: String { get }

  /// Whether the provider is configured and available for querying
  var isAvailable: Bool { get }

  /// Performs concurrent search for matching subtitles
  func search(request: SubtitleSearchRequest) async throws -> [SubtitleResult]

  /// Downloads the subtitle file to a local destination and returns the local file URL
  func download(result: SubtitleResult) async throws -> URL
}
