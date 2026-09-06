import SwiftUI

/// Drives the first-run setup UI shown while `DependencyManager` is still
/// deciding what's needed / actively installing. Once `stage` reaches
/// `.ready`, the caller stops showing this view entirely.
enum SetupStage {
    case checking
    case choosingSource
    case settingUp(status: String)
    case failed(String)
    case ready
}

/// A simple full-screen setup overlay. Shown only when an actual install is
/// required (a returning user whose environment already works never sees
/// this — `detectSetupNeed` skips straight to `.ready`). Asks once for a pip
/// package source before installing, purely for this run: see
/// `PackageSource.pipIndexURL`.
struct OnboardingView: View {
    let stage: SetupStage
    var onChooseSource: (PackageSource) -> Void
    var onRetry: () -> Void

    @State private var selectedSource: PackageSource = .default

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            Group {
                switch stage {
                case .checking:
                    checkingView
                case .choosingSource:
                    choosingSourceView
                case .settingUp(let status):
                    settingUpView(status: status)
                case .failed(let reason):
                    failedView(reason: reason)
                case .ready:
                    EmptyView()
                }
            }
            .padding(32)
        }
    }

    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在检测运行环境… / Checking environment…")
                .foregroundStyle(.secondary)
        }
    }

    private var choosingSourceView: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "shippingbox")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            Text("首次运行需要安装 yt-dlp\nFirst run needs to install yt-dlp")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("请选择软件包安装源，仅本次安装使用，不会修改任何系统全局设置\nChoose a package source — used only for this installation, no global changes")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(PackageSource.allCases) { source in
                    sourceRow(source)
                }
            }
            .padding(.vertical, 4)

            Button("继续 / Continue") {
                onChooseSource(selectedSource)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: 420)
    }

    private func settingUpView(status: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(status)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 380)
    }

    private func failedView(reason: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
            Text(reason)
                .multilineTextAlignment(.center)
            Button("重试 / Retry") { onRetry() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: 420)
    }

    private func sourceRow(_ source: PackageSource) -> some View {
        Button {
            selectedSource = source
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedSource == source ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selectedSource == source ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.displayName).fontWeight(.medium)
                    Text(source.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedSource == source ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selectedSource == source ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: selectedSource == source ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
