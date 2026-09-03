import Foundation

/// Mirrors `on_update_ytdlp` in yt_dlp_gui_wx.py: runs
/// `pip install -U yt-dlp` and `pip install -U yt-dlp[default]` and reports
/// on both independently.
///
/// `update` is `@MainActor`-isolated so calling it always hops onto the main
/// actor before touching `log` (which mutates an `@Published` `LogStore`);
/// the actual blocking `Process` calls run inside `Task.detached` so they
/// never block the UI.
enum YtDlpUpdater {
    @MainActor
    static func update(pythonPath: String, log: @escaping (String, Bool) -> Void) async {
        log("🔄 Updating yt-dlp and yt-dlp[default]...", false)

        async let result1 = runPipUpgrade(pythonPath: pythonPath, package: "yt-dlp")
        async let result2 = runPipUpgrade(pythonPath: pythonPath, package: "yt-dlp[default]")

        let (success1, error1) = await result1
        let (success2, error2) = await result2

        switch (success1, success2) {
        case (true, true):
            log("✅ yt-dlp and yt-dlp[default] updated successfully!", false)
        case (true, false):
            log("❌ yt-dlp[default] update failed: \(error2 ?? "")", true)
        case (false, true):
            log("❌ yt-dlp update failed: \(error1 ?? "")", true)
        case (false, false):
            log("❌ yt-dlp update failed: \(error1 ?? "")", true)
            log("❌ yt-dlp[default] update failed: \(error2 ?? "")", true)
        }
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
