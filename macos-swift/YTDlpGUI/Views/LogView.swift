import SwiftUI

/// Mirrors `init_log_panel` in yt_dlp_gui_wx.py: clear button, auto-scroll
/// toggle, and a read-only scrolling log. SwiftUI's @Published array drives
/// updates directly, replacing the original's queue+timer poll.
struct LogView: View {
    @ObservedObject var logStore: LogStore
    @State private var autoScroll = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Clear Log") { logStore.clear() }
                Toggle("Auto Scroll", isOn: $autoScroll)
                Spacer()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logStore.lines) { line in
                            Text(line.text)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(line.isError ? .red : .primary)
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .border(Color(nsColor: .separatorColor))
                .onChange(of: logStore.lines.count) { _ in
                    guard autoScroll, let last = logStore.lines.last else { return }
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
