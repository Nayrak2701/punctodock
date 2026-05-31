import AppKit

/// Polls NSPasteboard.general every 0.75 s for new user-generated content.
/// Call suppress(for:) before any PunctoDock-internal clipboard write so those
/// changes are not recorded in the history.
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    var onNewText:  ((String) -> Void)?
    var onNewImage: ((Data, String) -> Void)?   // (imageData, pasteboardTypeRawValue)

    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var suppressUntil: Date = .distantPast

    private init() {}

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func suppress(for duration: TimeInterval = 1.0) {
        suppressUntil = Date().addingTimeInterval(duration)
    }

    private func poll() {
        let pb    = NSPasteboard.general
        let count = pb.changeCount
        defer { lastChangeCount = count }           // always track, even when suppressed
        guard count != lastChangeCount else { return }
        guard Date() >= suppressUntil  else { return }

        if let text = pb.string(forType: .string), !text.isEmpty {
            onNewText?(text)
            return
        }
        if let item = pb.pasteboardItems?.first {
            if let data = item.data(forType: .png) {
                onNewImage?(data, NSPasteboard.PasteboardType.png.rawValue)
                return
            }
            if let data = item.data(forType: .tiff) {
                onNewImage?(data, NSPasteboard.PasteboardType.tiff.rawValue)
                return
            }
        }
    }
}
