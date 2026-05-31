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
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
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
        queue.async { [settingsURL] in
            guard let data = try? Self.encoder.encode(settings) else { return }
            try? data.write(to: settingsURL, options: .atomic)
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
        queue.async { [usageURL] in
            guard let data = try? Self.encoder.encode(usage) else { return }
            try? data.write(to: usageURL, options: .atomic)
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
        queue.async { [clipboardURL] in
            guard let data = try? Self.encoder.encode(history) else { return }
            try? data.write(to: clipboardURL, options: .atomic)
        }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
