import SwiftUI

@main
struct YTDlpGUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 800)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About yt-dlp GUI") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        NSApplication.AboutPanelOptionKey.applicationName: "yt-dlp GUI",
                        NSApplication.AboutPanelOptionKey.applicationVersion: "2.0 (SwiftUI Version)",
                        NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                            string: "A simple and easy-to-use YouTube downloader with graphical interface\nBuilt with SwiftUI, native to macOS"
                        )
                    ])
                }
            }
        }
    }
}
