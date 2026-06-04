import AppKit
import UniformTypeIdentifiers

/// Polls NSPasteboard.general every 0.75 s for new user-generated content.
/// Call suppress(for:) before any PunctoDock-internal clipboard write so those
/// changes are not recorded in the history.
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    var onNewText:  ((String) -> Void)?
    var onNewImage: ((Data, String) -> Void)?   // (imageData, pasteboardTypeRawValue)

    /// Image representations we recognise on the pasteboard, richest / most portable
    /// first. macOS usually synthesises `.tiff` for any image, so the first two catch
    /// almost everything; the rest cover apps that publish only one specific format.
    private static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png, .tiff, .pdf,
        NSPasteboard.PasteboardType(UTType.jpeg.identifier),
        NSPasteboard.PasteboardType(UTType.gif.identifier),
        NSPasteboard.PasteboardType(UTType.heic.identifier),
        NSPasteboard.PasteboardType(UTType.heif.identifier),
        NSPasteboard.PasteboardType(UTType.bmp.identifier),
        NSPasteboard.PasteboardType(UTType.webP.identifier)
    ]

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

        // Plain text wins when present (covers copied text and most rich text).
        if let text = pb.string(forType: .string), !text.isEmpty {
            onNewText?(text)
            return
        }

        // Inline image data placed on the pasteboard, in order of preference.
        if let item = pb.pasteboardItems?.first {
            for type in Self.imageTypes {
                if let data = item.data(forType: type) {
                    onNewImage?(data, type.rawValue)
                    return
                }
            }
        }

        // An image FILE copied in Finder arrives as a file URL — load its bytes so it
        // can be re-pasted as an image into other apps. Non-image files are ignored;
        // oversized files are dropped downstream by ClipboardHistory's size cap.
        if let (data, type) = imageFromFileURL(on: pb) {
            onNewImage?(data, type.rawValue)
        }
    }

    /// If the pasteboard holds a single image file reference, returns its bytes and the
    /// pasteboard type matching the file's format.
    private func imageFromFileURL(on pb: NSPasteboard) -> (Data, NSPasteboard.PasteboardType)? {
        guard let urls = pb.readObjects(forClasses: [NSURL.self],
                                        options: [.urlReadingFileURLsOnly: true]) as? [URL],
              let url = urls.first,
              let utType = UTType(filenameExtension: url.pathExtension),
              utType.conforms(to: .image),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return (data, NSPasteboard.PasteboardType(utType.identifier))
    }
}
