import SwiftUI
import WebKit

enum NotionProjectSelectedLinkedItem: Identifiable {
    case task(NotionTaskItem)
    case document(NotionDocumentItem)
    case memo(NotionMemoItem)

    var id: String {
        switch self {
        case .task(let item):
            return item.id
        case .document(let item):
            return item.id
        case .memo(let item):
            return item.id
        }
    }

    var kind: NotionLinkedItemKind {
        switch self {
        case .task:
            return .task
        case .document:
            return .document
        case .memo:
            return .memo
        }
    }

    var title: String {
        switch self {
        case .task(let item):
            return item.title
        case .document(let item):
            return item.title
        case .memo(let item):
            return item.title
        }
    }

    var notionURL: URL? {
        switch self {
        case .task(let item):
            return item.notionURL
        case .document(let item):
            return item.notionURL
        case .memo(let item):
            return item.notionURL
        }
    }
}

struct NotionLinkedItemDetailSheet: View {
    let item: NotionProjectSelectedLinkedItem
    let service: any NotionHubService

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var webSessionManager = NotionWebSessionManager.shared

    @State private var webLoadFailed = false
    @State private var isShowingWebLoginSheet = false
    @State private var reloadToken = UUID()

    private let themeColor = Color(red: 0.10, green: 0.18, blue: 0.14)
    private let surfaceColor = Color(red: 0.96, green: 0.97, blue: 0.97)

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            contentArea
        }
        .frame(minWidth: 980, idealWidth: 1180, minHeight: 760, idealHeight: 900)
        .background(Color.white)
        .sheet(isPresented: $isShowingWebLoginSheet, onDismiss: {
            Task {
                await webSessionManager.refreshSessionStatus()
            }
        }) {
            NotionWebLoginSheet()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Text(sheetTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.8))

            Spacer()

            Button {
                webLoadFailed = false
                reloadToken = UUID()
            } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeColor)

            if let notionURL = item.notionURL {
                Link(destination: notionURL) {
                    Label("노션에서 열기", systemImage: "arrow.up.forward.square")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeColor)
            }

            Button {
                dismiss()
            } label: {
                Label("닫기", systemImage: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.black.opacity(0.65))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var sheetTitle: String {
        switch item.kind {
        case .task:
            return "To-do 상세"
        case .document:
            return "Document 상세"
        case .memo:
            return "Memo 상세"
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if let notionURL = item.notionURL {
            VStack(spacing: 0) {
                NotionPageWebView(url: notionURL, loadFailed: $webLoadFailed)
                    .id(reloadToken)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if webLoadFailed {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("웹뷰 로그인이 필요합니다.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.19))

                        Text("시스템 설정상 Google 버튼 로그인은 정상 진행되지 않을 수 있습니다. 이메일 입력 후 직접 로그인하거나 패스키 방식으로 진행해 주세요.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.black.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)

                        Button("웹뷰 로그인 열기") {
                            isShowingWebLoginSheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(themeColor)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(surfaceColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                    )
                    .padding(18)
                }
            }
        } else {
            VStack(spacing: 14) {
                Text("이 항목에 연결된 노션 페이지 URL이 없습니다.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.72))
                Button("닫기") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        }
    }

    private func htmlDocument(for blocks: [NotionLinkedContentBlock]) -> String {
        let body = blocks.enumerated().map { index, block in
            htmlFragment(for: block, index: index, blocks: blocks)
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="ko">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root {
              color-scheme: light;
              --text: #1f2328;
              --muted: #5f6670;
              --surface: #f5f7f7;
              --line: rgba(15, 23, 42, 0.08);
              --quote: rgba(15, 23, 42, 0.18);
              --accent: #193025;
            }
            * { box-sizing: border-box; }
            body {
              margin: 0;
              padding: 28px 30px 80px;
              font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
              color: var(--text);
              background: #ffffff;
              line-height: 1.68;
              font-size: 15px;
            }
            .block { margin: 0 0 10px 0; }
            .indent-1 { margin-left: 24px; }
            .indent-2 { margin-left: 48px; }
            .indent-3 { margin-left: 72px; }
            .indent-4 { margin-left: 96px; }
            .h1 { font-size: 2rem; font-weight: 800; margin: 12px 0 14px; }
            .h2 { font-size: 1.45rem; font-weight: 760; margin: 18px 0 12px; }
            .h3 { font-size: 1.12rem; font-weight: 700; margin: 16px 0 10px; }
            .row { display: flex; align-items: flex-start; gap: 10px; }
            .marker { width: 28px; flex: 0 0 28px; color: var(--muted); font-weight: 700; }
            .content { flex: 1; min-width: 0; }
            .quote {
              border-left: 3px solid var(--quote);
              padding-left: 14px;
              color: #3f4852;
            }
            .callout, .code {
              border-radius: 12px;
              padding: 12px 14px;
            }
            .callout { background: var(--surface); }
            .code {
              background: var(--surface);
              border: 1px solid var(--line);
              font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              white-space: pre-wrap;
            }
            .divider {
              height: 1px;
              background: var(--line);
              margin: 12px 0;
            }
            a { color: #2563eb; text-decoration: none; }
            strong { font-weight: 760; }
            em { font-style: italic; }
            code.inline {
              font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              background: rgba(15, 23, 42, 0.06);
              padding: 1px 5px;
              border-radius: 6px;
              font-size: 0.92em;
            }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private func htmlFragment(
        for block: NotionLinkedContentBlock,
        index: Int,
        blocks: [NotionLinkedContentBlock]
    ) -> String {
        let indentClass = "indent-\(min(block.depth, 4))"
        let text = richHTML(for: block.richText)
        let plainText = escapeHTML(block.text)

        switch block.style {
        case .heading1:
            return "<div class=\"block \(indentClass) h1\">\(text.isEmpty ? plainText : text)</div>"
        case .heading2:
            return "<div class=\"block \(indentClass) h2\">\(text.isEmpty ? plainText : text)</div>"
        case .heading3:
            return "<div class=\"block \(indentClass) h3\">\(text.isEmpty ? plainText : text)</div>"
        case .body, .note:
            return "<div class=\"block \(indentClass)\">\(text.isEmpty ? plainText : text)</div>"
        case .bullet:
            return rowHTML(marker: "•", content: text.isEmpty ? plainText : text, extraClass: indentClass)
        case .numbered:
            let number = orderedListIndex(for: index, in: blocks) ?? 1
            return rowHTML(marker: "\(number).", content: text.isEmpty ? plainText : text, extraClass: indentClass)
        case .todo:
            return rowHTML(marker: (block.isChecked ?? false) ? "☑" : "☐", content: text.isEmpty ? plainText : text, extraClass: indentClass)
        case .quote:
            return "<div class=\"block \(indentClass) quote\">\(text.isEmpty ? plainText : text)</div>"
        case .callout:
            let icon = escapeHTML(block.icon ?? "💡")
            return "<div class=\"block \(indentClass) callout\"><div class=\"row\"><div class=\"marker\">\(icon)</div><div class=\"content\">\(text.isEmpty ? plainText : text)</div></div></div>"
        case .code:
            return "<pre class=\"block \(indentClass) code\">\(plainText)</pre>"
        case .divider:
            return "<div class=\"divider\"></div>"
        case .image, .file:
            return "<div class=\"block \(indentClass)\">\(plainText)</div>"
        }
    }

    private func rowHTML(marker: String, content: String, extraClass: String) -> String {
        "<div class=\"block \(extraClass) row\"><div class=\"marker\">\(escapeHTML(marker))</div><div class=\"content\">\(content)</div></div>"
    }

    private func richHTML(for segments: [NotionRichTextSegment]) -> String {
        segments.map { segment in
            var html = escapeHTML(segment.text)

            if segment.annotations.code {
                html = "<code class=\"inline\">\(html)</code>"
            }
            if segment.annotations.bold {
                html = "<strong>\(html)</strong>"
            }
            if segment.annotations.italic {
                html = "<em>\(html)</em>"
            }
            if segment.annotations.strikethrough {
                html = "<s>\(html)</s>"
            }
            if segment.annotations.underline {
                html = "<u>\(html)</u>"
            }
            if let href = segment.href {
                html = "<a href=\"\(escapeHTML(href))\">\(html)</a>"
            }

            return html
        }
        .joined()
    }

    private func escapeHTML(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private func orderedListIndex(
        for index: Int,
        in blocks: [NotionLinkedContentBlock]
    ) -> Int? {
        guard blocks.indices.contains(index), blocks[index].style == .numbered else {
            return nil
        }

        let targetDepth = blocks[index].depth
        var number = 1

        guard index > 0 else { return number }

        for previousIndex in stride(from: index - 1, through: 0, by: -1) {
            let previous = blocks[previousIndex]
            guard previous.style == .numbered, previous.depth == targetDepth else {
                break
            }
            number += 1
        }

        return number
    }

    private func contentBlockView(
        _ block: NotionLinkedContentBlock,
        index: Int,
        blocks: [NotionLinkedContentBlock]
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if let prefix = prefix(for: block, index: index, in: blocks) {
                Text(prefix)
                    .font(prefixFont(for: block))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .frame(width: 24, alignment: .leading)
            } else if block.style == .callout {
                Text(block.icon ?? "💡")
                    .font(.system(size: 16))
                    .frame(width: 32, alignment: .leading)
            }

            NotionRichTextView(segments: block.richText, defaultFontSize: fontSize(for: block))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(block.depth) * 20)
        .padding(.vertical, block.style == .divider ? 4 : 2)
        .padding(block.style == .callout || block.style == .code ? 12 : 0)
        .background(
            ZStack {
                if block.style == .callout {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(notionBackgroundColor(for: block.color))
                } else if block.style == .code {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(surfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                }
            }
        )
        .overlay(
            HStack {
                if block.style == .quote {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 3)
                        .padding(.vertical, 2)
                    Spacer()
                }
            }
        )
        .padding(.leading, block.style == .quote ? 4 : 0)
        .overlay {
            if block.style == .divider {
                Divider()
                    .padding(.vertical, 8)
            }
        }
    }

    private func prefix(for block: NotionLinkedContentBlock, index: Int, in blocks: [NotionLinkedContentBlock]) -> String? {
        switch block.style {
        case .bullet:
            return "•"
        case .numbered:
            guard let order = orderedListIndex(for: index, in: blocks) else {
                return nil
            }
            return "\(order)."
        case .todo:
            return (block.isChecked ?? false) ? "☑" : "☐"
        case .quote:
            return "“"
        case .callout:
            return "!"
        case .code:
            return "</>"
        default:
            return nil
        }
    }

    private func notionBackgroundColor(for color: String?) -> Color {
        guard let color else {
            return Color.black.opacity(0.04)
        }

        switch color {
        case "gray_background":
            return Color.black.opacity(0.06)
        case "brown_background":
            return Color(hex: "F4EEEE")
        case "orange_background":
            return Color(hex: "FBEDEB")
        case "yellow_background":
            return Color(hex: "FBF3DB")
        case "green_background":
            return Color(hex: "EDF3EC")
        case "blue_background":
            return Color(hex: "E7F3F8")
        case "purple_background":
            return Color(hex: "F4F0F7")
        case "pink_background":
            return Color(hex: "F9EEF3")
        case "red_background":
            return Color(hex: "FDEBEC")
        default:
            return Color.black.opacity(0.04)
        }
    }

    private func fontSize(for block: NotionLinkedContentBlock) -> CGFloat {
        switch block.style {
        case .heading1:
            return 24
        case .heading2:
            return 19
        case .heading3:
            return 16
        case .code:
            return 13
        default:
            return 14
        }
    }

    private func prefixFont(for block: NotionLinkedContentBlock) -> Font {
        .system(size: 14, weight: .bold)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(themeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(themeColor.opacity(0.08))
            .clipShape(Capsule())
    }

}

struct NotionRichTextView: View {
    let segments: [NotionRichTextSegment]
    let defaultFontSize: CGFloat

    var body: some View {
        Text(attributedString)
    }

    private var attributedString: AttributedString {
        var combined = AttributedString("")

        for segment in segments {
            var attributedSegment = AttributedString(segment.text)

            let size = segment.annotations.code ? defaultFontSize - 1 : defaultFontSize
            let design: Font.Design = segment.annotations.code ? .monospaced : .default
            let weight: Font.Weight = segment.annotations.bold ? .bold : .regular

            var font = Font.system(size: size, weight: weight, design: design)
            if segment.annotations.italic {
                font = font.italic()
            }
            attributedSegment.font = font

            if segment.annotations.strikethrough {
                attributedSegment.strikethroughStyle = .single
            }
            if segment.annotations.underline {
                attributedSegment.underlineStyle = .single
            }

            if let colorString = segment.annotations.color {
                attributedSegment.foregroundColor = notionTextColor(for: colorString)
            } else {
                attributedSegment.foregroundColor = Color.black.opacity(0.78)
            }

            if let href = segment.href, let url = URL(string: href) {
                attributedSegment.link = url
                attributedSegment.underlineStyle = .single
            }

            combined.append(attributedSegment)
        }

        return combined
    }

    private func notionTextColor(for color: String) -> Color {
        switch color {
        case "gray":
            return Color.gray
        case "brown":
            return Color(hex: "976D57")
        case "orange":
            return Color.orange
        case "yellow":
            return Color(hex: "DFAB01")
        case "green":
            return Color(hex: "448361")
        case "blue":
            return Color.blue
        case "purple":
            return Color.purple
        case "pink":
            return Color(hex: "D15796")
        case "red":
            return Color.red
        default:
            return Color.black.opacity(0.78)
        }
    }
}

struct NotionPageWebView: NSViewRepresentable {
    let url: URL
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(loadFailed: $loadFailed)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(
            frame: .zero,
            configuration: NotionWebSessionManager.shared.makeConfiguration()
        )
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard nsView.url != url else { return }
        context.coordinator.loadFailed = false
        nsView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var loadFailed: Bool

        init(loadFailed: Binding<Bool>) {
            _loadFailed = loadFailed
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadFailed = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadFailed = true
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            loadFailed = true
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.targetFrame == nil,
               let requestURL = navigationAction.request.url {
                webView.load(URLRequest(url: requestURL))
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let requestURL = navigationAction.request.url else {
                return nil
            }

            webView.load(URLRequest(url: requestURL))
            return nil
        }

        func webViewDidClose(_ webView: WKWebView) {
            loadFailed = false
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            completionHandler()
        }
    }
}

struct NotionHTMLContentWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(
            frame: .zero,
            configuration: NotionWebSessionManager.shared.makeConfiguration()
        )
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(html, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: baseURL)
    }
}

struct LinkedItemTagLayout: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.62))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.96, green: 0.97, blue: 0.97))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
