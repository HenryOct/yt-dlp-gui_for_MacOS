import Foundation

/// Result of a resolved yt-dlp invocation inside the app's own venv.
struct YtDlpInvocation {
    let pythonPath: String
    let baseCommand: [String]
}

/// Outcome of the fast startup check, before any installation happens.
enum SetupNeed {
    /// Already fully set up — no install needed, no onboarding UI required.
    case ready(YtDlpInvocation)
    /// No system Python 3 at all — we never attempt to install Python itself.
    case pythonMissing(String)
    /// Venv/yt-dlp missing or broken — an install is required. Carries the
    /// resolved system Python path to hand to `performInstall`.
    case needsInstall(systemPython: String)
}

/// One-click setup: finds system Python 3, creates a dedicated venv for this
/// app under Application Support if one doesn't already exist, and installs
/// yt-dlp into it. If system Python 3 itself is missing, this reports a
/// clear error and stops — it never attempts to install Python.
///
/// Split into `detectSetupNeed` (fast, silent — decides whether an install
/// is required at all) and `performInstall` (does the actual work) so the
/// UI can ask the user for a package-source preference only when an install
/// is actually about to happen, never on every ordinary launch.
///
/// All actual subprocess work runs inside `Task.detached` so the blocking
/// `Process.waitUntilExit()` calls never occur on the main actor — otherwise
/// venv creation and `pip install` would freeze the UI. Each `log(...)` call
/// happens only after hopping back to the main actor via `await`, since
/// `log` ultimately mutates an `@Published` `LogStore` and SwiftUI requires
/// that from the main thread.
@MainActor
final class DependencyManager: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var failureReason: String?
    @Published private(set) var ytDlpVersion: String?

    private static let pythonMissingReason = "未检测到 Python 3 / Python 3 not found\n\n请先安装 Python 3（例如通过 Homebrew: brew install python，或前往 python.org 下载），然后重新打开本应用。\nPlease install Python 3 first (e.g. via Homebrew: brew install python, or from python.org), then reopen this app."

    /// Fast, silent check: is everything already set up and working? Does
    /// not perform any installation — only decides whether one is needed.
    func detectSetupNeed(log: @escaping (String, Bool) -> Void) async -> SetupNeed {
        log("🖥️ System: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)", false)

        guard let systemPython = await Task.detached(priority: .userInitiated, operation: {
            PythonEnvironment.resolveSystemPython()
        }).value else {
            log("❌ \(Self.pythonMissingReason)", true)
            failureReason = Self.pythonMissingReason
            return .pythonMissing(Self.pythonMissingReason)
        }

        log("🐍 System Python: \(systemPython)", false)
        log("🏠 \(PythonEnvironment.describeEnvironment(pythonPath: systemPython))", false)

        let venvDir = PythonEnvironment.appManagedVenvDirectory()
        let venvPython = PythonEnvironment.venvPythonPath(venvDir)

        if FileManager.default.isExecutableFile(atPath: venvPython) {
            log("📦 Checking yt-dlp...", false)
            let command = PythonEnvironment.ytDlpCommand(venvDir: venvDir)
            if let version = await Self.runVersionCheck(command: command) {
                log("✅ yt-dlp installed: \(version)", false)
                isReady = true
                ytDlpVersion = version
                return .ready(YtDlpInvocation(pythonPath: venvPython, baseCommand: command))
            }
        }

        return .needsInstall(systemPython: systemPython)
    }

    /// Performs the actual venv creation + yt-dlp install. `source`'s
    /// package index is passed only as a one-off `-i` flag to the `pip
    /// install` calls below — it's never written to any config file or
    /// environment variable, so it has no effect beyond this installation.
    func performInstall(
        systemPython: String,
        source: PackageSource,
        log: @escaping (String, Bool) -> Void,
        onStatus: @escaping (String) -> Void
    ) async -> YtDlpInvocation? {
        let venvDir = PythonEnvironment.appManagedVenvDirectory()
        let venvPython = PythonEnvironment.venvPythonPath(venvDir)

        if !FileManager.default.isExecutableFile(atPath: venvPython) {
            onStatus("正在创建虚拟环境… / Creating virtual environment…")
            log("📦 Setting up a dedicated environment...", false)
            guard await Self.createVenv(systemPython: systemPython, venvDir: venvDir) else {
                let reason = "创建运行环境失败 / Failed to create the app's virtual environment.\n请确认 Python 3 安装完整（包含 venv 模块）。\nPlease make sure your Python 3 installation includes the venv module."
                log("❌ \(reason)", true)
                failureReason = reason
                return nil
            }
            log("✅ Environment created / 环境创建完成", false)
        }

        onStatus("正在检查 yt-dlp… / Checking yt-dlp…")
        log("📦 Checking yt-dlp...", false)
        var command = PythonEnvironment.ytDlpCommand(venvDir: venvDir)

        if let version = await Self.runVersionCheck(command: command) {
            log("✅ yt-dlp installed: \(version)", false)
            isReady = true
            ytDlpVersion = version
            return YtDlpInvocation(pythonPath: venvPython, baseCommand: command)
        }

        onStatus("正在安装 yt-dlp… / Installing yt-dlp…")
        log("❌ yt-dlp not found, installing...", false)
        guard await installYtDlp(venvPython: venvPython, source: source, log: log) else {
            let reason = "yt-dlp 自动安装失败 / yt-dlp auto-installation failed.\n可尝试重新打开应用重试，或在引导中切换安装源。\nTry reopening the app, or switch the package source in the setup screen."
            log("❌ \(reason)", true)
            failureReason = reason
            return nil
        }

        command = PythonEnvironment.ytDlpCommand(venvDir: venvDir)
        isReady = true
        ytDlpVersion = await Self.runVersionCheck(command: command)
        return YtDlpInvocation(pythonPath: venvPython, baseCommand: command)
    }

    /// Re-checks the installed version, e.g. after "Update yt-dlp" runs.
    func refreshVersion(invocation: YtDlpInvocation) async {
        ytDlpVersion = await Self.runVersionCheck(command: invocation.baseCommand)
    }

    private func installYtDlp(venvPython: String, source: PackageSource, log: @escaping (String, Bool) -> Void) async -> Bool {
        log("🔧 Installing yt-dlp...", false)
        if let url = source.pipIndexURL {
            log("🌐 Using package source for this install only: \(url)", false)
        }

        // Best-effort pip upgrade; a stale bundled pip can fail modern installs.
        _ = await Self.runPip(pythonPath: venvPython, args: ["install", "--upgrade", "pip"], indexURL: source.pipIndexURL)

        let (success, errorText) = await Self.runPip(pythonPath: venvPython, args: ["install", "yt-dlp"], indexURL: source.pipIndexURL)
        if success {
            log("✅ yt-dlp installed successfully", false)
            return true
        }

        log("❌ Command failed: \(venvPython) -m pip install yt-dlp", true)
        if let errorText, !errorText.isEmpty {
            log("Error output: \(errorText)", true)
        }
        return false
    }

    private static func createVenv(systemPython: String, venvDir: URL) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            try? FileManager.default.createDirectory(
                at: venvDir.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let process = Process()
            process.executableURL = URL(fileURLWithPath: systemPython)
            process.arguments = ["-m", "venv", venvDir.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    /// Runs `pythonPath -m pip <args>`, optionally with `-i <indexURL>`
    /// appended as a one-off flag on this single invocation only.
    private static func runPip(pythonPath: String, args: [String], indexURL: String?) async -> (success: Bool, errorText: String?) {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            var fullArgs = ["-m", "pip"] + args
            if let indexURL {
                fullArgs += ["-i", indexURL]
            }
            process.arguments = fullArgs
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
                return (false, String(data: errData, encoding: .utf8) ?? "")
            } catch {
                return (false, error.localizedDescription)
            }
        }.value
    }

    private static func runVersionCheck(command: [String]) async -> String? {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = command + ["--version"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return nil
            }
        }.value
    }
}
