import SwiftUI
import AppKit

/// Mirrors `init_basic_panel` in yt_dlp_gui_wx.py: URL field, download path
/// + Browse, format picker + custom format, Start/Stop/Update buttons,
/// and progress display.
struct BasicSettingsView: View {
    @ObservedObject var options: DownloadOptions
    @ObservedObject var logStore: LogStore
    @ObservedObject var downloadRunner: DownloadRunner
    let invocation: YtDlpInvocation?

    @Binding var progressText: String
    @Binding var progressFraction: Double?

    @State private var isCheckingFormats = false
    @State private var isUpdating = false

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
                        }

                        HStack {
                            Text("Custom:")
                            TextField("", text: $options.customFormat)
                                .textFieldStyle(.roundedBorder)
                                .disabled(options.formatPreset != .custom)
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

                    Button("Update yt-dlp") { updateYtDlp() }
                        .disabled(isUpdating || invocation == nil)
                }
                .padding(.vertical, 8)

                GroupBox("Download Progress") {
                    VStack(alignment: .leading, spacing: 8) {
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

        downloadRunner.start(
            invocation: invocation,
            arguments: options.buildArguments(),
            url: trimmedURL,
            onLog: { text, isError in logStore.append(text, isError: isError) },
            onProgress: { text in
                progressText = text
                progressFraction = Self.parseProgressFraction(from: text)
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
        Task {
            await FormatChecker.check(invocation: invocation, url: trimmedURL) { text, isError in
                logStore.append(text, isError: isError)
            }
            isCheckingFormats = false
        }
    }

    private func updateYtDlp() {
        guard let invocation else { return }
        isUpdating = true
        Task {
            await YtDlpUpdater.update(pythonPath: invocation.pythonPath) { text, isError in
                logStore.append(text, isError: isError)
            }
            isUpdating = false
        }
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
