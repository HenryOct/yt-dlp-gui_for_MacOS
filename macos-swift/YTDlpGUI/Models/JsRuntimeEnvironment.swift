import Foundation

/// Resolves and (best-effort) installs the JavaScript runtime yt-dlp needs to
/// solve JS challenges on sites like YouTube (see
/// https://github.com/yt-dlp/yt-dlp/wiki/EJS). yt-dlp shells out to `deno` or
/// `node` on PATH at download time — neither ships via pip, so this is
/// handled entirely outside the Python venv.
///
/// Strategy, in order:
/// 1. Already on PATH (Homebrew, system install, or our own managed copy) → done.
/// 2. Homebrew present → `brew install deno` (fast, user's existing package manager).
/// 3. No Homebrew → download Deno's official prebuilt binary directly from its
///    GitHub release into this app's own Application Support directory. No
///    admin rights, no system-wide change.
/// 4. If all of that fails, this is treated as a soft failure: yt-dlp itself
///    still works for the (large) majority of sites that don't need a JS
///    challenge solver, so setup continues rather than blocking the app.
enum JsRuntimeEnvironment {
    /// Official Deno release download page, surfaced to the user as a manual
    /// fallback if automatic install fails entirely.
    static let manualDownloadURL = "https://github.com/yt-dlp/yt-dlp/wiki/EJS"

    private static let candidateDenoPaths = [
        "/opt/homebrew/bin/deno",
        "/usr/local/bin/deno"
    ]
    private static let candidateNodePaths = [
        "/opt/homebrew/bin/node",
        "/usr/local/bin/node"
    ]
    private static let candidateBrewPaths = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]

    /// This app's own managed copy of Deno, used only when Homebrew isn't
    /// available: `~/Library/Application Support/<bundle id>/tools/deno`.
    static func appManagedToolsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let bundleID = Bundle.main.bundleIdentifier ?? "com.henrywan.ytdlpgui.YTDlpGUI"
        return base.appendingPathComponent(bundleID, isDirectory: true).appendingPathComponent("tools", isDirectory: true)
    }

    static func appManagedDenoPath() -> String {
        appManagedToolsDirectory().appendingPathComponent("deno").path
    }

    static func resolveBrew() -> String? {
        for path in candidateBrewPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return PythonEnvironment.which("brew")
    }

    /// Any JS runtime already usable — Homebrew/system-installed, or our own
    /// managed copy. Does not attempt installation.
    static func resolveExistingRuntime() -> String? {
        for path in candidateDenoPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        if FileManager.default.isExecutableFile(atPath: appManagedDenoPath()) {
            return appManagedDenoPath()
        }
        for path in candidateNodePaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        if let deno = PythonEnvironment.which("deno") { return deno }
        if let node = PythonEnvironment.which("node") { return node }
        return nil
    }

    /// Extra directories to prepend to subprocess PATH so `env`-launched
    /// yt-dlp can find Homebrew and/or our app-managed tools at download
    /// time — GUI apps don't inherit the user's shell PATH.
    static func extraPathDirectories() -> [String] {
        var dirs = ["/opt/homebrew/bin", "/usr/local/bin"]
        dirs.append(appManagedToolsDirectory().path)
        return dirs
    }

    /// Builds the environment dictionary to hand to a `Process`, with
    /// Homebrew/app-managed tool directories prepended to PATH.
    static func subprocessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let extra = extraPathDirectories().filter { !existingPath.contains($0) }
        env["PATH"] = (extra + [existingPath]).joined(separator: ":")
        return env
    }

    enum InstallOutcome {
        case alreadyPresent(path: String)
        case installed(path: String)
        /// Non-fatal: yt-dlp still works for sites that don't need a JS
        /// challenge solver. `reason` is shown to the user as a warning.
        case skipped(reason: String)
    }

    /// Ensures a JS runtime is available, installing one if needed. Never
    /// throws / never blocks overall app setup — worst case returns
    /// `.skipped` with an explanation.
    static func ensureRuntime(log: @escaping (String, Bool) -> Void) async -> InstallOutcome {
        if let existing = resolveExistingRuntime() {
            log("✅ JS runtime found: \(existing)", false)
            return .alreadyPresent(path: existing)
        }

        log("📦 No JavaScript runtime (Deno/Node.js) found — yt-dlp needs one to solve JS challenges on sites like YouTube.", false)

        if let brew = resolveBrew() {
            log("🍺 Homebrew detected, installing Deno via Homebrew...", false)
            if await installViaHomebrew(brew: brew, log: log) {
                for path in candidateDenoPaths where FileManager.default.isExecutableFile(atPath: path) {
                    log("✅ Deno installed: \(path)", false)
                    return .installed(path: path)
                }
            }
            log("⚠️ Homebrew install of Deno failed, falling back to direct download...", true)
        }

        log("⬇️ Downloading Deno directly from GitHub releases (no Homebrew needed)...", false)
        if let installed = await installViaDirectDownload(log: log) {
            log("✅ Deno installed: \(installed)", false)
            return .installed(path: installed)
        }

        let reason = "未能自动安装 JavaScript 运行时（Deno/Node.js）/ Could not automatically install a JavaScript runtime (Deno/Node.js).\n" +
            "部分网站（如 YouTube）可能因此下载失败。可手动安装后重启本应用：\n" +
            "Some sites (e.g. YouTube) may fail to download without one. You can install one manually, then restart this app:\n" +
            manualDownloadURL
        log("⚠️ \(reason)", true)
        return .skipped(reason: reason)
    }

    private static func installViaHomebrew(brew: String, log: @escaping (String, Bool) -> Void) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = ["install", "deno"]
            process.standardOutput = FileHandle.nullDevice
            let errPipe = Pipe()
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    /// Downloads Deno's official prebuilt binary zip for this Mac's
    /// architecture straight from its GitHub release and unzips it into our
    /// app-managed tools directory. This is the officially published release
    /// asset (same one `curl -fsSL https://deno.land/install.sh` fetches),
    /// just without needing a package manager.
    private static func installViaDirectDownload(log: @escaping (String, Bool) -> Void) async -> String? {
        let arch = machineArchitecture()
        let assetName = arch == "arm64" ? "deno-aarch64-apple-darwin.zip" : "deno-x86_64-apple-darwin.zip"
        guard let url = URL(string: "https://github.com/denoland/deno/releases/latest/download/\(assetName)") else {
            return nil
        }

        let toolsDir = appManagedToolsDirectory()
        let destPath = appManagedDenoPath()

        return await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: toolsDir, withIntermediateDirectories: true)

                let (tempFileURL, response) = try await URLSession.shared.download(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    return nil
                }

                let zipPath = toolsDir.appendingPathComponent("deno-download.zip")
                try? FileManager.default.removeItem(at: zipPath)
                try FileManager.default.moveItem(at: tempFileURL, to: zipPath)

                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzip.arguments = ["-o", zipPath.path, "-d", toolsDir.path]
                unzip.standardOutput = FileHandle.nullDevice
                unzip.standardError = FileHandle.nullDevice
                try unzip.run()
                unzip.waitUntilExit()
                try? FileManager.default.removeItem(at: zipPath)

                guard unzip.terminationStatus == 0, FileManager.default.fileExists(atPath: destPath) else {
                    return nil
                }
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
                return destPath
            } catch {
                return nil
            }
        }.value
    }

    private static func machineArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }
}
