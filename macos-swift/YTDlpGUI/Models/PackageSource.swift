import Foundation

/// A pip package index choice offered during first-run setup. This is never
/// persisted or applied globally (no pip.conf edits, no environment
/// variables) — `pipIndexURL` is passed as a one-off `-i` flag only to the
/// specific `pip install` calls made during that installation.
enum PackageSource: String, CaseIterable, Identifiable {
    case `default`
    case tsinghua

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "默认源 (PyPI)"
        case .tsinghua: return "清华大学镜像源 (Tsinghua Mirror)"
        }
    }

    var detail: String {
        switch self {
        case .default: return "官方 PyPI 源"
        case .tsinghua: return "适合中国大陆网络环境，安装更快更稳定"
        }
    }

    /// Passed as `-i <url>` to `pip install` for this run only. `nil` means
    /// pip's own default index (PyPI) with no override at all.
    var pipIndexURL: String? {
        switch self {
        case .default: return nil
        case .tsinghua: return "https://pypi.tuna.tsinghua.edu.cn/simple"
        }
    }
}
