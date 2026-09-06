import Foundation

/// Mirrors `on_update_ytdlp` in yt_dlp_gui_wx.py: runs
/// `pip install -U yt-dlp[default]`.
///
/// `update` is `@MainActor`-isolated so calling it always hops onto the main
/// actor before touching `log` (which mutates an `@Published` `LogStore`);
/// the actual blocking `Process` calls run inside `Task.detached` so they
/// never block the UI.
enum YtDlpUpdater {
    /// Returned so callers can surface the outcome in the UI, not just the log.
    @MainActor
    static func update(pythonPath: String, log: @escaping (String, Bool) -> Void) async -> (success: Bool, message: String) {
        log("🔄 Updating yt-dlp[default]...", false)

        let (success, error) = await runPipUpgrade(pythonPath: pythonPath, package: "yt-dlp[default]")

        let message: String
        if success {
            message = "yt-dlp[default] updated successfully!"
            log("✅ \(message)", false)
        } else {
            message = "yt-dlp[default] update failed: \(error ?? "")"
            log("❌ \(message)", true)
        }
        return (success, message)
    }

    private static func runPipUpgrade(pythonPath: String, package: String) async -> (Bool, String?) {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-m", "pip", "install", "-U", package]
            let errPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return (true, nil)
                }
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errText = String(data: errData, encoding: .utf8) ?? "unknown error"
                return (false, errText)
            } catch {
                return (false, error.localizedDescription)
            }
        }.value
    }
}
