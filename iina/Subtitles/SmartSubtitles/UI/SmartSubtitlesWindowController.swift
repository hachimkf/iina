//
//  SmartSubtitlesWindowController.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Cocoa

public final class SmartSubtitlesWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

  public static var shared: SmartSubtitlesWindowController?

  private unowned let player: PlayerCore

  // UI Components
  private let videoTitleLabel = NSTextField(labelWithString: "")
  private let videoMetaLabel = NSTextField(labelWithString: "")
  private let languagePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
  private let searchButton = NSButton(title: "Search Subtitles", target: nil, action: nil)

  private let openSubCheckbox = NSButton(checkboxWithTitle: "OpenSubtitles", target: nil, action: nil)
  private let subdlCheckbox = NSButton(checkboxWithTitle: "SubDL", target: nil, action: nil)
  private let wyzieCheckbox = NSButton(checkboxWithTitle: "Wyzie", target: nil, action: nil)

  private let statusIndicator = NSProgressIndicator()
  private let statusLabel = NSTextField(labelWithString: "")
  private let tableView = NSTableView()
  private let scrollView = NSScrollView()

  private var searchRequest: SubtitleSearchRequest?
  private var searchResults: [SubtitleResult] = []
  private var isSearching = false
  private var downloadingID: String?

  init(player: PlayerCore) {
    self.player = player

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Find Online Subtitles"
    window.minSize = NSSize(width: 480, height: 420)
    window.center()

    super.init(window: window)
    setupUI()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  static func show(for player: PlayerCore) {
    if shared == nil {
      shared = SmartSubtitlesWindowController(player: player)
    }
    shared?.window?.makeKeyAndOrderFront(nil)
    shared?.prepareSearch()
  }

  private func setupUI() {
    guard let contentView = window?.contentView else { return }

    // Header Card (Video Metadata)
    let headerBox = NSBox()
    headerBox.titlePosition = .noTitle
    headerBox.boxType = .custom
    headerBox.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6)
    headerBox.borderColor = NSColor.separatorColor
    headerBox.cornerRadius = 8
    headerBox.translatesAutoresizingMaskIntoConstraints = false

    videoTitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
    videoTitleLabel.lineBreakMode = .byTruncatingTail
    videoTitleLabel.translatesAutoresizingMaskIntoConstraints = false

    videoMetaLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    videoMetaLabel.textColor = NSColor.secondaryLabelColor
    videoMetaLabel.translatesAutoresizingMaskIntoConstraints = false

    let headerStack = NSStackView(views: [videoTitleLabel, videoMetaLabel])
    headerStack.orientation = .vertical
    headerStack.alignment = .leading
    headerStack.spacing = 3
    headerStack.translatesAutoresizingMaskIntoConstraints = false

    headerBox.addSubview(headerStack)

    // Language Row
    let langLabel = NSTextField(labelWithString: "Language:")
    langLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
    langLabel.translatesAutoresizingMaskIntoConstraints = false

    languagePopUp.translatesAutoresizingMaskIntoConstraints = false
    let reg = SubtitleLanguageRegistry.shared
    for lang in reg.languages {
      let item = NSMenuItem(title: "\(lang.flag)  \(lang.name) (\(lang.code))", action: nil, keyEquivalent: "")
      item.representedObject = lang.code
      languagePopUp.menu?.addItem(item)
    }

    // Select user preferred language or default
    let savedLang = Preference.string(for: .subLang) ?? "fra"
    let normSaved = reg.normalize(savedLang.components(separatedBy: ",").first)
    if let idx = reg.languages.firstIndex(where: { $0.code == normSaved }) {
      languagePopUp.selectItem(at: idx)
    }

    // Sources Row
    openSubCheckbox.state = Preference.bool(for: .smartSubProviderOpenSubtitles) ? .on : .off
    subdlCheckbox.state = Preference.bool(for: .smartSubProviderSubDL) ? .on : .off
    wyzieCheckbox.state = Preference.bool(for: .smartSubProviderWyzie) ? .on : .off

    openSubCheckbox.target = self
    openSubCheckbox.action = #selector(onProviderToggled(_:))
    subdlCheckbox.target = self
    subdlCheckbox.action = #selector(onProviderToggled(_:))
    wyzieCheckbox.target = self
    wyzieCheckbox.action = #selector(onProviderToggled(_:))

    let sourcesStack = NSStackView(views: [openSubCheckbox, subdlCheckbox, wyzieCheckbox])
    sourcesStack.orientation = .horizontal
    sourcesStack.spacing = 14
    sourcesStack.translatesAutoresizingMaskIntoConstraints = false

    // Search button
    searchButton.bezelStyle = .rounded
    searchButton.keyEquivalent = "\r"
    searchButton.target = self
    searchButton.action = #selector(onSearchClicked(_:))
    searchButton.translatesAutoresizingMaskIntoConstraints = false

    let controlRow = NSStackView(views: [langLabel, languagePopUp, NSView(), searchButton])
    controlRow.orientation = .horizontal
    controlRow.alignment = .centerY
    controlRow.spacing = 8
    controlRow.translatesAutoresizingMaskIntoConstraints = false

    // Status Row
    statusIndicator.style = .spinning
    statusIndicator.controlSize = .small
    statusIndicator.isDisplayedWhenStopped = false
    statusIndicator.translatesAutoresizingMaskIntoConstraints = false

    statusLabel.font = NSFont.systemFont(ofSize: 11)
    statusLabel.textColor = NSColor.secondaryLabelColor
    statusLabel.translatesAutoresizingMaskIntoConstraints = false

    let statusStack = NSStackView(views: [statusIndicator, statusLabel])
    statusStack.orientation = .horizontal
    statusStack.spacing = 6
    statusStack.alignment = .centerY
    statusStack.translatesAutoresizingMaskIntoConstraints = false

    // Results Table View
    let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SubCell"))
    col.title = "Subtitles"
    tableView.addTableColumn(col)
    tableView.headerView = nil
    tableView.delegate = self
    tableView.dataSource = self
    tableView.rowHeight = 72
    tableView.backgroundColor = .clear
    tableView.target = self
    tableView.doubleAction = #selector(onTableDoubleClicked(_:))

    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.borderType = .bezelBorder
    scrollView.wantsLayer = true
    scrollView.layer?.cornerRadius = 6
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    // Main Layout
    contentView.addSubview(headerBox)
    contentView.addSubview(controlRow)
    contentView.addSubview(sourcesStack)
    contentView.addSubview(statusStack)
    contentView.addSubview(scrollView)

    NSLayoutConstraint.activate([
      headerBox.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
      headerBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      headerBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      headerStack.topAnchor.constraint(equalTo: headerBox.topAnchor, constant: 10),
      headerStack.bottomAnchor.constraint(equalTo: headerBox.bottomAnchor, constant: -10),
      headerStack.leadingAnchor.constraint(equalTo: headerBox.leadingAnchor, constant: 12),
      headerStack.trailingAnchor.constraint(equalTo: headerBox.trailingAnchor, constant: -12),

      controlRow.topAnchor.constraint(equalTo: headerBox.bottomAnchor, constant: 12),
      controlRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      controlRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      sourcesStack.topAnchor.constraint(equalTo: controlRow.bottomAnchor, constant: 10),
      sourcesStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

      statusStack.topAnchor.constraint(equalTo: sourcesStack.bottomAnchor, constant: 8),
      statusStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      statusStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      scrollView.topAnchor.constraint(equalTo: statusStack.bottomAnchor, constant: 8),
      scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
    ])
  }

  public func prepareSearch() {
    guard let currentURL = player.info.currentURL else {
      videoTitleLabel.stringValue = "No video opened"
      videoMetaLabel.stringValue = "Open a video in IINA to find online subtitles."
      searchButton.isEnabled = false
      return
    }

    let rawTitle = player.getMediaTitle()
    let parsed = VideoFilenameParser.parse(rawTitle.isEmpty ? currentURL.lastPathComponent : rawTitle)

    videoTitleLabel.stringValue = parsed.cleanTitle
    var metaTokens: [String] = []
    if let se = parsed.seasonEpisode { metaTokens.append(se) }
    else if let y = parsed.year { metaTokens.append(String(y)) }
    if let src = parsed.source { metaTokens.append(src) }
    if let res = parsed.resolution { metaTokens.append(res) }
    if let c = parsed.codec { metaTokens.append(c) }
    videoMetaLabel.stringValue = metaTokens.joined(separator: " • ")

    searchButton.isEnabled = true

    // Compute file hash if local
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
    if openSubCheckbox.state == .on { enabledProviders.insert("opensubtitles") }
    if subdlCheckbox.state == .on { enabledProviders.insert("subdl") }
    if wyzieCheckbox.state == .on { enabledProviders.insert("wyzie") }

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

    // Execute search automatically on open
    performSearch()
  }

  @objc private func onSearchClicked(_ sender: Any) {
    prepareSearch()
  }

  @objc private func onProviderToggled(_ sender: NSButton) {
    Preference.set(openSubCheckbox.state == .on, for: .smartSubProviderOpenSubtitles)
    Preference.set(subdlCheckbox.state == .on, for: .smartSubProviderSubDL)
    Preference.set(wyzieCheckbox.state == .on, for: .smartSubProviderWyzie)
  }

  private func performSearch() {
    guard let req = searchRequest, !isSearching else { return }

    isSearching = true
    searchButton.isEnabled = false
    statusIndicator.startAnimation(nil)
    statusLabel.stringValue = "Searching enabled sources…"
    searchResults = []
    tableView.reloadData()

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

      if outcome.results.isEmpty {
        let langName = SubtitleLanguageRegistry.shared.language(for: req.language)?.name ?? req.language
        self.statusLabel.stringValue = "No \(langName) subtitles found."
      } else {
        self.statusLabel.stringValue = "Found \(outcome.results.count) subtitles."

        // Check Auto-Download
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
        self.statusLabel.stringValue = "Error: Provider \(sub.providerName) not available"
        return
      }

      do {
        let localURL = try await provider.download(result: sub)

        // Save location: beside video if configured
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
        self.statusLabel.stringValue = "✓ Successfully loaded subtitle."
      } catch {
        self.statusLabel.stringValue = "Download failed: \(error.localizedDescription)"
        self.player.sendOSD(.custom("Failed to download subtitle"))
      }
    }
  }

  @objc private func onTableDoubleClicked(_ sender: Any) {
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
    let identifier = NSUserInterfaceItemIdentifier("SubtitleRowView")

    var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? SubtitleCellView
    if cellView == nil {
      cellView = SubtitleCellView()
      cellView?.identifier = identifier
    }

    cellView?.configure(with: sub, isDownloading: downloadingID == sub.id) { [weak self] in
      self?.downloadSubtitle(sub)
    }

    return cellView
  }
}

// MARK: - Custom Native Subtitle Table Cell View

fileprivate final class SubtitleCellView: NSTableCellView {

  private let scoreBadge = NSTextField(labelWithString: "")
  private let titleLabel = NSTextField(labelWithString: "")
  private let releaseLabel = NSTextField(labelWithString: "")
  private let sourcesLabel = NSTextField(labelWithString: "")
  private let tagsLabel = NSTextField(labelWithString: "")
  private let downloadButton = NSButton(title: "Download", target: nil, action: nil)
  private var onDownload: (() -> Void)?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupViews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    scoreBadge.font = NSFont.systemFont(ofSize: 11, weight: .bold)
    scoreBadge.textColor = .white
    scoreBadge.alignment = .center
    scoreBadge.wantsLayer = true
    scoreBadge.layer?.cornerRadius = 4
    scoreBadge.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    titleLabel.lineBreakMode = .byTruncatingTail
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    releaseLabel.font = NSFont.systemFont(ofSize: 11)
    releaseLabel.textColor = NSColor.secondaryLabelColor
    releaseLabel.lineBreakMode = .byTruncatingTail
    releaseLabel.translatesAutoresizingMaskIntoConstraints = false

    sourcesLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
    sourcesLabel.textColor = NSColor.secondaryLabelColor
    sourcesLabel.translatesAutoresizingMaskIntoConstraints = false

    tagsLabel.font = NSFont.systemFont(ofSize: 10)
    tagsLabel.textColor = NSColor.systemGreen
    tagsLabel.translatesAutoresizingMaskIntoConstraints = false

    downloadButton.bezelStyle = .rounded
    downloadButton.controlSize = .small
    downloadButton.target = self
    downloadButton.action = #selector(onButtonClicked)
    downloadButton.translatesAutoresizingMaskIntoConstraints = false

    addSubview(scoreBadge)
    addSubview(titleLabel)
    addSubview(releaseLabel)
    addSubview(sourcesLabel)
    addSubview(tagsLabel)
    addSubview(downloadButton)

    NSLayoutConstraint.activate([
      scoreBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      scoreBadge.topAnchor.constraint(equalTo: topAnchor, constant: 10),
      scoreBadge.widthAnchor.constraint(equalToConstant: 44),
      scoreBadge.heightAnchor.constraint(equalToConstant: 22),

      downloadButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
      downloadButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      downloadButton.widthAnchor.constraint(equalToConstant: 80),

      titleLabel.leadingAnchor.constraint(equalTo: scoreBadge.trailingAnchor, constant: 10),
      titleLabel.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -8),
      titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),

      releaseLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      releaseLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
      releaseLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

      sourcesLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      sourcesLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

      tagsLabel.leadingAnchor.constraint(equalTo: sourcesLabel.trailingAnchor, constant: 8),
      tagsLabel.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -8),
      tagsLabel.centerYAnchor.constraint(equalTo: sourcesLabel.centerYAnchor)
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
    releaseLabel.stringValue = sub.release ?? sub.format.uppercased()
    sourcesLabel.stringValue = "From: \(sub.sources.joined(separator: " · "))"
    tagsLabel.stringValue = sub.matchReasons.joined(separator: "  ")

    downloadButton.isEnabled = !isDownloading
    downloadButton.title = isDownloading ? "Loading…" : "Download"
  }
}
