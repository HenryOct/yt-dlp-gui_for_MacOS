import SwiftUI

/// Mirrors `init_log_panel` in yt_dlp_gui_wx.py: clear button, auto-scroll
/// toggle, and a read-only scrolling log. Styled as a dark console (like
/// Xcode's or Terminal's output), which reads as more "professional" than a
/// plain text view regardless of the app's own light/dark appearance.
struct LogView: View {
    @ObservedObject var logStore: LogStore
    @State private var autoScroll = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Log")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Toggle("Auto Scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                Button("Clear Log") { logStore.clear() }
                    .buttonStyle(.bordered)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logStore.lines) { line in
                            Text(line.text)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(line.isError ? Color(red: 1, green: 0.41, blue: 0.38) : Color.white.opacity(0.92))
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(red: 0.118, green: 0.118, blue: 0.118))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: logStore.lines.count) { _ in
                    guard autoScroll, let last = logStore.lines.last else { return }
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
