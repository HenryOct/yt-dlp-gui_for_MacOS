import Foundation

/// Preset video quality/format choices, mirroring `format_choices` in
/// yt_dlp_gui_wx.py. `formatCode` is what actually gets passed to `-f`.
enum FormatPreset: String, CaseIterable, Identifiable {
    case recommended
    case bestMp4
    case p1080
    case p720
    case worst
    case audioOnly
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recommended: return "bestvideo+bestaudio/best[ext=mp4] (Recommended - Most Stable)"
        case .bestMp4: return "best[ext=mp4] (Best Quality MP4)"
        case .p1080: return "best[height<=1080]+bestaudio/best[height<=1080][ext=mp4] (1080p)"
        case .p720: return "best[height<=720][ext=mp4] (720p - Space Saving)"
        case .worst: return "worst[ext=mp4] (Lowest Quality)"
        case .audioOnly: return "bestaudio (Audio Only)"
        case .custom: return "Custom Format"
        }
    }

    var formatCode: String? {
        switch self {
        case .recommended: return "bestvideo+bestaudio/best[ext=mp4]"
        case .bestMp4: return "best[ext=mp4]"
        case .p1080: return "best[height<=1080]+bestaudio/best[height<=1080][ext=mp4]"
        case .p720: return "best[height<=720][ext=mp4]"
        case .worst: return "worst[ext=mp4]"
        case .audioOnly: return "bestaudio"
        case .custom: return nil
        }
    }
}

enum ProxyType: String, CaseIterable, Identifiable {
    case http, https, socks5
    var id: String { rawValue }
}

enum BrowserChoice: String, CaseIterable, Identifiable {
    case chrome, firefox, safari, edge
    var id: String { rawValue }
}

/// All user-configurable download settings, mirroring the widgets across the
/// Basic/Advanced tabs of yt_dlp_gui_wx.py. `buildArguments` reproduces
/// `on_start_download`'s command construction exactly.
@MainActor
final class DownloadOptions: ObservableObject {
    @Published var url: String = ""
    @Published var savePath: String = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
    }()

    @Published var formatPreset: FormatPreset = .recommended
    @Published var customFormat: String = ""

    @Published var useProxy: Bool = false
    @Published var proxyType: ProxyType = .http
    @Published var proxyHost: String = "127.0.0.1"
    @Published var proxyPort: String = "7890"

    @Published var useCookies: Bool = false
    @Published var browser: BrowserChoice = .chrome

    /// Builds the yt-dlp argument list (excluding the base command / URL),
    /// matching `on_start_download` in yt_dlp_gui_wx.py line-for-line.
    func buildArguments() -> [String] {
        var args: [String] = ["--newline"]

        if formatPreset == .custom {
            let trimmed = customFormat.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                args += ["-f", trimmed]
            }
        } else if let code = formatPreset.formatCode {
            args += ["-f", code]
        }

        args += ["-o", "\(savePath)/%(title)s.%(ext)s"]

        if useProxy {
            let host = proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let port = proxyPort.trimmingCharacters(in: .whitespacesAndNewlines)
            args += ["--proxy", "\(proxyType.rawValue)://\(host):\(port)"]
        }

        if useCookies {
            args += ["--cookies-from-browser", browser.rawValue]
        }

        args += ["--js-runtimes", "node"]

        return args
    }

    var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
