import Foundation

/// Runs a yt-dlp download as a subprocess and streams its output, mirroring
/// `DownloadWorker` in yt_dlp_gui_wx.py: line-buffered stdout, `[download]`+`%`
/// lines routed to a progress callback, everything else to the log, and a
/// terminate-then-kill shutdown sequence.
@MainActor
final class DownloadRunner: ObservableObject {
    @Published private(set) var isRunning = false

    private var process: Process?
    private var outputHandle: FileHandle?

    /// Starts the download. `onLog` receives normal log lines, `onProgress`
    /// receives `[download] NN.N%` lines, `onFinished` fires once when the
    /// process exits (success flag + message).
    func start(
        invocation: YtDlpInvocation,
        arguments: [String],
        url: String,
        onLog: @escaping (String, Bool) -> Void,
        onProgress: @escaping (String) -> Void,
        onFinished: @escaping (Bool, String) -> Void
    ) {
        guard !isRunning else { return }

        let fullCommand = invocation.baseCommand + arguments + [url]
        onLog("⚙️ Command: \(fullCommand.joined(separator: " "))", false)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = fullCommand
        process.environment = JsRuntimeEnvironment.subprocessEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        self.outputHandle = pipe.fileHandleForReading

        let buffer = LineBuffer()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let lines = buffer.appendAndExtractLines(data)
            guard !lines.isEmpty else { return }

            Task { @MainActor in
                for trimmed in lines {
                    if trimmed.contains("[download]") && trimmed.contains("%") {
                        onProgress(trimmed)
                    } else {
                        onLog(trimmed, false)
                    }
                }
            }
            _ = self // keep self alive for the closure's lifetime
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor in
                guard let self else { return }
                pipe.fileHandleForReading.readabilityHandler = nil
                self.isRunning = false
                self.process = nil
                let success = terminatedProcess.terminationStatus == 0
                if success {
                    onFinished(true, "Download completed!")
                } else {
                    onFinished(false, "Download failed, return code: \(terminatedProcess.terminationStatus)")
                }
            }
        }

        do {
            try process.run()
            self.process = process
            isRunning = true
        } catch {
            onFinished(false, "Download error: \(error.localizedDescription)")
        }
    }

    /// Terminates the running download: SIGTERM, then SIGKILL after a grace period.
    func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()

        Task {
            for _ in 0..<50 { // up to 5 seconds, matching the Python version
                if !process.isRunning { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            if process.isRunning {
                process.interrupt() // best-effort; Process has no direct SIGKILL API
                kill(process.processIdentifier, SIGKILL)
            }
        }
    }
}

/// Confines line-buffering state to a single reference type so the
/// readability handler's mutations are isolated and Sendable-clean.
private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func appendAndExtractLines(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(data)
        var lines: [String] = []
        while let newlineRange = buffer.range(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<newlineRange.upperBound)
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            lines.append(trimmed)
        }
        return lines
    }
}
