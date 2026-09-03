import SwiftUI
import AppKit

/// Mirrors `init_basic_panel` in yt_dlp_gui_wx.py: URL field, download path
/// + Browse, format picker + custom format, Start/Stop/Update buttons,
/// and progress display.
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
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Video URL") {
                    TextField("Enter YouTube or other video website URL...", text: $options.url)
                        .textFieldStyle(.roundedBorder)
                        .padding(8)
                }

                GroupBox("Download Path") {
                    HStack {
                        TextField("Download path", text: $options.savePath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse") { browseForFolder() }
                    }
                    .padding(8)
                }

                GroupBox("Video Quality") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Format:")
                            Picker("", selection: $options.formatPreset) {
                                ForEach(FormatPreset.allCases) { preset in
                                    Text(preset.displayName).tag(preset)
                                }
                            }
                            .labelsHidden()

                            Button("Check Available Formats") { checkFormats() }
                                .disabled(isCheckingFormats || invocation == nil)
                            if isCheckingFormats {
                                ProgressView().controlSize(.small)
                            }
                        }

                        HStack {
                            Text("Custom:")
                            TextField("", text: $options.customFormat)
                                .textFieldStyle(.roundedBorder)
                                .disabled(options.formatPreset != .custom)
                        }

                        if let formatCheckStatus {
                            StatusBanner(success: formatCheckStatus.success, message: formatCheckStatus.message)
                        }
                    }
                    .padding(8)
                }

                HStack {
                    Button("Start Download") { startDownload() }
                        .disabled(downloadRunner.isRunning || invocation == nil)

                    Button("Stop Download") { downloadRunner.stop() }
                        .disabled(!downloadRunner.isRunning)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Button("Update yt-dlp") { updateYtDlp() }
                            .disabled(isUpdating || invocation == nil)
                        if let version = dependencyManager.ytDlpVersion {
                            Text("Current: \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)

                if isUpdating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Updating yt-dlp…")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                } else if let updateStatus {
                    StatusBanner(success: updateStatus.success, message: updateStatus.message)
                }

                GroupBox("Download Progress") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let current = playlistCurrent, let total = playlistTotal, total > 1 {
                            Text("Playlist item \(current) of \(total)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(progressText)
                        if let fraction = progressFraction {
                            ProgressView(value: fraction)
                        } else if downloadRunner.isRunning {
                            ProgressView()
                        } else {
                            ProgressView(value: 0)
                        }
                    }
                    .padding(8)
                }
            }
            .padding()
        }
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

/// Compact inline result indicator, used so outcomes (update result, format
/// check result) are visible directly in the Basic Settings tab instead of
/// only in the Log tab.
private struct StatusBanner: View {
    let success: Bool
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(success ? .green : .red)
            Text(message)
                .font(.callout)
                .foregroundColor(success ? .primary : .red)
        }
    }
}
