import SwiftUI
import Combine
import LinkPresentation

struct MessageLinkPreviewData: Identifiable, Equatable {
    let id: String
    let url: URL
    let title: String
    let detail: String
}

struct ChatDriveAttachment: Equatable {
    enum StorageProvider: String, Equatable {
        case googleDrive = "Google Drive"
        case dropbox = "Dropbox"
        case unknown

        var title: String {
            switch self {
            case .googleDrive:
                return "Google Drive"
            case .dropbox:
                return "Dropbox"
            case .unknown:
                return "스토리지"
            }
        }

        var openButtonTitle: String {
            return "\(title)에서 열기"
        }
    }

    let fileName: String
    let folderTitle: String
    let mimeType: String?
    let fileID: String?
    let webViewURL: URL
    let storageProvider: StorageProvider
    let thumbnailDataURL: String?

    static func parse(from text: String) -> ChatDriveAttachment? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first,
              firstLine.hasPrefix("[파일 첨부]") else {
            return nil
        }

        var storageProvider: StorageProvider = .unknown
        let prefix = "[파일 첨부]"
        let suffix = String(firstLine.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        if suffix.contains("Dropbox") || suffix.contains("드롭박스") {
            storageProvider = .dropbox
        } else if suffix.contains("Google") || suffix.contains("구글") {
            storageProvider = .googleDrive
        }

        var fileName = String(firstLine.dropFirst("[파일 첨부]".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        var folderTitle = ""
        var mimeType: String?
        var fileID: String?
        var openURLString: String?
        var thumbnailDataURL: String?

        for line in lines.dropFirst() {
            if let value = value(after: "이름:", in: line) {
                fileName = value
            } else if let value = value(after: "분류:", in: line) {
                folderTitle = value
            } else if let value = value(after: "스토리지:", in: line) {
                if value.contains("Dropbox") {
                    storageProvider = .dropbox
                } else if value.contains("Google") || value.contains("구글") {
                    storageProvider = .googleDrive
                }
            } else if let value = value(after: "타입:", in: line) {
                mimeType = value
            } else if let value = value(after: "파일ID:", in: line) {
                fileID = value
            } else if let value = value(after: "썸네일:", in: line) {
                thumbnailDataURL = value
            } else if let value = value(after: "열기:", in: line) {
                openURLString = value
            }
        }

        if openURLString == nil {
            openURLString = firstStorageURLString(in: text)
        }

        guard let openURLString,
              let webViewURL = URL(string: openURLString),
              let host = webViewURL.host else {
            return nil
        }

        if storageProvider == .unknown {
            if host.contains("drive.google.com") || host.contains("docs.google.com") {
                storageProvider = .googleDrive
            } else if host.contains("dropbox.com") {
                storageProvider = .dropbox
            }
        }

        guard storageProvider != .unknown || host.contains("drive.google.com") || host.contains("docs.google.com") || host.contains("dropbox.com") else {
            return nil
        }

        if fileName.isEmpty {
            fileName = "파일 첨부"
        }

        if folderTitle.isEmpty {
            folderTitle = storageProvider.title
        }

        return ChatDriveAttachment(
            fileName: fileName,
            folderTitle: folderTitle,
            mimeType: mimeType,
            fileID: fileID,
            webViewURL: webViewURL,
            storageProvider: storageProvider,
            thumbnailDataURL: thumbnailDataURL
        )
    }

    var summaryText: String {
        "파일 첨부: \(fileName)"
    }

    var symbolName: String {
        let lowercasedName = fileName.lowercased()
        let lowercasedMime = mimeType?.lowercased() ?? ""

        if lowercasedMime.hasPrefix("image/") || hasAnySuffix(lowercasedName, [".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic"]) {
            return "photo"
        }
        if lowercasedMime.hasPrefix("video/") || hasAnySuffix(lowercasedName, [".mp4", ".mov", ".m4v", ".avi"]) {
            return "video"
        }
        if lowercasedMime.hasPrefix("audio/") || hasAnySuffix(lowercasedName, [".mp3", ".wav", ".m4a", ".aiff"]) {
            return "music.note"
        }
        if lowercasedMime.contains("pdf") || lowercasedName.hasSuffix(".pdf") {
            return "doc.richtext"
        }
        if lowercasedMime.contains("zip") || hasAnySuffix(lowercasedName, [".zip", ".rar", ".7z"]) {
            return "archivebox"
        }
        if lowercasedMime.contains("spreadsheet") || hasAnySuffix(lowercasedName, [".xls", ".xlsx", ".numbers", ".csv"]) {
            return "tablecells"
        }
        if lowercasedMime.contains("presentation") || hasAnySuffix(lowercasedName, [".ppt", ".pptx", ".key"]) {
            return "rectangle.on.rectangle"
        }
        return "doc"
    }

    var typeLabel: String {
        if let mimeType, !mimeType.isEmpty {
            return mimeType
        }
        let `extension` = URL(fileURLWithPath: fileName).pathExtension
        if !`extension`.isEmpty {
            return `extension`.uppercased()
        }
        return "파일"
    }

    var providerTitle: String {
        storageProvider.title
    }

    var openActionTitle: String {
        storageProvider.openButtonTitle
    }

    private static func value(after prefix: String, in line: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstStorageURLString(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        for match in matches {
            guard let matchRange = Range(match.range, in: text) else { continue }
            let candidate = String(text[matchRange])
            guard let url = URL(string: candidate),
                  let host = url.host,
                  (host.contains("drive.google.com") || host.contains("docs.google.com") || host.contains("dropbox.com")) else {
                continue
            }
            return candidate
        }

        return nil
    }

    private func hasAnySuffix(_ value: String, _ suffixes: [String]) -> Bool {
        suffixes.contains { value.hasSuffix($0) }
    }
}

struct ChatComposerTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    let onSubmit: () -> Void

    private let font = NSFont.systemFont(ofSize: 14, weight: .regular)
    private let minHeight: CGFloat = 18

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false

        let textView = ComposerNSTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isFieldEditor = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.focusRingType = .none
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.frame = NSRect(x: 0, y: 0, width: 100, height: minHeight)
        textView.autoresizingMask = [.width]
        textView.string = text
        textView.submitAction = onSubmit

        scrollView.documentView = textView
        context.coordinator.recalculateHeight(for: textView, in: scrollView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ComposerNSTextView else { return }

        textView.submitAction = onSubmit
        textView.isEditable = true
        textView.isSelectable = true

        if textView.string != text {
            textView.string = text
        }

        context.coordinator.parent = self
        context.coordinator.recalculateHeight(for: textView, in: scrollView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatComposerTextView

        init(_ parent: ChatComposerTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? ComposerNSTextView,
                  let scrollView = textView.enclosingScrollView else {
                return
            }

            parent.text = textView.string
            recalculateHeight(for: textView, in: scrollView)
        }

        func recalculateHeight(for textView: ComposerNSTextView, in scrollView: NSScrollView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return
            }

            layoutManager.ensureLayout(for: textContainer)

            let contentHeight = layoutManager.usedRect(for: textContainer).height
            let insetHeight = textView.textContainerInset.height * 2
            let requiredHeight = max(parent.minHeight, ceil(contentHeight + insetHeight))
            let maxHeight = ceil(parent.font.ascender - parent.font.descender + parent.font.leading) * 3 + insetHeight
            let clampedHeight = min(requiredHeight, maxHeight)

            if parent.measuredHeight != clampedHeight {
                DispatchQueue.main.async {
                    self.parent.measuredHeight = clampedHeight
                }
            }

            textView.isVerticallyResizable = requiredHeight <= maxHeight + 0.5
            scrollView.hasVerticalScroller = requiredHeight > maxHeight + 0.5
        }
    }
}

final class ComposerNSTextView: NSTextView {
    var submitAction: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isReturnKey = event.keyCode == 36 || event.keyCode == 76

        guard isReturnKey else {
            super.keyDown(with: event)
            return
        }

        if modifiers.contains(.shift) || modifiers.contains(.option) {
            insertNewline(nil)
            return
        }

        submitAction?()
    }
}

@MainActor
final class MessageLinkPreviewCache: ObservableObject {
    @Published private(set) var previews: [String: MessageLinkPreviewData] = [:]
    @Published private(set) var isLoading: Set<String> = []
    @Published private(set) var failures: [String: Bool] = [:]

    private let metadataProvider = LPMetadataProvider()
    private var inFlight: Set<String> = []

    static func makeKey(messageID: String, url: URL) -> String {
        "\(messageID)::\(url.absoluteString)"
    }

    func loadPreview(for messageID: String, url: URL) async {
        let key = Self.makeKey(messageID: messageID, url: url)

        if previews[key] != nil || inFlight.contains(key) {
            return
        }

        if let value = failures[key], value {
            return
        }

        inFlight.insert(key)
        isLoading.insert(key)
        defer {
            isLoading.remove(key)
            inFlight.remove(key)
        }

        do {
            let metadata = try await fetchMetadata(for: url)
            let title = metadata.title ?? url.host ?? url.absoluteString
            let detail = metadata.url?.absoluteString ?? url.absoluteString
            previews[key] = MessageLinkPreviewData(
                id: key,
                url: metadata.url ?? url,
                title: title,
                detail: detail
            )
            failures[key] = false
        } catch {
            failures[key] = true
        }
    }

    func reloadPreview(for messageID: String, url: URL) async {
        let key = Self.makeKey(messageID: messageID, url: url)
        previews[key] = nil
        failures[key] = nil
        inFlight.remove(key)
        await loadPreview(for: messageID, url: url)
    }

    private func fetchMetadata(for url: URL) async throws -> LPLinkMetadata {
        try await withCheckedThrowingContinuation { continuation in
            metadataProvider.startFetchingMetadata(for: url) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: NSError(domain: "LinkPreview", code: -1, userInfo: [NSLocalizedDescriptionKey: "No metadata returned."]))
                }
            }
        }
    }
}
