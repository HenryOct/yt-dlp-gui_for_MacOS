import SwiftUI

/// Mirrors `init_advanced_panel` in yt_dlp_gui_wx.py: proxy settings and
/// browser cookies. (The ignore-errors / geo-bypass toggles were removed —
/// testing showed they had no real effect.)
struct AdvancedSettingsView: View {
    @ObservedObject var options: DownloadOptions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Proxy Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Proxy", isOn: $options.useProxy)

                        HStack {
                            Text("Type:")
                            Picker("", selection: $options.proxyType) {
                                ForEach(ProxyType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)

                            Text("Host:")
                            TextField("", text: $options.proxyHost)
                                .textFieldStyle(.roundedBorder)

                            Text("Port:")
                            TextField("", text: $options.proxyPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        .disabled(!options.useProxy)
                    }
                    .padding(8)
                }

                GroupBox("Browser Cookies") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use Browser Cookies", isOn: $options.useCookies)

                        HStack {
                            Text("Browser:")
                            Picker("", selection: $options.browser) {
                                ForEach(BrowserChoice.allCases) { browser in
                                    Text(browser.rawValue).tag(browser)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        .disabled(!options.useCookies)
                    }
                    .padding(8)
                }

                Spacer()
            }
            .padding()
        }
    }
}
