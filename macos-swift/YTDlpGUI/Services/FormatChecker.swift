import Foundation

/// Mirrors `on_check_formats` in yt_dlp_gui_wx.py: runs
/// `yt-dlp --list-formats <url>` and logs each line of the result.
///
/// `check` is `@MainActor`-isolated so every `log(...)` call happens on the
/// main actor (required since it mutates an `@Published` `LogStore`), while
/// the actual blocking `Process` call runs inside `Task.detached` so it
/// never blocks the UI.
enum FormatChecker {
    /// Returned so callers can surface a summary in the UI, not just the log.
    @MainActor
    static func check(invocation: YtDlpInvocation, url: String, log: @escaping (String, Bool) -> Void) async -> (success: Bool, message: String) {
        log("🔍 Checking available formats...", false)

        let command = invocation.baseCommand + ["--list-formats", url]

        let result = await Task.detached(priority: .userInitiated) { () -> (output: String?, errorText: String?) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = command
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    return (String(data: data, encoding: .utf8) ?? "", nil)
                }
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                return (nil, String(data: errData, encoding: .utf8) ?? "unknown error")
            } catch {
                return (nil, error.localizedDescription)
            }
        }.value

        if let text = result.output {
            log("📋 Available formats:", false)
            var formatLineCount = 0
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
                if !trimmed.isEmpty {
                    log(String(line), false)
                    formatLineCount += 1
                }
            }
            let message = "Found \(formatLineCount) format line(s) — see Log tab for details"
            return (true, message)
        } else {
            let message = "Format check failed: \(result.errorText ?? "unknown error")"
            log("❌ \(message)", true)
            return (false, message)
        }
    }
}
