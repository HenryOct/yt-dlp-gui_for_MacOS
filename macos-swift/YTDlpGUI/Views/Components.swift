import SwiftUI

/// The three top-level destinations, shown in a native macOS sidebar
/// (`.listStyle(.sidebar)`) rather than the old `TabView`.
enum SidebarItem: String, CaseIterable, Identifiable {
    case download, advanced, log

    var id: String { rawValue }

    var title: String {
        switch self {
        case .download: return "Download"
        case .advanced: return "Advanced"
        case .log: return "Log"
        }
    }

    var systemImage: String {
        switch self {
        case .download: return "arrow.down.circle"
        case .advanced: return "slider.horizontal.3"
        case .log: return "doc.plaintext"
        }
    }
}

/// A grouped, inset card matching macOS System Settings: an uppercase
/// secondary-color label above a rounded, bordered container.
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            VStack(spacing: 0) { content }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5))
                )
        }
    }
}

/// One divided row inside a `SectionCard`, laid out as a native settings row.
struct SectionRow<Content: View>: View {
    var showDivider: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { content }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            if showDivider {
                Divider().padding(.leading, 14)
            }
        }
    }
}

/// Compact inline result indicator, used so outcomes (update result, format
/// check result) are visible directly in the Download tab instead of only
/// in the Log tab.
struct StatusBanner: View {
    let success: Bool
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(success ? Color.green : Color.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(success ? Color.primary : Color.red)
        }
    }
}
