import FirebaseFirestore
import Foundation

enum ProjectStoragePolicy {
    static let operatorEmail = "pd@studioleaf.kr"
    static let templateDocumentPath = "portalSettings/projectHubStorageTemplate"
    static let externalAccountsDocumentPath = "portalSettings/externalStorageAccounts"
}

enum ProjectArchiveLinkType: String, CaseIterable, Codable, Sendable {
    case notion
    case dropbox
    case googleDrive
    case teamMessenger
    case other

    var title: String {
        switch self {
        case .notion:
            return PortalFeatureNaming.notionConnector
        case .dropbox:
            return "Dropbox"
        case .googleDrive:
            return "Google Drive"
        case .teamMessenger:
            return PortalFeatureNaming.teamMessenger
        case .other:
            return "기타"
        }
    }

    var systemIcon: String {
        switch self {
        case .notion:
            return "books.vertical.fill"
        case .dropbox:
            return "shippingbox.fill"
        case .googleDrive:
            return "externaldrive.fill"
        case .teamMessenger:
            return "bubble.left.and.bubble.right.fill"
        case .other:
            return "link"
        }
    }
}

struct ProjectArchiveResourceLink: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var title: String
    var urlString: String
    var type: ProjectArchiveLinkType

    init(
        id: String = UUID().uuidString,
        title: String,
        urlString: String,
        type: ProjectArchiveLinkType
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.type = type
    }

    nonisolated init?(dictionary: [String: Any]) {
        let urlString = dictionary["url"] as? String ?? dictionary["urlString"] as? String ?? ""
        guard !urlString.isEmpty else {
            return nil
        }

        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.title = dictionary["title"] as? String ?? ""
        self.urlString = urlString
        self.type = ProjectArchiveLinkType(rawValue: dictionary["type"] as? String ?? "") ?? .other
    }

    static let empty = ProjectArchiveResourceLink(title: "", urlString: "", type: .other)

    var url: URL? {
        URL(string: urlString)
    }

    var payload: [String: Any] {
        [
            "id": id,
            "title": title,
            "url": urlString,
            "type": type.rawValue
        ]
    }
}

enum ProjectStorageProvider: String, CaseIterable, Codable, Sendable {
    case googleDrive
    case dropbox

    var title: String {
        switch self {
        case .googleDrive:
            return "Google Drive"
        case .dropbox:
            return "Dropbox"
        }
    }

    var systemIcon: String {
        switch self {
        case .googleDrive:
            return "externaldrive.fill"
        case .dropbox:
            return "shippingbox.fill"
        }
    }
}

enum ProjectUploadRenameMode: String, CaseIterable, Codable, Sendable {
    case keepOriginal
    case applyNamingRule

    var title: String {
        switch self {
        case .keepOriginal:
            return "원본 파일명 유지"
        case .applyNamingRule:
            return "규칙 기반 파일명 적용"
        }
    }
}

enum ProjectUploadVersionMode: String, CaseIterable, Codable, Sendable {
    case dateBased
    case sequenceBased

    var title: String {
        switch self {
        case .dateBased:
            return "Date Based"
        case .sequenceBased:
            return "Sequence Based"
        }
    }
}

enum ProjectUploadDateFormat: String, CaseIterable, Codable, Sendable {
    case mmdd
    case yymmdd

    var title: String {
        switch self {
        case .mmdd:
            return "MMDD"
        case .yymmdd:
            return "YYMMDD"
        }
    }
}

enum ProjectUploadPresetCategory: String, CaseIterable, Codable, Sendable {
    case edit
    case resource

    var title: String {
        switch self {
        case .edit:
            return "편집본"
        case .resource:
            return "자료"
        }
    }
}

enum ProjectUploadPreset: String, CaseIterable, Codable, Sendable {
    case assemblyCut = "AssemblyCut"
    case roughCut = "RoughCut"
    case fineCut = "FineCut"
    case masterCut = "MasterCut"
    case finalMaster = "FinalMaster"
    case brief = "Brief"
    case contextDocs = "ContextDocs"
    case references = "References"
    case assets = "Assets"

    var title: String { rawValue }

    var category: ProjectUploadPresetCategory {
        switch self {
        case .assemblyCut, .roughCut, .fineCut, .masterCut, .finalMaster:
            return .edit
        case .brief, .contextDocs, .references, .assets:
            return .resource
        }
    }

    static func defaults(for category: ProjectUploadPresetCategory) -> [ProjectUploadPreset] {
        allCases.filter { $0.category == category }
    }
}

struct ProjectUploadNamingDefaults: Equatable, Codable, Sendable {
    var renameMode: ProjectUploadRenameMode
    var versionMode: ProjectUploadVersionMode
    var dateFormat: ProjectUploadDateFormat

    init(
        renameMode: ProjectUploadRenameMode = .keepOriginal,
        versionMode: ProjectUploadVersionMode = .dateBased,
        dateFormat: ProjectUploadDateFormat = .mmdd
    ) {
        self.renameMode = renameMode
        self.versionMode = versionMode
        self.dateFormat = dateFormat
    }

    init(dictionary: [String: Any]) {
        self.init(
            renameMode: ProjectUploadRenameMode(rawValue: dictionary["renameMode"] as? String ?? "") ?? .keepOriginal,
            versionMode: ProjectUploadVersionMode(rawValue: dictionary["versionMode"] as? String ?? "") ?? .dateBased,
            dateFormat: ProjectUploadDateFormat(rawValue: dictionary["dateFormat"] as? String ?? "") ?? .mmdd
        )
    }

    var payload: [String: Any] {
        [
            "renameMode": renameMode.rawValue,
            "versionMode": versionMode.rawValue,
            "dateFormat": dateFormat.rawValue
        ]
    }
}

struct ProjectStorageFolder: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var title: String
    var provider: ProjectStorageProvider
    var relativePath: String
    var keywords: [String]
    var sortOrder: Int
    var isRequired: Bool

    init(
        id: String,
        title: String,
        provider: ProjectStorageProvider,
        relativePath: String,
        keywords: [String],
        sortOrder: Int,
        isRequired: Bool = true
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.relativePath = relativePath
        self.keywords = keywords
        self.sortOrder = sortOrder
        self.isRequired = isRequired
    }

    nonisolated init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let title = dictionary["title"] as? String,
              let provider = ProjectStorageProvider(rawValue: dictionary["provider"] as? String ?? ""),
              let relativePath = dictionary["relativePath"] as? String else {
            return nil
        }

        self.id = id
        self.title = title
        self.provider = provider
        self.relativePath = relativePath
        self.keywords = dictionary["keywords"] as? [String] ?? []
        self.sortOrder = dictionary["sortOrder"] as? Int ?? 0
        self.isRequired = dictionary["isRequired"] as? Bool ?? true
    }

    var payload: [String: Any] {
        [
            "id": id,
            "title": title,
            "provider": provider.rawValue,
            "relativePath": normalizedRelativePath,
            "keywords": keywords,
            "sortOrder": sortOrder,
            "isRequired": isRequired
        ]
    }

    var normalizedRelativePath: String {
        relativePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static let `default`: [ProjectStorageFolder] = [
        .init(
            id: "docs",
            title: "문서",
            provider: .googleDrive,
            relativePath: "docs",
            keywords: ["문서", "기획", "문안", "제안서"],
            sortOrder: 0
        ),
        .init(
            id: "references",
            title: "레퍼런스",
            provider: .googleDrive,
            relativePath: "references",
            keywords: ["레퍼런스", "자료", "참고"],
            sortOrder: 1
        ),
        .init(
            id: "schedule",
            title: "일정",
            provider: .googleDrive,
            relativePath: "schedule",
            keywords: ["일정", "스케줄", "캘린더"],
            sortOrder: 2
        ),
        .init(
            id: "meeting-notes",
            title: "회의록",
            provider: .googleDrive,
            relativePath: "meeting-notes",
            keywords: ["미팅", "회의", "회의록"],
            sortOrder: 3
        ),
        .init(
            id: "scripts",
            title: "스크립트",
            provider: .googleDrive,
            relativePath: "scripts",
            keywords: ["대본", "스크립트", "자막"],
            sortOrder: 4,
            isRequired: false
        ),
        .init(
            id: "admin",
            title: "관리 자료",
            provider: .googleDrive,
            relativePath: "admin",
            keywords: ["관리", "정산", "계약", "비용"],
            sortOrder: 5,
            isRequired: false
        ),
        .init(
            id: "footage",
            title: "원본 소스",
            provider: .dropbox,
            relativePath: "footage",
            keywords: ["원본", "소스", "촬영본"],
            sortOrder: 10
        ),
        .init(
            id: "graphics",
            title: "그래픽",
            provider: .dropbox,
            relativePath: "graphics",
            keywords: ["그래픽", "디자인", "소스"],
            sortOrder: 11
        ),
        .init(
            id: "renders",
            title: "렌더",
            provider: .dropbox,
            relativePath: "renders",
            keywords: ["렌더", "렌더본", "출력"],
            sortOrder: 12
        ),
        .init(
            id: "exports",
            title: "편집본",
            provider: .dropbox,
            relativePath: "exports",
            keywords: ["편집본", "시안", "작업본"],
            sortOrder: 13
        ),
        .init(
            id: "delivery",
            title: "납품본",
            provider: .dropbox,
            relativePath: "delivery",
            keywords: ["납품", "최종", "최종본"],
            sortOrder: 14
        ),
        .init(
            id: "review",
            title: "리뷰용",
            provider: .dropbox,
            relativePath: "review",
            keywords: ["리뷰", "검수", "컨펌"],
            sortOrder: 15,
            isRequired: false
        )
    ]
}

struct ProjectStorageTemplateDocument: Equatable, Sendable {
    var version: Int
    var folders: [ProjectStorageFolder]
    var updatedAt: Date
    var updatedByEmail: String
    var updatedByName: String

    init(
        version: Int = 1,
        folders: [ProjectStorageFolder] = ProjectStorageFolder.default,
        updatedAt: Date = .distantPast,
        updatedByEmail: String = "",
        updatedByName: String = ""
    ) {
        self.version = version
        self.folders = folders.sorted { $0.sortOrder < $1.sortOrder }
        self.updatedAt = updatedAt
        self.updatedByEmail = updatedByEmail
        self.updatedByName = updatedByName
    }

    init(dictionary: [String: Any]) {
        let foldersPayload = dictionary["folders"] as? [[String: Any]] ?? []
        let folders = foldersPayload.compactMap { ProjectStorageFolder(dictionary: $0) }
        self.init(
            version: dictionary["version"] as? Int ?? 1,
            folders: folders.isEmpty ? ProjectStorageFolder.default : folders,
            updatedAt: (dictionary["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast,
            updatedByEmail: dictionary["updatedByEmail"] as? String ?? "",
            updatedByName: dictionary["updatedByName"] as? String ?? ""
        )
    }

    static let `default` = ProjectStorageTemplateDocument()

    var payload: [String: Any] {
        [
            "version": version,
            "folders": folders.sorted { $0.sortOrder < $1.sortOrder }.map(\.payload),
            "updatedAt": FieldValue.serverTimestamp(),
            "updatedByEmail": updatedByEmail,
            "updatedByName": updatedByName
        ]
    }
}

enum ProjectStorageConnectionState: String, CaseIterable, Codable, Sendable {
    case notConfigured
    case pending
    case connected
    case needsReconnect

    var title: String {
        switch self {
        case .notConfigured:
            return "미설정"
        case .pending:
            return "준비 중"
        case .connected:
            return "연결됨"
        case .needsReconnect:
            return "재연결 필요"
        }
    }
}

struct ProjectStorageProviderAccountStatus: Equatable, Sendable {
    let provider: ProjectStorageProvider
    var executionEmail: String
    var accountLabel: String
    var connectionState: ProjectStorageConnectionState
    var notes: String
    var lastValidatedAt: Date?

    init(
        provider: ProjectStorageProvider,
        executionEmail: String = ProjectStoragePolicy.operatorEmail,
        accountLabel: String = "",
        connectionState: ProjectStorageConnectionState = .notConfigured,
        notes: String = "",
        lastValidatedAt: Date? = nil
    ) {
        self.provider = provider
        self.executionEmail = executionEmail
        self.accountLabel = accountLabel
        self.connectionState = connectionState
        self.notes = notes
        self.lastValidatedAt = lastValidatedAt
    }

    init(provider: ProjectStorageProvider, dictionary: [String: Any]) {
        self.init(
            provider: provider,
            executionEmail: dictionary["executionEmail"] as? String ?? ProjectStoragePolicy.operatorEmail,
            accountLabel: dictionary["accountLabel"] as? String ?? "",
            connectionState: ProjectStorageConnectionState(rawValue: dictionary["connectionState"] as? String ?? "") ?? .notConfigured,
            notes: dictionary["notes"] as? String ?? "",
            lastValidatedAt: (dictionary["lastValidatedAt"] as? Timestamp)?.dateValue()
        )
    }

    var payload: [String: Any] {
        var data: [String: Any] = [
            "executionEmail": executionEmail,
            "accountLabel": accountLabel,
            "connectionState": connectionState.rawValue,
            "notes": notes
        ]
        if let lastValidatedAt {
            data["lastValidatedAt"] = Timestamp(date: lastValidatedAt)
        }
        return data
    }
}

struct ProjectExternalStorageAccountsDocument: Equatable, Sendable {
    var googleDrive: ProjectStorageProviderAccountStatus
    var dropbox: ProjectStorageProviderAccountStatus
    var updatedAt: Date
    var updatedByEmail: String
    var updatedByName: String

    init(
        googleDrive: ProjectStorageProviderAccountStatus = .init(provider: .googleDrive),
        dropbox: ProjectStorageProviderAccountStatus = .init(provider: .dropbox),
        updatedAt: Date = .distantPast,
        updatedByEmail: String = "",
        updatedByName: String = ""
    ) {
        self.googleDrive = googleDrive
        self.dropbox = dropbox
        self.updatedAt = updatedAt
        self.updatedByEmail = updatedByEmail
        self.updatedByName = updatedByName
    }

    init(dictionary: [String: Any]) {
        self.init(
            googleDrive: ProjectStorageProviderAccountStatus(
                provider: .googleDrive,
                dictionary: dictionary["googleDrive"] as? [String: Any] ?? [:]
            ),
            dropbox: ProjectStorageProviderAccountStatus(
                provider: .dropbox,
                dictionary: dictionary["dropbox"] as? [String: Any] ?? [:]
            ),
            updatedAt: (dictionary["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast,
            updatedByEmail: dictionary["updatedByEmail"] as? String ?? "",
            updatedByName: dictionary["updatedByName"] as? String ?? ""
        )
    }

    static let `default` = ProjectExternalStorageAccountsDocument()

    var payload: [String: Any] {
        [
            "googleDrive": googleDrive.payload,
            "dropbox": dropbox.payload,
            "updatedAt": FieldValue.serverTimestamp(),
            "updatedByEmail": updatedByEmail,
            "updatedByName": updatedByName
        ]
    }
}

struct ProjectArchiveSummary: Identifiable, Equatable, Sendable {
    let id: String
    let projectName: String
    let projectSummary: String
    let projectCode: String
    let namingDefaults: ProjectUploadNamingDefaults
    let ownerID: String
    let ownerDisplayName: String
    let memberIDs: [String]
    let notionProjectID: String?
    let notionProjectTitle: String?
    let notionProjectURLString: String?
    let chatProjectID: String?
    let links: [ProjectArchiveResourceLink]
    let googleDriveRootFolderID: String?
    let googleDriveRootTitle: String?
    let googleDriveRootWebURLString: String?
    let dropboxRootPath: String?
    let dropboxRootTitle: String?
    let dropboxRootWebURLString: String?
    let storageTemplateVersion: Int
    let storageFolders: [ProjectStorageFolder]
    let savedWorkGroups: [String]
    let createdAt: Date
    let updatedAt: Date

    init?(
        id: String,
        dictionary: [String: Any]
    ) {
        guard let projectName = dictionary["name"] as? String else {
            return nil
        }

        let linkPayloads = dictionary["resourceLinks"] as? [[String: Any]] ?? []
        let folderPayloads = dictionary["storageFolders"] as? [[String: Any]] ?? []
        let storageFolders = folderPayloads.compactMap { ProjectStorageFolder(dictionary: $0) }
        let savedWorkGroups = (dictionary["savedWorkGroups"] as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        self.id = id
        self.projectName = projectName
        self.projectSummary = dictionary["summary"] as? String ?? ""
        self.projectCode = dictionary["projectCode"] as? String ?? ""
        self.namingDefaults = ProjectUploadNamingDefaults(dictionary: dictionary["uploadNamingDefaults"] as? [String: Any] ?? [:])
        self.ownerID = dictionary["ownerId"] as? String ?? ""
        self.ownerDisplayName = dictionary["ownerDisplayName"] as? String ?? ""
        self.memberIDs = dictionary["memberIds"] as? [String] ?? []
        self.notionProjectID = dictionary["notionProjectId"] as? String
        self.notionProjectTitle = dictionary["notionProjectTitle"] as? String
        self.notionProjectURLString = dictionary["notionProjectURL"] as? String
        self.chatProjectID = dictionary["chatProjectId"] as? String
        self.links = linkPayloads.compactMap { ProjectArchiveResourceLink(dictionary: $0) }
        self.googleDriveRootFolderID = dictionary["googleDriveRootFolderId"] as? String
        self.googleDriveRootTitle = dictionary["googleDriveRootTitle"] as? String
        self.googleDriveRootWebURLString = dictionary["googleDriveRootWebURL"] as? String
        self.dropboxRootPath = dictionary["dropboxRootPath"] as? String
        self.dropboxRootTitle = dictionary["dropboxRootTitle"] as? String
        self.dropboxRootWebURLString = dictionary["dropboxRootWebURL"] as? String
        self.storageTemplateVersion = dictionary["storageTemplateVersion"] as? Int ?? 1
        self.storageFolders = (storageFolders.isEmpty ? ProjectStorageFolder.default : storageFolders).sorted { $0.sortOrder < $1.sortOrder }
        self.savedWorkGroups = Array(Set(savedWorkGroups)).sorted()
        self.createdAt = (dictionary["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
        self.updatedAt = (dictionary["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
    }

    init?(document: QueryDocumentSnapshot) {
        self.init(id: document.documentID, dictionary: document.data())
    }

    var notionURL: URL? {
        guard let notionProjectURLString else { return nil }
        return URL(string: notionProjectURLString)
    }

    var googleDriveRootWebURL: URL? {
        guard let googleDriveRootWebURLString else { return nil }
        return URL(string: googleDriveRootWebURLString)
    }

    var dropboxRootWebURL: URL? {
        guard let dropboxRootWebURLString else { return nil }
        return URL(string: dropboxRootWebURLString)
    }

    func asDraft() -> ProjectArchiveDraft {
        ProjectArchiveDraft(
            id: id,
            projectName: projectName,
            projectSummary: projectSummary,
            projectCode: projectCode,
            namingDefaults: namingDefaults,
            notionProjectID: notionProjectID,
            notionProjectTitle: notionProjectTitle,
            notionProjectURL: notionProjectURLString,
            chatProjectID: chatProjectID,
            shouldCreateChatProject: false,
            links: links,
            googleDriveRootFolderID: googleDriveRootFolderID,
            googleDriveRootTitle: googleDriveRootTitle,
            googleDriveRootWebURL: googleDriveRootWebURLString,
            dropboxRootPath: dropboxRootPath,
            dropboxRootTitle: dropboxRootTitle,
            dropboxRootWebURL: dropboxRootWebURLString,
            storageTemplateVersion: storageTemplateVersion,
            storageFolders: storageFolders,
            savedWorkGroups: savedWorkGroups
        )
    }
}

struct ProjectArchiveDraft: Equatable, Sendable {
    var id: String?
    var projectName: String
    var projectSummary: String
    var projectCode: String
    var namingDefaults: ProjectUploadNamingDefaults
    var notionProjectID: String?
    var notionProjectTitle: String?
    var notionProjectURL: String?
    var chatProjectID: String?
    var shouldCreateChatProject: Bool
    var links: [ProjectArchiveResourceLink]
    var googleDriveRootFolderID: String?
    var googleDriveRootTitle: String?
    var googleDriveRootWebURL: String?
    var dropboxRootPath: String?
    var dropboxRootTitle: String?
    var dropboxRootWebURL: String?
    var storageTemplateVersion: Int
    var storageFolders: [ProjectStorageFolder]
    var savedWorkGroups: [String]

    static let empty = ProjectArchiveDraft(
        id: nil,
        projectName: "",
        projectSummary: "",
        projectCode: "",
        namingDefaults: ProjectUploadNamingDefaults(),
        notionProjectID: nil,
        notionProjectTitle: nil,
        notionProjectURL: nil,
        chatProjectID: nil,
        shouldCreateChatProject: false,
        links: [],
        googleDriveRootFolderID: nil,
        googleDriveRootTitle: nil,
        googleDriveRootWebURL: nil,
        dropboxRootPath: nil,
        dropboxRootTitle: nil,
        dropboxRootWebURL: nil,
        storageTemplateVersion: 1,
        storageFolders: ProjectStorageFolder.default,
        savedWorkGroups: []
    )

    var sortedStorageFolders: [ProjectStorageFolder] {
        storageFolders.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    mutating func applyTemplate(_ template: ProjectStorageTemplateDocument) {
        storageTemplateVersion = template.version
        storageFolders = template.folders.sorted { $0.sortOrder < $1.sortOrder }
    }
}

struct ProjectGoogleDriveItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let mimeType: String
    let webViewURLString: String?
    let sizeBytes: Int64?
    let modifiedAt: Date?
    let iconLink: String?

    init(
        id: String,
        name: String,
        mimeType: String,
        webViewURLString: String?,
        sizeBytes: Int64?,
        modifiedAt: Date?,
        iconLink: String?
    ) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.webViewURLString = webViewURLString
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
        self.iconLink = iconLink
    }

    nonisolated init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let mimeType = dictionary["mimeType"] as? String else {
            return nil
        }

        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.webViewURLString = dictionary["webViewLink"] as? String
        self.sizeBytes = dictionary["sizeBytes"] as? Int64
        self.iconLink = dictionary["iconLink"] as? String

        if let timestamp = dictionary["modifiedAt"] as? Timestamp {
            self.modifiedAt = timestamp.dateValue()
        } else if let seconds = dictionary["modifiedAtSeconds"] as? TimeInterval {
            self.modifiedAt = Date(timeIntervalSince1970: seconds)
        } else {
            self.modifiedAt = nil
        }
    }

    var isFolder: Bool {
        mimeType == "application/vnd.google-apps.folder"
    }

    var webViewURL: URL? {
        guard let webViewURLString else { return nil }
        return URL(string: webViewURLString)
    }
}

struct ProjectGoogleDriveFolderListing: Equatable, Sendable {
    let archiveID: String
    let folderID: String
    let folderTitle: String
    let relativePath: String
    let items: [ProjectGoogleDriveItem]

    init(
        archiveID: String,
        folderID: String,
        folderTitle: String,
        relativePath: String,
        items: [ProjectGoogleDriveItem]
    ) {
        self.archiveID = archiveID
        self.folderID = folderID
        self.folderTitle = folderTitle
        self.relativePath = relativePath
        self.items = items
    }

    init?(archiveID: String, relativePath: String, dictionary: [String: Any]) {
        guard let folderID = dictionary["folderId"] as? String,
              let folderTitle = dictionary["folderTitle"] as? String else {
            return nil
        }

        let itemsPayload = dictionary["items"] as? [[String: Any]] ?? []
        self.init(
            archiveID: archiveID,
            folderID: folderID,
            folderTitle: folderTitle,
            relativePath: relativePath,
            items: itemsPayload.compactMap(ProjectGoogleDriveItem.init(dictionary:))
        )
    }
}

struct ProjectGoogleDriveUploadResult: Equatable, Sendable {
    let fileID: String
    let fileName: String
    let webViewURLString: String
    let folderID: String
    let folderTitle: String
    let relativePath: String
    let mimeType: String
    let iconLink: String?
    let thumbnailLink: String?
    let size: Int64?
    let modifiedTime: Date?

    nonisolated init(
        fileID: String,
        fileName: String,
        webViewURLString: String,
        folderID: String,
        folderTitle: String,
        relativePath: String,
        mimeType: String,
        iconLink: String? = nil,
        thumbnailLink: String? = nil,
        size: Int64? = nil,
        modifiedTime: Date? = nil
    ) {
        self.fileID = fileID
        self.fileName = fileName
        self.webViewURLString = webViewURLString
        self.folderID = folderID
        self.folderTitle = folderTitle
        self.relativePath = relativePath
        self.mimeType = mimeType
        self.iconLink = iconLink
        self.thumbnailLink = thumbnailLink
        self.size = size
        self.modifiedTime = modifiedTime
    }

    nonisolated init?(dictionary: [String: Any]) {
        let fileID = dictionary["fileId"] as? String ?? dictionary["id"] as? String
        let fileName = dictionary["fileName"] as? String ?? dictionary["name"] as? String
        let webViewURLString = dictionary["webViewLink"] as? String
        let folderID = dictionary["folderId"] as? String
        let folderTitle = dictionary["folderTitle"] as? String
        let relativePath = dictionary["relativePath"] as? String
        let mimeType = dictionary["mimeType"] as? String
        let iconLink = dictionary["iconLink"] as? String
        let thumbnailLink = dictionary["thumbnailLink"] as? String

        let size: Int64?
        if let sizeValue = dictionary["size"] as? Int64 {
            size = sizeValue
        } else if let sizeValue = dictionary["size"] as? Double {
            size = Int64(sizeValue)
        } else if let sizeValue = dictionary["size"] as? String {
            size = Int64(sizeValue)
        } else if let sizeValue = dictionary["size"] as? NSNumber {
            size = sizeValue.int64Value
        } else {
            size = nil
        }

        let modifiedTime: Date?
        if let modifiedAtString = dictionary["modifiedTime"] as? String {
            if let withFraction = Self.makeGoogleDriveModifiedDateFormatterWithFractional().date(from: modifiedAtString) {
                modifiedTime = withFraction
            } else {
                modifiedTime = Self.makeGoogleDriveModifiedDateFormatterWithoutFractional().date(from: modifiedAtString)
            }
        } else {
            modifiedTime = nil
        }

        guard let fileID,
              let fileName,
              let webViewURLString,
              let folderID,
              let folderTitle,
              let relativePath,
              let mimeType else {
            return nil
        }

        self.init(
            fileID: fileID,
            fileName: fileName,
            webViewURLString: webViewURLString,
            folderID: folderID,
            folderTitle: folderTitle,
            relativePath: relativePath,
            mimeType: mimeType,
            iconLink: iconLink,
            thumbnailLink: thumbnailLink,
            size: size,
            modifiedTime: modifiedTime
        )
    }

    var webViewURL: URL? {
        URL(string: webViewURLString)
    }

    nonisolated private static func makeGoogleDriveModifiedDateFormatterWithFractional() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    nonisolated private static func makeGoogleDriveModifiedDateFormatterWithoutFractional() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}

struct ProjectGoogleDriveUploadSession: Equatable, Sendable {
    let uploadURLString: String
    let folderID: String
    let folderTitle: String
    let relativePath: String

    nonisolated init(
        uploadURLString: String,
        folderID: String,
        folderTitle: String,
        relativePath: String
    ) {
        self.uploadURLString = uploadURLString
        self.folderID = folderID
        self.folderTitle = folderTitle
        self.relativePath = relativePath
    }

    nonisolated init?(dictionary: [String: Any]) {
        guard let uploadURLString = dictionary["uploadUrl"] as? String,
              let folderID = dictionary["folderId"] as? String,
              let folderTitle = dictionary["folderTitle"] as? String,
              let relativePath = dictionary["relativePath"] as? String else {
            return nil
        }

        self.init(
            uploadURLString: uploadURLString,
            folderID: folderID,
            folderTitle: folderTitle,
            relativePath: relativePath
        )
    }

    var uploadURL: URL? {
        URL(string: uploadURLString)
    }
}

struct ProjectDropboxUploadSession: Equatable, Sendable {
    let accessToken: String
    let uploadPath: String
    let folderPath: String
    let folderTitle: String
    let relativePath: String
    let webViewLink: String
    let pathRootHeader: String?

    nonisolated init(
        accessToken: String,
        uploadPath: String,
        folderPath: String,
        folderTitle: String,
        relativePath: String,
        webViewLink: String,
        pathRootHeader: String? = nil
    ) {
        self.accessToken = accessToken
        self.uploadPath = uploadPath
        self.folderPath = folderPath
        self.folderTitle = folderTitle
        self.relativePath = relativePath
        self.webViewLink = webViewLink
        self.pathRootHeader = pathRootHeader
    }

    nonisolated init?(dictionary: [String: Any]) {
        guard let accessToken = dictionary["accessToken"] as? String,
              let uploadPath = dictionary["uploadPath"] as? String,
              let folderPath = dictionary["folderPath"] as? String,
              let folderTitle = dictionary["folderTitle"] as? String,
              let relativePath = dictionary["relativePath"] as? String,
              let webViewLink = dictionary["webViewLink"] as? String else {
            return nil
        }

        self.init(
            accessToken: accessToken,
            uploadPath: uploadPath,
            folderPath: folderPath,
            folderTitle: folderTitle,
            relativePath: relativePath,
            webViewLink: webViewLink,
            pathRootHeader: dictionary["pathRootHeader"] as? String
        )
    }
}

struct ProjectDropboxUploadResult: Equatable, Sendable {
    let fileID: String
    let fileName: String
    let webViewURLString: String
    let folderPath: String
    let folderTitle: String
    let relativePath: String
    let mimeType: String
    let size: Int64?
    let modifiedTime: Date?

    nonisolated init(
        fileID: String,
        fileName: String,
        webViewURLString: String,
        folderPath: String,
        folderTitle: String,
        relativePath: String,
        mimeType: String,
        size: Int64?,
        modifiedTime: Date?
    ) {
        self.fileID = fileID
        self.fileName = fileName
        self.webViewURLString = webViewURLString
        self.folderPath = folderPath
        self.folderTitle = folderTitle
        self.relativePath = relativePath
        self.mimeType = mimeType
        self.size = size
        self.modifiedTime = modifiedTime
    }

    nonisolated init?(dictionary: [String: Any]) {
        guard let fileID = dictionary["id"] as? String ?? dictionary["fileId"] as? String,
              let fileName = dictionary["name"] as? String,
              let webViewURLString = dictionary["webViewLink"] as? String,
              let folderPath = dictionary["folderPath"] as? String,
              let folderTitle = dictionary["folderTitle"] as? String,
              let relativePath = dictionary["relativePath"] as? String,
              let mimeType = dictionary["mimeType"] as? String else {
            return nil
        }

        let size: Int64?
        if let sizeValue = dictionary["size"] as? Int64 {
            size = sizeValue
        } else if let sizeValue = dictionary["size"] as? Double {
            size = Int64(sizeValue)
        } else if let sizeValue = dictionary["size"] as? String {
            size = Int64(sizeValue)
        } else if let sizeValue = dictionary["size"] as? NSNumber {
            size = sizeValue.int64Value
        } else {
            size = nil
        }

        let modifiedTime: Date?
        if let modifiedAtString = dictionary["modifiedTime"] as? String {
            let formatter = ISO8601DateFormatter()
            modifiedTime = formatter.date(from: modifiedAtString)
        } else {
            modifiedTime = nil
        }

        self.init(
            fileID: fileID,
            fileName: fileName,
            webViewURLString: webViewURLString,
            folderPath: folderPath,
            folderTitle: folderTitle,
            relativePath: relativePath,
            mimeType: mimeType,
            size: size,
            modifiedTime: modifiedTime
        )
    }

    var webViewURL: URL? {
        URL(string: webViewURLString)
    }
}

struct ProjectDropboxItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isFolder: Bool
    let pathDisplay: String
    let pathLower: String
    let webViewURLString: String?
    let sizeBytes: Int64?
    let modifiedAt: Date?

    init(
        id: String,
        name: String,
        isFolder: Bool,
        pathDisplay: String,
        pathLower: String,
        webViewURLString: String?,
        sizeBytes: Int64?,
        modifiedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.isFolder = isFolder
        self.pathDisplay = pathDisplay
        self.pathLower = pathLower
        self.webViewURLString = webViewURLString
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
    }

    nonisolated init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let pathDisplay = dictionary["pathDisplay"] as? String,
              let pathLower = dictionary["pathLower"] as? String else {
            return nil
        }

        self.id = id
        self.name = name
        self.pathDisplay = pathDisplay
        self.pathLower = pathLower
        self.webViewURLString = dictionary["webViewLink"] as? String
        self.sizeBytes = Self.parseDropboxSizeBytes(from: dictionary["sizeBytes"])

        let folder = dictionary["isFolder"] as? Bool ?? false
        self.isFolder = folder

        if let modifiedAt = dictionary["modifiedAt"] as? String {
            self.modifiedAt = Self.makeDropboxModifiedDateFormatter().date(from: modifiedAt)
        } else if let modifiedDate = dictionary["modifiedAt"] as? Date {
            self.modifiedAt = modifiedDate
        } else {
            self.modifiedAt = nil
        }
    }

    nonisolated private static func parseDropboxSizeBytes(from value: Any?) -> Int64? {
        if let value {
            if let numeric = value as? Int64 {
                return numeric
            }
            if let numeric = value as? Int {
                return Int64(numeric)
            }
            if let numeric = value as? Double {
                return Int64(numeric)
            }
            if let numeric = value as? NSNumber {
                return numeric.int64Value
            }
            if let raw = value as? String, let numeric = Int64(raw) {
                return numeric
            }
        }
        return nil
    }

    var webViewURL: URL? {
        guard let webViewURLString else { return nil }
        return URL(string: webViewURLString)
    }

    nonisolated private static func makeDropboxModifiedDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}

struct ProjectDropboxFolderListing: Equatable, Sendable {
    let archiveID: String
    let folderPath: String
    let folderTitle: String
    let relativePath: String
    let items: [ProjectDropboxItem]

    init(
        archiveID: String,
        folderPath: String,
        folderTitle: String,
        relativePath: String,
        items: [ProjectDropboxItem]
    ) {
        self.archiveID = archiveID
        self.folderPath = folderPath
        self.folderTitle = folderTitle
        self.relativePath = relativePath
        self.items = items
    }

    init?(archiveID: String, relativePath: String, dictionary: [String: Any]) {
        guard let folderPath = dictionary["folderPath"] as? String,
              let folderTitle = dictionary["folderTitle"] as? String else {
            return nil
        }

        let itemsPayload = dictionary["items"] as? [[String: Any]] ?? []
        self.init(
            archiveID: archiveID,
            folderPath: folderPath,
            folderTitle: folderTitle,
            relativePath: relativePath,
            items: itemsPayload.compactMap(ProjectDropboxItem.init(dictionary:))
        )
    }
}
