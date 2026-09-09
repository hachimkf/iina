//
//  SmartSubtitlesSidebarView.swift
//  iina
//
//  Created for IINA Smart Subtitles native sidebar integration.
//

import Cocoa

public final class SmartSubtitlesSidebarView: NSView, NSTableViewDelegate, NSTableViewDataSource {

  private unowned let player: PlayerCore

  // Header / Video title info
  private let headerLabel = NSTextField(labelWithString: "")
  private let metaLabel = NSTextField(labelWithString: "")

  // Search & Language Controls
  private let languagePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
  private let searchButton = NSButton(title: "Search", target: nil, action: nil)

  // Status & Progress
  private let statusIndicator = NSProgressIndicator()
  private let statusLabel = NSTextField(labelWithString: "")

  // Results Table
  private let scrollView = NSScrollView()
  private let tableView = NSTableView()

  // State
  private var searchRequest: SubtitleSearchRequest?
  private var searchResults: [SubtitleResult] = []
  private var isSearching = false
  private var downloadingID: String?

  private var heightConstraint: NSLayoutConstraint?

  public init(player: PlayerCore) {
    self.player = player
    super.init(frame: .zero)
    setupUI()

    // Listen for file changes or external triggers
    player.observe(.iinaFileLoaded) { [weak self] _ in
      self?.reset()
    }
    NotificationCenter.default.addObserver(self, selector: #selector(onTriggerSearchNotification), name: .iinaTriggerSmartSubSearch, object: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func onTriggerSearchNotification() {
    startSearch()
  }

  public func reset() {
    searchResults = []
    tableView.reloadData()
    updateHeight()
    statusLabel.stringValue = ""
    statusIndicator.stopAnimation(nil)
    headerLabel.stringValue = ""
    metaLabel.stringValue = ""
  }

  private func setupUI() {
    translatesAutoresizingMaskIntoConstraints = false

    // Title / Meta
    headerLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
    headerLabel.lineBreakMode = .byTruncatingTail
    headerLabel.translatesAutoresizingMaskIntoConstraints = false

    metaLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
    metaLabel.textColor = NSColor.secondaryLabelColor
    metaLabel.lineBreakMode = .byTruncatingTail
    metaLabel.translatesAutoresizingMaskIntoConstraints = false

    // Language selector
    languagePopUp.translatesAutoresizingMaskIntoConstraints = false
    languagePopUp.controlSize = .small
    languagePopUp.font = NSFont.systemFont(ofSize: 11)

    let reg = SubtitleLanguageRegistry.shared
    for lang in reg.languages {
      let item = NSMenuItem(title: "\(lang.flag) \(lang.name)", action: nil, keyEquivalent: "")
      item.representedObject = lang.code
      languagePopUp.menu?.addItem(item)
    }

    let savedLang = Preference.string(for: .subLang) ?? "fra"
    let normSaved = reg.normalize(savedLang.components(separatedBy: ",").first)
    if let idx = reg.languages.firstIndex(where: { $0.code == normSaved }) {
      languagePopUp.selectItem(at: idx)
    }

    languagePopUp.target = self
    languagePopUp.action = #selector(onLanguageChanged)

    // Search button
    searchButton.translatesAutoresizingMaskIntoConstraints = false
    searchButton.bezelStyle = .rounded
    searchButton.controlSize = .small
    searchButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    searchButton.target = self
    searchButton.action = #selector(onSearchClicked)

    let langStack = NSStackView(views: [languagePopUp, searchButton])
    langStack.orientation = .horizontal
    langStack.spacing = 6
    langStack.translatesAutoresizingMaskIntoConstraints = false

    // Status row
    statusIndicator.style = .spinning
    statusIndicator.controlSize = .small
    statusIndicator.isDisplayedWhenStopped = false
    statusIndicator.translatesAutoresizingMaskIntoConstraints = false

    statusLabel.font = NSFont.systemFont(ofSize: 10)
    statusLabel.textColor = NSColor.secondaryLabelColor
    statusLabel.lineBreakMode = .byTruncatingTail
    statusLabel.translatesAutoresizingMaskIntoConstraints = false

    let statusStack = NSStackView(views: [statusIndicator, statusLabel])
    statusStack.orientation = .horizontal
    statusStack.spacing = 6
    statusStack.alignment = .centerY
    statusStack.translatesAutoresizingMaskIntoConstraints = false

    // Table view
    let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SubCell"))
    col.title = "Subtitles"
    tableView.addTableColumn(col)
    tableView.headerView = nil
    tableView.delegate = self
    tableView.dataSource = self
    tableView.rowHeight = 64
    tableView.backgroundColor = .clear
    tableView.target = self
    tableView.doubleAction = #selector(onTableDoubleClicked)

    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.borderType = .bezelBorder
    scrollView.wantsLayer = true
    scrollView.layer?.cornerRadius = 6
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    addSubview(headerLabel)
    addSubview(metaLabel)
    addSubview(langStack)
    addSubview(statusStack)
    addSubview(scrollView)

    let heightConstraint = heightAnchor.constraint(equalToConstant: 72)
    self.heightConstraint = heightConstraint

    NSLayoutConstraint.activate([
      headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      headerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

      metaLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 2),
      metaLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      metaLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

      langStack.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 6),
      langStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      langStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

      statusStack.topAnchor.constraint(equalTo: langStack.bottomAnchor, constant: 4),
      statusStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      statusStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

      scrollView.topAnchor.constraint(equalTo: statusStack.bottomAnchor, constant: 4),
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

      heightConstraint
    ])

    updateHeight()
  }

  private func updateHeight() {
    if searchResults.isEmpty && !isSearching {
      // Compact height when no results
      heightConstraint?.constant = 72
      scrollView.isHidden = true
    } else {
      // Expanded height with table visible (~280pt)
      heightConstraint?.constant = 280
      scrollView.isHidden = false
    }
  }

  @objc private func onLanguageChanged() {
    startSearch()
  }

  @objc private func onSearchClicked() {
    startSearch()
  }

  public func startSearch() {
    guard let currentURL = player.info.currentURL else {
      headerLabel.stringValue = "No video opened"
      metaLabel.stringValue = "Open a video to search subtitles"
      statusLabel.stringValue = ""
      updateHeight()
      return
    }

    let rawTitle = player.getMediaTitle()
    let parsed = VideoFilenameParser.parse(rawTitle.isEmpty ? currentURL.lastPathComponent : rawTitle)

    headerLabel.stringValue = parsed.cleanTitle
    var metaTokens: [String] = []
    if let se = parsed.seasonEpisode { metaTokens.append(se) }
    else if let y = parsed.year { metaTokens.append(String(y)) }
    if let src = parsed.source { metaTokens.append(src) }
    if let res = parsed.resolution { metaTokens.append(res) }
    metaLabel.stringValue = metaTokens.isEmpty ? currentURL.lastPathComponent : metaTokens.joined(separator: " • ")

    // Compute hash if local file
    var hashStr: String? = nil
    var fileSize: UInt64? = nil
    if currentURL.isFileURL {
      if let handle = try? FileHandle(forReadingFrom: currentURL) {
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        fileSize = handle.offsetInFile
        if let sz = fileSize, sz > 131072 {
          let chunkSize = 65536
          let offsets = [0, sz - UInt64(chunkSize)]
          var h: UInt64 = 0
          for off in offsets {
            handle.seek(toFileOffset: off)
            h &+= handle.readData(ofLength: chunkSize).chksum64
          }
          h &+= sz
          hashStr = String(format: "%016qx", h)
        }
      }
    }

    let selectedLang = (languagePopUp.selectedItem?.representedObject as? String) ?? "fra"

    var enabledProviders = Set<String>()
    if Preference.bool(for: .smartSubProviderOpenSubtitles) { enabledProviders.insert("opensubtitles") }
    if Preference.bool(for: .smartSubProviderSubDL) { enabledProviders.insert("subdl") }
    if Preference.bool(for: .smartSubProviderWyzie) { enabledProviders.insert("wyzie") }
    if enabledProviders.isEmpty {
      enabledProviders = ["opensubtitles", "subdl", "wyzie"]
    }

    let providerKeys: [String: String] = [
      "subdl": Preference.string(for: .smartSubSubDLApiKey) ?? "",
      "wyzie": Preference.string(for: .smartSubWyzieApiKey) ?? ""
    ]

    self.searchRequest = SubtitleSearchRequest(
      mediaURL: currentURL,
      filename: currentURL.lastPathComponent,
      cleanTitle: parsed.cleanTitle,
      year: parsed.year,
      season: parsed.season,
      episode: parsed.episode,
      seasonEpisode: parsed.seasonEpisode,
      resolution: parsed.resolution,
      source: parsed.source,
      codec: parsed.codec,
      audio: parsed.audio,
      releaseGroup: parsed.releaseGroup,
      videoHash: hashStr,
      fileSize: fileSize,
      language: selectedLang,
      allowFallback: Preference.bool(for: .smartSubAllowFallback),
      enabledProviders: enabledProviders,
      providerKeys: providerKeys
    )

    performSearch()
  }

  private func performSearch() {
    guard let req = searchRequest, !isSearching else { return }

    isSearching = true
    searchButton.isEnabled = false
    statusIndicator.startAnimation(nil)
    statusLabel.stringValue = "Searching online subtitles…"
    searchResults = []
    tableView.reloadData()
    updateHeight()

    Task { @MainActor in
      let outcome = await SubtitleSearchEngine.shared.search(request: req) { status in
        Task { @MainActor in
          self.statusLabel.stringValue = "\(status.providerName): \(status.message ?? "")"
        }
      }

      self.searchResults = outcome.results
      self.tableView.reloadData()
      self.isSearching = false
      self.searchButton.isEnabled = true
      self.statusIndicator.stopAnimation(nil)
      self.updateHeight()

      if outcome.results.isEmpty {
        let langName = SubtitleLanguageRegistry.shared.language(for: req.language)?.name ?? req.language
        self.statusLabel.stringValue = "No \(langName) subtitles found."
      } else {
        self.statusLabel.stringValue = "Found \(outcome.results.count) subtitles."

        if Preference.bool(for: .smartSubAutoDownload),
           let best = outcome.results.first,
           best.score >= Preference.integer(for: .smartSubAutoDownloadThreshold) {
          self.downloadSubtitle(best)
        }
      }
    }
  }

  public func downloadSubtitle(_ sub: SubtitleResult) {
    guard downloadingID == nil else { return }
    downloadingID = sub.id
    statusIndicator.startAnimation(nil)
    statusLabel.stringValue = "Downloading \(sub.title)…"
    tableView.reloadData()

    Task { @MainActor in
      defer {
        self.downloadingID = nil
        self.statusIndicator.stopAnimation(nil)
        self.tableView.reloadData()
      }

      guard let provider = SubtitleSearchEngine.shared.provider(for: sub.providerID) else {
        self.statusLabel.stringValue = "Error: Provider not available"
        return
      }

      do {
        let localURL = try await provider.download(result: sub)

        var finalURL = localURL
        if Preference.bool(for: .smartSubSaveBesideVideo),
           let videoURL = self.player.info.currentURL,
           videoURL.isFileURL {
          let videoDir = videoURL.deletingLastPathComponent()
          let targetFilename = "\(videoURL.deletingPathExtension().lastPathComponent).\(sub.format)"
          let destination = videoDir.appendingPathComponent(targetFilename)
          try? FileManager.default.removeItem(at: destination)
          try? FileManager.default.copyItem(at: localURL, to: destination)
          finalURL = destination
        }

        self.player.loadExternalSubFile(finalURL)
        let msg = "Loaded: \(sub.language) (\(sub.score)% match)"
        self.player.sendOSD(.custom(msg))
        self.statusLabel.stringValue = "✓ Loaded: \(sub.title)"
      } catch {
        self.statusLabel.stringValue = "Download failed: \(error.localizedDescription)"
        self.player.sendOSD(.custom("Failed to download subtitle"))
      }
    }
  }

  @objc private func onTableDoubleClicked() {
    let row = tableView.selectedRow
    guard row >= 0, row < searchResults.count else { return }
    downloadSubtitle(searchResults[row])
  }

  // MARK: - NSTableViewDelegate & DataSource

  public func numberOfRows(in tableView: NSTableView) -> Int {
    return searchResults.count
  }

  public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let sub = searchResults[row]
    let identifier = NSUserInterfaceItemIdentifier("SidebarSubtitleCellView")

    var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? SidebarSubtitleCellView
    if cellView == nil {
      cellView = SidebarSubtitleCellView()
      cellView?.identifier = identifier
    }

    cellView?.configure(with: sub, isDownloading: downloadingID == sub.id) { [weak self] in
      self?.downloadSubtitle(sub)
    }

    return cellView
  }
}

// MARK: - Compact Cell View designed for Sidebar (~280-320pt)

fileprivate final class SidebarSubtitleCellView: NSTableCellView {

  private let scoreBadge = NSTextField(labelWithString: "")
  private let titleLabel = NSTextField(labelWithString: "")
  private let infoLabel = NSTextField(labelWithString: "")
  private let downloadButton = NSButton(title: "Get", target: nil, action: nil)
  private var onDownload: (() -> Void)?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    scoreBadge.font = NSFont.systemFont(ofSize: 10, weight: .bold)
    scoreBadge.textColor = .white
    scoreBadge.alignment = .center
    scoreBadge.wantsLayer = true
    scoreBadge.layer?.cornerRadius = 3
    scoreBadge.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
    titleLabel.lineBreakMode = .byTruncatingTail
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    infoLabel.font = NSFont.systemFont(ofSize: 9.5)
    infoLabel.textColor = NSColor.secondaryLabelColor
    infoLabel.lineBreakMode = .byTruncatingTail
    infoLabel.translatesAutoresizingMaskIntoConstraints = false

    downloadButton.bezelStyle = .rounded
    downloadButton.controlSize = .mini
    downloadButton.font = NSFont.systemFont(ofSize: 10, weight: .medium)
    downloadButton.target = self
    downloadButton.action = #selector(onButtonClicked)
    downloadButton.translatesAutoresizingMaskIntoConstraints = false

    addSubview(scoreBadge)
    addSubview(titleLabel)
    addSubview(infoLabel)
    addSubview(downloadButton)

    NSLayoutConstraint.activate([
      scoreBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      scoreBadge.topAnchor.constraint(equalTo: topAnchor, constant: 6),
      scoreBadge.widthAnchor.constraint(equalToConstant: 34),
      scoreBadge.heightAnchor.constraint(equalToConstant: 18),

      downloadButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      downloadButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      downloadButton.widthAnchor.constraint(equalToConstant: 54),

      titleLabel.leadingAnchor.constraint(equalTo: scoreBadge.trailingAnchor, constant: 6),
      titleLabel.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -4),
      titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),

      infoLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      infoLabel.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -4),
      infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2)
    ])
  }

  @objc private func onButtonClicked() {
    onDownload?()
  }

  func configure(with sub: SubtitleResult, isDownloading: Bool, downloadAction: @escaping () -> Void) {
    self.onDownload = downloadAction

    scoreBadge.stringValue = "\(sub.score)%"
    if sub.score >= 85 {
      scoreBadge.layer?.backgroundColor = NSColor.systemGreen.cgColor
    } else if sub.score >= 60 {
      scoreBadge.layer?.backgroundColor = NSColor.systemOrange.cgColor
    } else {
      scoreBadge.layer?.backgroundColor = NSColor.systemGray.cgColor
    }

    titleLabel.stringValue = sub.title

    var infoParts: [String] = []
    infoParts.append(sub.providerName)
    if let rel = sub.release, !rel.isEmpty {
      infoParts.append(rel)
    } else {
      infoParts.append(sub.format.uppercased())
    }
    if !sub.matchReasons.isEmpty {
      infoParts.append(sub.matchReasons.joined(separator: " "))
    }
    infoLabel.stringValue = infoParts.joined(separator: " • ")

    downloadButton.isEnabled = !isDownloading
    downloadButton.title = isDownloading ? "..." : "Get"
  }
}
