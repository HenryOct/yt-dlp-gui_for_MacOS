import Foundation

/// Resolves system Python 3 and manages a dedicated, app-owned virtual
/// environment (in Application Support) where yt-dlp is installed. This
/// keeps the app self-contained: it never touches the user's system-wide
/// Python site-packages, and the whole setup — venv creation + `pip install
/// yt-dlp` — happens automatically on first launch. If no system Python 3 is
/// found at all, we report that clearly rather than attempting to install
/// Python itself.
enum PythonEnvironment {

    /// Candidate `python3` executables to probe, in priority order.
    private static let candidateSystemPythonPaths = [
        "/opt/homebrew/bin/python3",
        "/usr/local/bin/python3",
        "/usr/bin/python3"
    ]

    /// Finds a usable system `python3` executable, or nil if none exists.
    /// Does not attempt to install Python — the caller should surface a
    /// clear error and stop if this returns nil.
    static func resolveSystemPython() -> String? {
        for path in candidateSystemPythonPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // Fall back to whatever `python3` resolves to on PATH.
        return which("python3")
    }

    /// Describes the kind of Python installation found, for the log/system-info banner.
    static func describeEnvironment(pythonPath: String) -> String {
        if pythonPath.lowercased().contains("conda") {
            return "Anaconda/Miniconda"
        }
        if pythonPath.contains("/opt/homebrew") {
            return "Homebrew (Apple Silicon)"
        }
        if pythonPath.contains("/usr/local") {
            return "Homebrew (Intel)"
        }
        return "System Python"
    }

    /// The directory for this app's dedicated virtual environment:
    /// `~/Library/Application Support/<bundle id>/venv`.
    static func appManagedVenvDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let bundleID = Bundle.main.bundleIdentifier ?? "com.henrywan.ytdlpgui.YTDlpGUI"
        return base.appendingPathComponent(bundleID, isDirectory: true).appendingPathComponent("venv", isDirectory: true)
    }

    static func venvPythonPath(_ venvDir: URL) -> String {
        venvDir.appendingPathComponent("bin/python3").path
    }

    static func venvYtDlpExecutablePath(_ venvDir: URL) -> String {
        venvDir.appendingPathComponent("bin/yt-dlp").path
    }

    /// Returns the base command array used to invoke yt-dlp inside the app's
    /// venv: the `yt-dlp` console-script if present, else the module form.
    static func ytDlpCommand(venvDir: URL) -> [String] {
        let executable = venvYtDlpExecutablePath(venvDir)
        if FileManager.default.isExecutableFile(atPath: executable) {
            return [executable]
        }
        return [venvPythonPath(venvDir), "-m", "yt_dlp"]
    }

    static func which(_ executable: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [executable]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty ?? true) ? nil : path
        } catch {
            return nil
        }
    }
}
