import SwiftUI

/// Top-level container: shows a first-run `OnboardingView` while setup is
/// pending, then the main sidebar interface (Download / Advanced / Log,
/// styled after macOS System Settings / Finder) once ready.
struct ContentView: View {
    @StateObject private var options = DownloadOptions()
    @StateObject private var logStore = LogStore()
    @StateObject private var dependencyManager = DependencyManager()
    @StateObject private var downloadRunner = DownloadRunner()

    @State private var invocation: YtDlpInvocation?
    @State private var progressText = "Ready"
    @State private var progressFraction: Double? = nil // nil = indeterminate pulse

    @State private var setupStage: SetupStage = .checking
    @State private var pendingSystemPython: String = ""

    @State private var selection: SidebarItem? = .download

    var body: some View {
        ZStack {
            mainSplit
                .opacity(isReady ? 1 : 0)
                .disabled(!isReady)

            if !isReady {
                OnboardingView(
                    stage: setupStage,
                    onChooseSource: { source in
                        Task { await performInstall(source: source) }
                    },
                    onRetry: {
                        Task { await runInitialCheck() }
                    }
                )
            }
        }
        .task {
            await runInitialCheck()
        }
    }

    private var mainSplit: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selection ?? .download {
                case .download:
                    BasicSettingsView(
                        options: options,
                        logStore: logStore,
                        downloadRunner: downloadRunner,
                        dependencyManager: dependencyManager,
                        invocation: invocation,
                        progressText: $progressText,
                        progressFraction: $progressFraction
                    )
                case .advanced:
                    AdvancedSettingsView(options: options)
                case .log:
                    LogView(logStore: logStore)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var isReady: Bool {
        if case .ready = setupStage { return true }
        return false
    }

    private func runInitialCheck() async {
        setupStage = .checking
        let need = await dependencyManager.detectSetupNeed { text, isError in
            logStore.append(text, isError: isError)
        }
        switch need {
        case .ready(let resolved):
            invocation = resolved
            setupStage = .ready
        case .pythonMissing(let reason):
            setupStage = .failed(reason)
        case .needsInstall(let systemPython):
            pendingSystemPython = systemPython
            setupStage = .choosingSource
        }
    }

    private func performInstall(source: PackageSource) async {
        setupStage = .settingUp(status: "正在准备… / Preparing…")
        let resolved = await dependencyManager.performInstall(
            systemPython: pendingSystemPython,
            source: source,
            log: { text, isError in logStore.append(text, isError: isError) },
            onStatus: { status in setupStage = .settingUp(status: status) }
        )
        if let resolved {
            invocation = resolved
            setupStage = .ready
        } else {
            setupStage = .failed(dependencyManager.failureReason ?? "未知错误 / Unknown error")
        }
    }
}

#Preview {
    ContentView()
}
