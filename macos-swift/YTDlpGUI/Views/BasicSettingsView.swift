import SwiftUI
import AppKit

/// Mirrors `init_basic_panel` in yt_dlp_gui_wx.py: URL field, download path
/// + Browse, format picker + custom format, Start/Stop/Update buttons,
/// and progress display. Laid out as grouped, inset cards (macOS System
/// Settings style) inside a light content background.
struct BasicSettingsView: View {
    @ObservedObject var options: DownloadOptions
    @ObservedObject var logStore: LogStore
    @ObservedObject var downloadRunner: DownloadRunner
    @ObservedObject var dependencyManager: DependencyManager
    let invocation: YtDlpInvocation?

    @Binding var progressText: String
    @Binding var progressFraction: Double?

    @State private var isCheckingFormats = false
    @State private var isUpdating = false

    @State private var updateStatus: (success: Bool, message: String)?
    @State private var formatCheckStatus: (success: Bool, message: String)?

    // Tracks "Downloading item N of M" for playlist URLs, so the progress
    // bar reflects overall playlist completion instead of resetting to 100%
    // (and looking finished) after every individual video.
    @State private var playlistCurrent: Int?
    @State private var playlistTotal: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Download")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.top, 2)

                SectionCard(title: "Video URL") {
                    SectionRow(showDivider: false) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        TextField("Paste a YouTube or other video URL…", text: $options.url)
                            .textFieldStyle(.plain)
                    }
                }

                SectionCard(title: "Download Location") {
                    SectionRow(showDivider: false) {
                        Image(systemName: "folder")
                            .foregroundStyle(Color.accentColor)
                        Text(options.savePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Choose…") { browseForFolder() }
                    }
                }

                SectionCard(title: "Video Quality") {
                    SectionRow {
                        Text("Format")
                            .frame(width: 90, alignment: .leading)
                        Picker("", selection: $options.formatPreset) {
                            ForEach(FormatPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .labelsHidden()
                    }

                    SectionRow {
                        Text("Custom")
                            .frame(width: 90, alignment: .leading)
                            .foregroundStyle(options.formatPreset == .custom ? .primary : .secondary)
                        TextField("", text: $options.customFormat)
                            .textFieldStyle(.roundedBorder)
                            .disabled(options.formatPreset != .custom)
                    }

                    SectionRow(showDivider: false) {
                        Button("Check Available Formats") { checkFormats() }
                            .disabled(isCheckingFormats || invocation == nil)
                        if isCheckingFormats {
                            ProgressView().controlSize(.small)
                        }
                        if let formatCheckStatus {
                            StatusBanner(success: formatCheckStatus.success, message: formatCheckStatus.message)
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        startDownload()
                    } label: {
                        Label("Start Download", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(downloadRunner.isRunning || invocation == nil)

                    Button("Stop") { downloadRunner.stop() }
                        .buttonStyle(.bordered)
                        .disabled(!downloadRunner.isRunning)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Button {
                            updateYtDlp()
                        } label: {
                            Label("Update yt-dlp", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUpdating || invocation == nil)

                        if let version = dependencyManager.ytDlpVersion {
                            Text("Current: \(version)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isUpdating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Updating yt-dlp…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if let updateStatus {
                    StatusBanner(success: updateStatus.success, message: updateStatus.message)
                }

                SectionCard(title: "Progress") {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(progressText)
                                .font(.system(size: 13))
                            Spacer()
                            if let current = playlistCurrent, let total = playlistTotal, total > 1 {
                                Text("Playlist item \(current) of \(total)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let fraction = progressFraction {
                            ProgressView(value: fraction)
                        } else if downloadRunner.isRunning {
                            ProgressView()
                        } else {
                            ProgressView(value: 0)
                        }
                    }
                    .padding(14)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: options.savePath)
        if panel.runModal() == .OK, let url = panel.url {
            options.savePath = url.path
        }
    }

    private func startDownload() {
        guard let invocation else { return }
        let trimmedURL = options.trimmedURL
        guard !trimmedURL.isEmpty else {
            presentAlert(title: "Warning", message: "Please enter video URL!")
            return
        }
        guard !options.savePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            presentAlert(title: "Warning", message: "Please select download path!")
            return
        }

        try? FileManager.default.createDirectory(
            atPath: options.savePath, withIntermediateDirectories: true
        )

        logStore.append("🚀 Starting download: \(trimmedURL)")
        logStore.append("💾 Save to: \(options.savePath)")

        progressText = "Downloading..."
        progressFraction = nil
        playlistCurrent = nil
        playlistTotal = nil

        downloadRunner.start(
            invocation: invocation,
            arguments: options.buildArguments(),
            url: trimmedURL,
            onLog: { text, isError in
                if let item = Self.parsePlaylistItem(from: text) {
                    playlistCurrent = item.current
                    playlistTotal = item.total
                }
                logStore.append(text, isError: isError)
            },
            onProgress: { text in
                let itemFraction = Self.parseProgressFraction(from: text)
                if let current = playlistCurrent, let total = playlistTotal, total > 1 {
                    // Overall playlist fraction, so the bar doesn't look
                    // "done" after just the first video finishes.
                    let completedItems = Double(current - 1)
                    progressFraction = min(1, max(0, (completedItems + (itemFraction ?? 0)) / Double(total)))
                } else {
                    progressFraction = itemFraction
                }
                progressText = text
                logStore.append(text)
            },
            onFinished: { success, message in
                progressFraction = success ? 1.0 : 0.0
                progressText = success ? "Download completed!" : "Download failed"
                logStore.append(success ? "✅ \(message)" : "❌ \(message)", isError: !success)
                presentAlert(title: success ? "Success" : "Error", message: message)
            }
        )
    }

    private func checkFormats() {
        guard let invocation else { return }
        let trimmedURL = options.trimmedURL
        guard !trimmedURL.isEmpty else {
            presentAlert(title: "Warning", message: "Please enter video URL first!")
            return
        }
        isCheckingFormats = true
        formatCheckStatus = nil
        Task {
            let result = await FormatChecker.check(invocation: invocation, url: trimmedURL) { text, isError in
                logStore.append(text, isError: isError)
            }
            formatCheckStatus = result
            isCheckingFormats = false
        }
    }

    private func updateYtDlp() {
        guard let invocation else { return }
        isUpdating = true
        updateStatus = nil
        Task {
            let result = await YtDlpUpdater.update(pythonPath: invocation.pythonPath) { text, isError in
                logStore.append(text, isError: isError)
            }
            updateStatus = result
            if result.success {
                await dependencyManager.refreshVersion(invocation: invocation)
            }
            isUpdating = false
        }
    }

    /// Parses "[download] Downloading item N of M" playlist marker lines.
    private static func parsePlaylistItem(from line: String) -> (current: Int, total: Int)? {
        guard line.contains("Downloading item") else { return nil }
        let parts = line.components(separatedBy: "item ")
        guard parts.count > 1 else { return nil }
        let tokens = parts[1].split(separator: " ")
        guard tokens.count >= 3, tokens[1] == "of" else { return nil }
        guard let current = Int(tokens[0]), let total = Int(tokens[2].filter(\.isNumber)) else { return nil }
        return (current, total)
    }

    private static func parseProgressFraction(from line: String) -> Double? {
        // Lines look like "[download]  42.3% of ...". Extract the number before '%'.
        guard let percentRange = line.range(of: "%") else { return nil }
        let prefix = line[line.startIndex..<percentRange.lowerBound]
        let numberString = prefix.split(separator: " ").last.map(String.init) ?? ""
        guard let value = Double(numberString) else { return nil }
        return max(0, min(1, value / 100))
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
