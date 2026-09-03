import Foundation

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

/// Replaces the queue+100ms-timer log pump in yt_dlp_gui_wx.py
/// (`log_queue` / `update_log_display`) with a plain @Published array —
/// SwiftUI re-renders on change without polling.
@MainActor
final class LogStore: ObservableObject {
    @Published private(set) var lines: [LogLine] = []

    func append(_ text: String, isError: Bool = false) {
        lines.append(LogLine(text: text, isError: isError))
    }

    func clear() {
        lines.removeAll()
    }
}
