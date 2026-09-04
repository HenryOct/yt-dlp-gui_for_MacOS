import SwiftUI

/// Mirrors `init_advanced_panel` in yt_dlp_gui_wx.py: proxy settings and
/// browser cookies. (The ignore-errors / geo-bypass toggles were removed —
/// testing showed they had no real effect.)
struct AdvancedSettingsView: View {
    @ObservedObject var options: DownloadOptions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Advanced")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.top, 2)

                SectionCard(title: "Proxy") {
                    SectionRow {
                        Image(systemName: "network")
                            .foregroundStyle(Color.accentColor)
                        Text("Enable Proxy")
                        Spacer()
                        Toggle("", isOn: $options.useProxy)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    SectionRow(showDivider: false) {
                        Text("Server")
                            .frame(width: 90, alignment: .leading)
                        Picker("", selection: $options.proxyType) {
                            ForEach(ProxyType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)

                        TextField("Host", text: $options.proxyHost)
                            .textFieldStyle(.roundedBorder)

                        Text(":")
                            .foregroundStyle(.secondary)

                        TextField("Port", text: $options.proxyPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 64)
                    }
                    .disabled(!options.useProxy)
                    .opacity(options.useProxy ? 1 : 0.5)
                }

                SectionCard(title: "Browser Cookies") {
                    SectionRow {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(Color.accentColor)
                        Text("Use Browser Cookies")
                        Spacer()
                        Toggle("", isOn: $options.useCookies)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    SectionRow(showDivider: false) {
                        Text("Browser")
                            .frame(width: 90, alignment: .leading)
                        Picker("", selection: $options.browser) {
                            ForEach(BrowserChoice.allCases) { browser in
                                Text(browser.rawValue).tag(browser)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                        Spacer()
                    }
                    .disabled(!options.useCookies)
                    .opacity(options.useCookies ? 1 : 0.5)
                }

                Text("Proxy and cookie settings apply only to this app's downloads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)

                Spacer()
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
