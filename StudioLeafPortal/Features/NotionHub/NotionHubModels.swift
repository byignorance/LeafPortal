import Foundation

enum NotionProjectViewMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case statusBoard = "진행상태별 보기"
    case ownerBoard = "프로젝트 오너별"

    var id: String { rawValue }
}

struct NotionPersonChip: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    let email: String?
    let photoURL: String?

    nonisolated init(id: String? = nil, name: String, email: String? = nil, photoURL: String? = nil) {
        self.id = id ?? name
        self.name = name
        self.email = email
        self.photoURL = photoURL
    }

    var initials: String {
        let source = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = source.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        if !letters.isEmpty {
            return letters.uppercased()
        }
        return String(source.prefix(1)).uppercased()
    }
}

struct NotionProjectSummary: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let title: String
    let emoji: String?
    let status: String
    let owners: [NotionPersonChip]
    let participants: [NotionPersonChip]
    let dueDate: Date?
    let clientTags: [String]
    let summary: String
    let currentSituation: String
    let notionURL: URL?
    let linkedPreview: NotionProjectLinkedPreview
}

struct NotionProjectLinkedPreview: Hashable, Sendable, Codable {
    let todos: [NotionTaskItem]
    let documents: [NotionDocumentItem]
    let memos: [NotionMemoItem]

    static let empty = NotionProjectLinkedPreview(
        todos: [],
        documents: [],
        memos: []
    )
}

struct NotionTaskItem: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let title: String
    let emoji: String?
    let status: String
    let assignees: [NotionPersonChip]
    let dueDate: Date?
    let startDate: Date?
    let dDayText: String
    let notionURL: URL?
}

struct NotionDocumentItem: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let title: String
    let emoji: String?
    let status: String
    let author: [NotionPersonChip]
    let categoryTags: [String]
    let date: Date?
    let dueDate: Date?
    let priority: String
    let summary: String
    let notionURL: URL?
}

struct NotionMemoItem: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let title: String
    let emoji: String?
    let status: String
    let date: Date?
    let dueDate: Date?
    let categoryTags: [String]
    let priority: String
    let summary: String
    let isExternallyShared: Bool
    let notionURL: URL?
}

struct NotionProjectDetail: Hashable, Sendable, Codable {
    let project: NotionProjectSummary
    let todos: [NotionTaskItem]
    let documents: [NotionDocumentItem]
    let memos: [NotionMemoItem]
}

struct NotionMetadataRow: Hashable, Sendable, Codable {
    let title: String
    let value: String
}

enum NotionLinkedItemKind: String, Hashable, Sendable, Codable {
    case task
    case document
    case memo
}

struct NotionLinkedContentBlock: Identifiable, Hashable, Sendable, Codable {
    enum Style: String, Hashable, Sendable, Codable {
        case heading1
        case heading2
        case heading3
        case body
        case bullet
        case numbered
        case todo
        case quote
        case callout
        case code
        case note
        case divider
        case image
        case file
    }

    let id: String
    let style: Style
    let text: String // Fallback plain text
    let richText: [NotionRichTextSegment]
    let depth: Int
    let isChecked: Bool?
    let color: String?
    let icon: String? // For callouts
}

struct NotionRichTextSegment: Hashable, Sendable, Codable {
    let text: String
    let href: String?
    let annotations: Annotations

    struct Annotations: Hashable, Sendable, Codable {
        let bold: Bool
        let italic: Bool
        let strikethrough: Bool
        let underline: Bool
        let code: Bool
        let color: String?
    }
}

struct NotionLinkedItemDetail: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let kind: NotionLinkedItemKind
    let title: String
    let emoji: String?
    let status: String
    let summary: String
    let secondaryBadge: String?
    let notionURL: URL?
    let tags: [String]
    let metadataRows: [NotionMetadataRow]
    let contentBlocks: [NotionLinkedContentBlock]
}

struct NotionProjectGroup: Identifiable, Hashable, Sendable, Codable {
    let title: String
    let subtitle: String
    let projects: [NotionProjectSummary]

    var id: String { title }
}
