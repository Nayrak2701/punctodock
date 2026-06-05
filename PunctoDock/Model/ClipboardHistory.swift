import Foundation

// MARK: - ImageStore (private)

/// Manages the clipboard-images directory. Images are stored as individual files
/// so that binary data is never held in the in-memory ClipboardEntry structs.
private enum ImageStore {
    static var directory: URL {
        PersistenceManager.shared.storageDirectory
            .appendingPathComponent("clipboard-images", isDirectory: true)
    }

    static func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    // MARK: In-flight staging cache
    //
    // addImage inserts a ClipboardEntry synchronously but writes its bytes to disk on a
    // background queue. Without a bridge, a read that lands in that window — clicking a
    // just-copied image to paste it, or the thumbnail's load task — would miss and get
    // nil (a blank tile, or a silently dropped paste). We therefore keep the bytes in a
    // tiny in-memory cache from the moment addImage accepts them until their atomic disk
    // write succeeds, and have load() consult it first. Normally this holds 0–1 items;
    // `maxStaged` is only a backstop for the pathological case of stalled/failing writes.
    // All access is serialised with `lock` because load() runs on both the main thread
    // (paste / reveal) and background threads (the thumbnail's detached Task).
    private static let lock = NSLock()
    private static var staged: [String: Data] = [:]
    private static var stagedOrder: [String] = []
    private static let maxStaged = 8

    static func stage(_ data: Data, filename: String) {
        lock.lock(); defer { lock.unlock() }
        if staged[filename] == nil { stagedOrder.append(filename) }
        staged[filename] = data
        while stagedOrder.count > maxStaged {
            let oldest = stagedOrder.removeFirst()
            staged[oldest] = nil
        }
    }

    private static func unstage(_ filename: String) {
        lock.lock(); defer { lock.unlock() }
        guard staged.removeValue(forKey: filename) != nil else { return }
        stagedOrder.removeAll { $0 == filename }
    }

    static func write(_ data: Data, filename: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try data.write(to: url(for: filename), options: .atomic)
            unstage(filename)            // bytes safely on disk — release the in-memory copy
        } catch {
            // Keep the staged copy so in-session reads still succeed despite the failure.
        }
    }

    static func remove(_ filename: String) {
        unstage(filename)
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    static func load(_ filename: String) -> Data? {
        lock.lock()
        let cached = staged[filename]
        lock.unlock()
        if let cached { return cached }
        return try? Data(contentsOf: url(for: filename))
    }
}

// MARK: - ClipboardContentType

enum ClipboardContentType: String, Codable {
    case text, image
}

// MARK: - ClipboardEntry

struct ClipboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    var isPinned: Bool
    let contentType: ClipboardContentType
    let text: String?
    /// Filename inside ImageStore.directory. Never stored inline — loaded on demand.
    let imagePath: String?
    let imagePasteboardType: String?

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool { lhs.id == rhs.id }

    /// Reads image bytes from disk on demand. Call only when the data is immediately
    /// needed (e.g. for display or paste). Never called on hot paths.
    var imageData: Data? { imagePath.flatMap { ImageStore.load($0) } }

    /// On-disk URL of the stored image (a UUID `.bin` file inside the image store).
    /// Used to export / reveal the image; nil for text entries.
    var imageFileURL: URL? { imagePath.map { ImageStore.url(for: $0) } }

    // MARK: Custom Codable — migrates old inline imageData to disk on first decode

    private enum CodingKeys: String, CodingKey {
        case id, date, isPinned, contentType, text, imagePath, imagePasteboardType
        case legacyImageData = "imageData"   // field name used before the disk-based rewrite
    }

    init(id: UUID, date: Date, isPinned: Bool, contentType: ClipboardContentType,
         text: String?, imagePath: String?, imagePasteboardType: String?) {
        self.id = id; self.date = date; self.isPinned = isPinned
        self.contentType = contentType; self.text = text
        self.imagePath = imagePath; self.imagePasteboardType = imagePasteboardType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,                   forKey: .id)
        date            = try c.decode(Date.self,                   forKey: .date)
        isPinned        = try c.decode(Bool.self,                   forKey: .isPinned)
        contentType     = try c.decode(ClipboardContentType.self,   forKey: .contentType)
        text            = try c.decodeIfPresent(String.self,        forKey: .text)
        imagePasteboardType = try c.decodeIfPresent(String.self,    forKey: .imagePasteboardType)

        if let p = try c.decodeIfPresent(String.self, forKey: .imagePath) {
            imagePath = p
        } else if let data = try c.decodeIfPresent(Data.self, forKey: .legacyImageData) {
            // One-time migration: move inline data to a file on disk.
            let filename = UUID().uuidString + ".bin"
            ImageStore.write(data, filename: filename)
            imagePath = filename
        } else {
            imagePath = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                    forKey: .id)
        try c.encode(date,                  forKey: .date)
        try c.encode(isPinned,              forKey: .isPinned)
        try c.encode(contentType,           forKey: .contentType)
        try c.encodeIfPresent(text,                 forKey: .text)
        try c.encodeIfPresent(imagePath,            forKey: .imagePath)
        try c.encodeIfPresent(imagePasteboardType,  forKey: .imagePasteboardType)
        // legacyImageData intentionally omitted — always use imagePath going forward
    }
}

// MARK: - ClipboardHistory

struct ClipboardHistory: Codable {
    var entries: [ClipboardEntry] = []

    static let maxEntries      = 50
    static let maxImageEntries = 15   // images are decoded in-memory when the panel is open;
                                       // cap them separately to keep NSImage memory manageable
    static let maxBytes        = 10 * 1024 * 1024  // 10 MB per entry

    // MARK: Mutations

    mutating func addText(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count <= Self.maxBytes else { return }
        if let first = entries.first, first.contentType == .text, first.text == text { return }
        entries.insert(ClipboardEntry(id: UUID(), date: Date(), isPinned: false,
                                      contentType: .text, text: text,
                                      imagePath: nil, imagePasteboardType: nil), at: 0)
        trim()
    }

    mutating func addImage(_ data: Data, pasteboardType: String) {
        guard data.count <= Self.maxBytes else { return }
        let filename = UUID().uuidString + ".bin"
        entries.insert(ClipboardEntry(id: UUID(), date: Date(), isPinned: false,
                                      contentType: .image, text: nil,
                                      imagePath: filename, imagePasteboardType: pasteboardType), at: 0)
        trim()
        // Stage the bytes in memory synchronously so an immediate read (paste / thumbnail)
        // can never miss, then write to disk off the main thread. The staged copy is
        // released as soon as the disk write succeeds.
        ImageStore.stage(data, filename: filename)
        DispatchQueue.global(qos: .utility).async { ImageStore.write(data, filename: filename) }
    }

    mutating func togglePin(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].isPinned.toggle()
    }

    mutating func delete(_ id: UUID) {
        if let p = entries.first(where: { $0.id == id })?.imagePath {
            DispatchQueue.global(qos: .utility).async { ImageStore.remove(p) }
        }
        entries.removeAll { $0.id == id }
    }

    mutating func clearAll(keepPinned: Bool) {
        let toRemove = entries.filter { keepPinned ? !$0.isPinned : true }
        let paths = toRemove.compactMap(\.imagePath)
        if !paths.isEmpty {
            DispatchQueue.global(qos: .utility).async { paths.forEach { ImageStore.remove($0) } }
        }
        entries.removeAll { keepPinned ? !$0.isPinned : true }
    }

    // MARK: Internal trim

    private mutating func trim() {
        var pathsToDelete: [String] = []

        // 1. Total-entry cap.
        if entries.count > Self.maxEntries {
            var i = entries.count - 1
            var excess = entries.count - Self.maxEntries
            while excess > 0 && i >= 0 {
                if !entries[i].isPinned {
                    if let p = entries[i].imagePath { pathsToDelete.append(p) }
                    entries.remove(at: i)
                    excess -= 1
                }
                i -= 1
            }
        }

        // 2. Per-type image cap — prevents NSImage memory from growing unbounded when
        //    many screenshots / photos are copied during a long session.
        let imageCount = entries.filter { $0.contentType == .image && !$0.isPinned }.count
        if imageCount > Self.maxImageEntries {
            var excess = imageCount - Self.maxImageEntries
            var i = entries.count - 1
            while excess > 0 && i >= 0 {
                if entries[i].contentType == .image && !entries[i].isPinned {
                    if let p = entries[i].imagePath { pathsToDelete.append(p) }
                    entries.remove(at: i)
                    excess -= 1
                }
                i -= 1
            }
        }

        if !pathsToDelete.isEmpty {
            DispatchQueue.global(qos: .utility).async { pathsToDelete.forEach { ImageStore.remove($0) } }
        }
    }
}
