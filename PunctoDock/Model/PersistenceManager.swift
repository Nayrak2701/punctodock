import Foundation

/// Central, local-only persistence in
/// ~/Library/Application Support/com.punctodock.app/.
/// Two JSON files, both prefixed with the neutral bundle id. No network, no analytics.
final class PersistenceManager {
    static let shared = PersistenceManager()

    let storageDirectory: URL
    private let settingsURL: URL
    private let usageURL: URL
    private let clipboardURL: URL
    private let queue = DispatchQueue(label: "com.punctodock.persistence", qos: .utility)

    private init() {
        // Application Support in the user domain effectively always resolves, but fall
        // back to the temp directory rather than force-unwrapping so a misconfigured
        // environment degrades to a working (if non-persistent) session instead of a crash.
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        storageDirectory = base.appendingPathComponent("com.punctodock.app", isDirectory: true)
        settingsURL  = storageDirectory.appendingPathComponent("com.punctodock.settings.json")
        usageURL     = storageDirectory.appendingPathComponent("com.punctodock.usage.json")
        clipboardURL = storageDirectory.appendingPathComponent("com.punctodock.clipboard.json")
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    // MARK: Settings

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .default }
        return s
    }

    func saveSettings(_ settings: AppSettings) {
        queue.async { [settingsURL, storageDirectory] in
            guard let data = try? Self.encoder.encode(settings) else { return }
            Self.write(data, to: settingsURL, ensuringDirectory: storageDirectory)
        }
    }

    // MARK: Usage

    func loadUsage() -> UsageHistory {
        guard let data = try? Data(contentsOf: usageURL),
              let u = try? JSONDecoder().decode(UsageHistory.self, from: data)
        else { return UsageHistory() }
        return u
    }

    func saveUsage(_ usage: UsageHistory) {
        queue.async { [usageURL, storageDirectory] in
            guard let data = try? Self.encoder.encode(usage) else { return }
            Self.write(data, to: usageURL, ensuringDirectory: storageDirectory)
        }
    }

    // MARK: Clipboard

    func loadClipboard() -> ClipboardHistory {
        guard let data = try? Data(contentsOf: clipboardURL),
              let h = try? JSONDecoder().decode(ClipboardHistory.self, from: data)
        else { return ClipboardHistory() }
        return h
    }

    func saveClipboard(_ history: ClipboardHistory) {
        queue.async { [clipboardURL, storageDirectory] in
            guard let data = try? Self.encoder.encode(history) else { return }
            Self.write(data, to: clipboardURL, ensuringDirectory: storageDirectory)
        }
    }

    /// Re-ensures the storage directory exists, then writes atomically. The directory is
    /// created once at init, but a transiently-unwritable Application Support at launch —
    /// or the directory being removed mid-session — would otherwise make every later save
    /// fail silently for the whole session. createDirectory is a cheap no-op when the
    /// directory already exists, so this just lets persistence self-heal. Mirrors the
    /// guard ImageStore.write already applies to clipboard-image files.
    private static func write(_ data: Data, to url: URL, ensuringDirectory directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
