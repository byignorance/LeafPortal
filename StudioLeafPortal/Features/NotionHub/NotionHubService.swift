import Foundation

protocol NotionHubService: Sendable {
    func fetchProjects(forceRefresh: Bool) async throws -> [NotionProjectSummary]
    func fetchProjectDetail(projectID: String, forceRefresh: Bool) async throws -> NotionProjectDetail
    func fetchLinkedItemDetail(itemID: String, kind: NotionLinkedItemKind, forceRefresh: Bool) async throws -> NotionLinkedItemDetail
}

enum NotionHubServiceError: LocalizedError {
    case projectNotFound
    case projectExcluded
    case configurationMissing(String)
    case networkFailure(String)
    case invalidResponse
    case apiFailure(String)

    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "선택한 프로젝트를 찾지 못했습니다."
        case .projectExcluded:
            return "완료 영역에 있는 프로젝트는 \(PortalFeatureNaming.notionConnector)에서 숨김 처리됩니다."
        case .configurationMissing(let message):
            return message
        case .networkFailure(let message):
            return message
        case .invalidResponse:
            return "노션 응답을 해석하지 못했습니다."
        case .apiFailure(let message):
            return message
        }
    }
}

struct NotionHubUnavailableService: NotionHubService {
    let message: String

    func fetchProjects(forceRefresh: Bool) async throws -> [NotionProjectSummary] {
        throw NotionHubServiceError.configurationMissing(message)
    }

    func fetchProjectDetail(projectID: String, forceRefresh: Bool) async throws -> NotionProjectDetail {
        throw NotionHubServiceError.configurationMissing(message)
    }

    func fetchLinkedItemDetail(itemID: String, kind: NotionLinkedItemKind, forceRefresh: Bool) async throws -> NotionLinkedItemDetail {
        throw NotionHubServiceError.configurationMissing(message)
    }
}

@MainActor
final class NotionHubMockService: NotionHubService {
    func fetchProjects(forceRefresh: Bool) async throws -> [NotionProjectSummary] {
        try await Task.sleep(for: .milliseconds(180))
        return await MainActor.run { NotionHubMocks.projects }
    }

    func fetchProjectDetail(projectID: String, forceRefresh: Bool) async throws -> NotionProjectDetail {
        try await Task.sleep(for: .milliseconds(120))

        return try await MainActor.run {
            guard let detail = NotionHubMocks.details[projectID] else {
                throw NotionHubServiceError.projectNotFound
            }
            return detail
        }
    }

    func fetchLinkedItemDetail(itemID: String, kind: NotionLinkedItemKind, forceRefresh: Bool) async throws -> NotionLinkedItemDetail {
        try await Task.sleep(for: .milliseconds(100))

        let title = mockTitle(for: itemID, kind: kind)
        return NotionLinkedItemDetail(
            id: itemID,
            kind: kind,
            title: title,
            emoji: mockEmoji(for: itemID, kind: kind),
            status: mockStatus(for: itemID, kind: kind),
            summary: "Mock 상세 본문과 속성입니다.",
            secondaryBadge: mockSecondaryBadge(for: itemID, kind: kind),
            notionURL: URL(string: "https://www.notion.so/example/\(itemID)"),
            tags: mockTags(for: itemID, kind: kind),
            metadataRows: mockMetadata(for: itemID, kind: kind),
            contentBlocks: [
                NotionLinkedContentBlock(
                    id: "\(itemID)-callout",
                    style: .callout,
                    text: "본 인터뷰 질문지는 스페이스 점프 팀의 사업 내용 파악을 위한 문서입니다.",
                    richText: [
                        .init(text: "본 인터뷰 질문지", href: nil, annotations: .init(bold: true, italic: false, strikethrough: false, underline: false, code: false, color: nil)),
                        .init(text: "는 스페이스 점프 팀의 사업 내용 파악을 위한 문서입니다.", href: nil, annotations: .init(bold: false, italic: false, strikethrough: false, underline: false, code: false, color: nil))
                    ],
                    depth: 0,
                    isChecked: nil,
                        color: "gray_background",
                    icon: "💡"
                ),
                NotionLinkedContentBlock(
                    id: "\(itemID)-h2",
                    style: .heading2,
                    text: "🎥 예상 촬영 스케줄",
                    richText: [.init(text: "🎥 예상 촬영 스케줄", href: nil, annotations: .init(bold: true, italic: false, strikethrough: false, underline: false, code: false, color: nil))],
                    depth: 0,
                    isChecked: nil,
                    color: nil,
                    icon: nil
                ),
                NotionLinkedContentBlock(
                    id: "\(itemID)-bullet-1",
                    style: .bullet,
                    text: "09:00 - 09:15 | 인터뷰 세팅",
                    richText: [.init(text: "09:00 - 09:15 | 인터뷰 세팅", href: nil, annotations: .init(bold: false, italic: false, strikethrough: false, underline: false, code: false, color: "blue"))],
                    depth: 0,
                    isChecked: nil,
                    color: nil,
                    icon: nil
                ),
                NotionLinkedContentBlock(
                    id: "\(itemID)-bullet-2",
                    style: .bullet,
                    text: "09:15 - 09:40 | 스페이스 점프 대표 인터뷰",
                    richText: [
                        .init(text: "09:15 - 09:40 | ", href: nil, annotations: .init(bold: false, italic: false, strikethrough: false, underline: false, code: false, color: nil)),
                        .init(text: "스페이스 점프", href: nil, annotations: .init(bold: true, italic: false, strikethrough: false, underline: false, code: false, color: "red")),
                        .init(text: " 대표 인터뷰", href: nil, annotations: .init(bold: false, italic: false, strikethrough: false, underline: false, code: false, color: nil))
                    ],
                    depth: 0,
                    isChecked: nil,
                    color: nil,
                    icon: nil
                ),
                NotionLinkedContentBlock(
                    id: "\(itemID)-divider",
                    style: .divider,
                    text: "",
                    richText: [],
                    depth: 0,
                    isChecked: nil,
                    color: nil,
                    icon: nil
                ),
                NotionLinkedContentBlock(
                    id: "\(itemID)-code",
                    style: .code,
                    text: "// Note: 촬영 시 조명 체크 필요",
                    richText: [.init(text: "// Note: 촬영 시 조명 체크 필요", href: nil, annotations: .init(bold: false, italic: false, strikethrough: false, underline: false, code: true, color: "gray"))],
                    depth: 0,
                    isChecked: nil,
                    color: nil,
                    icon: nil
                )
            ]
        )
    }

    private func mockEmoji(for itemID: String, kind: NotionLinkedItemKind) -> String? {
        switch kind {
        case .task: return "✅"
        case .document: return "📄"
        case .memo: return "📝"
        }
    }

    private func mockTitle(for itemID: String, kind: NotionLinkedItemKind) -> String {
        switch kind {
        case .task:
            return NotionHubMocks.details.values.flatMap(\.todos).first(where: { $0.id == itemID })?.title ?? "Mock To-do"
        case .document:
            return NotionHubMocks.details.values.flatMap(\.documents).first(where: { $0.id == itemID })?.title ?? "Mock Document"
        case .memo:
            return NotionHubMocks.details.values.flatMap(\.memos).first(where: { $0.id == itemID })?.title ?? "Mock Memo"
        }
    }

    private func mockStatus(for itemID: String, kind: NotionLinkedItemKind) -> String {
        switch kind {
        case .task:
            return NotionHubMocks.details.values.flatMap(\.todos).first(where: { $0.id == itemID })?.status ?? "Open"
        case .document:
            return NotionHubMocks.details.values.flatMap(\.documents).first(where: { $0.id == itemID })?.status ?? "Open"
        case .memo:
            return NotionHubMocks.details.values.flatMap(\.memos).first(where: { $0.id == itemID })?.status ?? "Open"
        }
    }

    private func mockSecondaryBadge(for itemID: String, kind: NotionLinkedItemKind) -> String? {
        switch kind {
        case .task:
            return NotionHubMocks.details.values.flatMap(\.todos).first(where: { $0.id == itemID })?.dDayText
        case .document:
            return NotionHubMocks.details.values.flatMap(\.documents).first(where: { $0.id == itemID })?.priority
        case .memo:
            return NotionHubMocks.details.values.flatMap(\.memos).first(where: { $0.id == itemID })?.priority
        }
    }

    private func mockTags(for itemID: String, kind: NotionLinkedItemKind) -> [String] {
        switch kind {
        case .task:
            return []
        case .document:
            return NotionHubMocks.details.values.flatMap(\.documents).first(where: { $0.id == itemID })?.categoryTags ?? []
        case .memo:
            return NotionHubMocks.details.values.flatMap(\.memos).first(where: { $0.id == itemID })?.categoryTags ?? []
        }
    }

    private func mockMetadata(for itemID: String, kind: NotionLinkedItemKind) -> [NotionMetadataRow] {
        switch kind {
        case .task:
            guard let item = NotionHubMocks.details.values.flatMap(\.todos).first(where: { $0.id == itemID }) else { return [] }
            return [
                .init(title: "담당자", value: item.assignees.map(\.name).joined(separator: ", ")),
                .init(title: "시작일", value: item.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "마감일", value: item.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정")
            ]
        case .document:
            guard let item = NotionHubMocks.details.values.flatMap(\.documents).first(where: { $0.id == itemID }) else { return [] }
            return [
                .init(title: "작성자", value: item.author.map(\.name).joined(separator: ", ")),
                .init(title: "날짜", value: item.date?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "마감일", value: item.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정")
            ]
        case .memo:
            guard let item = NotionHubMocks.details.values.flatMap(\.memos).first(where: { $0.id == itemID }) else { return [] }
            return [
                .init(title: "날짜", value: item.date?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "마감일", value: item.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "공유", value: item.isExternallyShared ? "외부 공유됨" : "내부 전용")
            ]
        }
    }
}

actor NotionHubCachedService: NotionHubService {
    private let upstream: any NotionHubService
    private let cacheStore: NotionHubCacheStore
    private let policy: NotionHubCachePolicy

    init(
        upstream: any NotionHubService,
        cacheStore: NotionHubCacheStore = NotionHubCacheStore(),
        policy: NotionHubCachePolicy = NotionHubCachePolicy.defaultPolicy()
    ) {
        self.upstream = upstream
        self.cacheStore = cacheStore
        self.policy = policy
    }

    func fetchProjects(forceRefresh: Bool) async throws -> [NotionProjectSummary] {
        if !forceRefresh,
           let cachedEntry = await cacheStore.cachedProjects(),
           !isExpired(cachedEntry.cachedAt, ttl: policy.projectTTL) {
            return cachedEntry.projects
        }

        do {
            let projects = try await upstream.fetchProjects(forceRefresh: forceRefresh)
            await cacheStore.saveProjects(projects)
            return projects
        } catch {
            if let cachedEntry = await cacheStore.cachedProjects() {
                return cachedEntry.projects
            }
            throw error
        }
    }

    func fetchProjectDetail(projectID: String, forceRefresh: Bool) async throws -> NotionProjectDetail {
        if !forceRefresh,
           let cachedEntry = await cacheStore.cachedDetail(projectID: projectID),
           !isExpired(cachedEntry.cachedAt, ttl: policy.detailTTL) {
            return cachedEntry.detail
        }

        do {
            let detail = try await upstream.fetchProjectDetail(projectID: projectID, forceRefresh: forceRefresh)
            await cacheStore.saveDetail(detail, for: projectID)
            return detail
        } catch {
            if let cachedEntry = await cacheStore.cachedDetail(projectID: projectID) {
                return cachedEntry.detail
            }
            throw error
        }
    }

    func fetchLinkedItemDetail(itemID: String, kind: NotionLinkedItemKind, forceRefresh: Bool) async throws -> NotionLinkedItemDetail {
        let cacheKey = "\(kind.rawValue)-\(itemID)"

        if !forceRefresh,
           let cachedEntry = await cacheStore.cachedLinkedItemDetail(cacheKey: cacheKey),
           !isExpired(cachedEntry.cachedAt, ttl: policy.linkedItemTTL) {
            return cachedEntry.detail
        }

        do {
            let detail = try await upstream.fetchLinkedItemDetail(itemID: itemID, kind: kind, forceRefresh: forceRefresh)
            await cacheStore.saveLinkedItemDetail(detail, for: cacheKey)
            return detail
        } catch {
            if let cachedEntry = await cacheStore.cachedLinkedItemDetail(cacheKey: cacheKey) {
                return cachedEntry.detail
            }
            throw error
        }
    }

    private func isExpired(_ cachedAt: Date, ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(cachedAt) > ttl
    }
}

actor NotionHubLiveService: NotionHubService {
    private let configuration: NotionHubConfiguration
    private let session: URLSession

    init(
        configuration: NotionHubConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func fetchProjects(forceRefresh: Bool) async throws -> [NotionProjectSummary] {
        let pages = try await queryAllPages(
            dataSourceID: configuration.projectDataSourceID,
            sorts: [
                ["property": "Status", "direction": "ascending"],
                ["property": "마감기한", "direction": "ascending"]
            ]
        )

        let summaries = pages.map(makeProjectSummary)
        let visibleProjects = summaries.filter { !isExcludedProjectStatus($0.status) }
        let visibleProjectIDs = Set(visibleProjects.map(\.id))

        async let todoPages = queryAllPages(
            dataSourceID: configuration.todoDataSourceID,
            sorts: [
                ["property": "Due date", "direction": "ascending"],
                ["property": "Status", "direction": "ascending"]
            ]
        )

        async let documentPages = queryAllPages(
            dataSourceID: configuration.documentDataSourceID,
            sorts: [
                ["property": "날짜", "direction": "descending"]
            ]
        )

        async let memoPages = queryAllPages(
            dataSourceID: configuration.memoDataSourceID,
            sorts: [
                ["property": "날짜", "direction": "descending"]
            ]
        )

        let previews = try await buildProjectLinkedPreviews(
            visibleProjectIDs: visibleProjectIDs,
            todoPages: todoPages,
            documentPages: documentPages,
            memoPages: memoPages
        )

        return visibleProjects.map { project in
            let preview = previews[project.id] ?? NotionProjectLinkedPreview(
                todos: [],
                documents: [],
                memos: []
            )
            return makeProjectSummary(project: project, linkedPreview: preview)
        }.sorted { lhs, rhs in
            (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
        }
    }

    func fetchProjectDetail(projectID: String, forceRefresh: Bool) async throws -> NotionProjectDetail {
        let projectPage = try await request(path: "/v1/pages/\(projectID)", method: "GET")
        let project = makeProjectSummary(from: projectPage)

        guard !isExcludedProjectStatus(project.status) else {
            throw NotionHubServiceError.projectExcluded
        }

        async let todos = queryAllPages(
            dataSourceID: configuration.todoDataSourceID,
            filter: relationFilter(property: "🎯 Project", contains: projectID),
            sorts: [
                ["property": "Due date", "direction": "ascending"],
                ["property": "Status", "direction": "ascending"]
            ]
        )

        async let documents = queryAllPages(
            dataSourceID: configuration.documentDataSourceID,
            filter: relationFilter(property: "🎯 Project", contains: projectID),
            sorts: [
                ["property": "날짜", "direction": "descending"]
            ]
        )

        async let memos = queryAllPages(
            dataSourceID: configuration.memoDataSourceID,
            filter: relationFilter(property: "🎯 Project", contains: projectID),
            sorts: [
                ["property": "날짜", "direction": "descending"]
            ]
        )

        return NotionProjectDetail(
            project: project,
            todos: try await todos.map(makeTaskItem),
            documents: try await documents.map(makeDocumentItem),
            memos: try await memos.map(makeMemoItem)
        )
    }

    func fetchLinkedItemDetail(itemID: String, kind: NotionLinkedItemKind, forceRefresh: Bool) async throws -> NotionLinkedItemDetail {
        let page = try await request(path: "/v1/pages/\(itemID)", method: "GET")
        let contentBlocks = try await fetchContentBlocks(blockID: itemID)

        switch kind {
        case .task:
            return makeTaskDetail(from: page, contentBlocks: contentBlocks)
        case .document:
            return makeDocumentDetail(from: page, contentBlocks: contentBlocks)
        case .memo:
            return makeMemoDetail(from: page, contentBlocks: contentBlocks)
        }
    }

    private func queryAllPages(
        dataSourceID: String,
        filter: [String: Any]? = nil,
        sorts: [[String: Any]] = []
    ) async throws -> [[String: Any]] {
        var pages: [[String: Any]] = []
        var nextCursor: String?

        repeat {
            var body: [String: Any] = [
                "page_size": 100
            ]

            if let filter {
                body["filter"] = filter
            }
            if !sorts.isEmpty {
                body["sorts"] = sorts
            }
            if let nextCursor {
                body["start_cursor"] = nextCursor
            }

            let response = try await request(
                path: "/v1/data_sources/\(dataSourceID)/query",
                method: "POST",
                body: body
            )

            let batch = response["results"] as? [[String: Any]] ?? []
            pages.append(contentsOf: batch)
            nextCursor = response["next_cursor"] as? String
        } while nextCursor != nil

        return pages
    }

    private func fetchContentBlocks(blockID: String, depth: Int = 0) async throws -> [NotionLinkedContentBlock] {
        let children = try await queryBlockChildren(blockID: blockID)
        var flattened: [NotionLinkedContentBlock] = []

        for child in children {
            let blockID = child["id"] as? String ?? UUID().uuidString
            if let contentBlock = makeContentBlock(from: child, depth: depth) {
                flattened.append(contentBlock)
            }

            let hasChildren = child["has_children"] as? Bool ?? false
            if hasChildren {
                let descendants = try await fetchContentBlocks(blockID: blockID, depth: depth + 1)
                flattened.append(contentsOf: descendants)
            }
        }

        return flattened
    }

    private func queryBlockChildren(blockID: String) async throws -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        var nextCursor: String?

        repeat {
            var path = "/v1/blocks/\(blockID)/children?page_size=100"
            if let nextCursor {
                path += "&start_cursor=\(nextCursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nextCursor)"
            }

            let response = try await request(path: path, method: "GET")
            let batch = response["results"] as? [[String: Any]] ?? []
            blocks.append(contentsOf: batch)
            nextCursor = response["next_cursor"] as? String
        } while nextCursor != nil

        return blocks
    }

    private func request(
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        guard !configuration.secret.isEmpty else {
            throw NotionHubServiceError.configurationMissing("NOTION_INTERNAL_SECRET 설정이 비어 있습니다.")
        }

        guard let url = URL(string: "https://api.notion.com\(path)") else {
            throw NotionHubServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.secret)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.notionVersion, forHTTPHeaderField: "Notion-Version")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw NotionHubServiceError.invalidResponse
            }

            guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NotionHubServiceError.invalidResponse
            }

            guard (200..<300).contains(http.statusCode) else {
                let message = payload["message"] as? String ?? "status \(http.statusCode)"
                throw NotionHubServiceError.apiFailure("노션 API 오류: \(message)")
            }

            return payload
        } catch let error as NotionHubServiceError {
            throw error
        } catch {
            throw NotionHubServiceError.networkFailure("노션 통신에 실패했습니다. \(error.localizedDescription)")
        }
    }

    private func relationFilter(property: String, contains pageID: String) -> [String: Any] {
        [
            "property": property,
            "relation": [
                "contains": pageID
            ]
        ]
    }

    private func buildProjectLinkedPreviews(
        visibleProjectIDs: Set<String>,
        todoPages: [[String: Any]],
        documentPages: [[String: Any]],
        memoPages: [[String: Any]]
    ) -> [String: NotionProjectLinkedPreview] {
        var todosByProject: [String: [NotionTaskItem]] = [:]
        var documentsByProject: [String: [NotionDocumentItem]] = [:]
        var memosByProject: [String: [NotionMemoItem]] = [:]

        for page in todoPages {
            let properties = page["properties"] as? [String: Any] ?? [:]
            let projectIDs = relationIDs(for: "🎯 Project", in: properties)
                .filter { visibleProjectIDs.contains($0) }
            guard !projectIDs.isEmpty else { continue }

            let item = makeTaskItem(from: page)
            guard !isExcludedLinkedPreviewStatus(item.status) else { continue }

            for projectID in projectIDs {
                todosByProject[projectID, default: []].append(item)
            }
        }

        for page in documentPages {
            let properties = page["properties"] as? [String: Any] ?? [:]
            let projectIDs = relationIDs(for: "🎯 Project", in: properties)
                .filter { visibleProjectIDs.contains($0) }
            guard !projectIDs.isEmpty else { continue }

            let item = makeDocumentItem(from: page)
            guard !isExcludedLinkedPreviewStatus(item.status) else { continue }

            for projectID in projectIDs {
                documentsByProject[projectID, default: []].append(item)
            }
        }

        for page in memoPages {
            let properties = page["properties"] as? [String: Any] ?? [:]
            let projectIDs = relationIDs(for: "🎯 Project", in: properties)
                .filter { visibleProjectIDs.contains($0) }
            guard !projectIDs.isEmpty else { continue }

            let item = makeMemoItem(from: page)
            guard !isExcludedLinkedPreviewStatus(item.status) else { continue }

            for projectID in projectIDs {
                memosByProject[projectID, default: []].append(item)
            }
        }

        var previews: [String: NotionProjectLinkedPreview] = [:]
        for projectID in visibleProjectIDs {
            previews[projectID] = NotionProjectLinkedPreview(
                todos: (todosByProject[projectID] ?? []).sorted {
                    ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
                },
                documents: (documentsByProject[projectID] ?? []).sorted {
                    ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
                },
                memos: (memosByProject[projectID] ?? []).sorted {
                    ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
                }
            )
        }
        return previews
    }

    private func makeProjectSummary(
        project: NotionProjectSummary,
        linkedPreview: NotionProjectLinkedPreview
    ) -> NotionProjectSummary {
        NotionProjectSummary(
            id: project.id,
            title: project.title,
            emoji: project.emoji,
            status: project.status,
            owners: project.owners,
            participants: project.participants,
            dueDate: project.dueDate,
            clientTags: project.clientTags,
            summary: project.summary,
            currentSituation: project.currentSituation,
            notionURL: project.notionURL,
            linkedPreview: linkedPreview
        )
    }

    private func makeProjectSummary(from page: [String: Any]) -> NotionProjectSummary {
        let properties = page["properties"] as? [String: Any] ?? [:]
        let owners = peopleValue(for: "Project Owner", in: properties)
        let participants = mergePeople(
            peopleValue(for: "담당자", in: properties),
            multiSelectPeopleValue(for: "진행 담당자", in: properties)
        )

        return NotionProjectSummary(
            id: page["id"] as? String ?? UUID().uuidString,
            title: titleValue(for: "Name", in: properties),
            emoji: emojiValue(from: page),
            status: statusValue(for: "Status", in: properties),
            owners: owners,
            participants: participants,
            dueDate: dateValue(for: "마감기한", in: properties),
            clientTags: multiSelectValue(for: "클라이언트", in: properties),
            summary: richTextValue(for: "요약", in: properties),
            currentSituation: richTextValue(for: "현재 상황", in: properties),
            notionURL: urlValue(from: page),
            linkedPreview: NotionProjectLinkedPreview(
                todos: [],
                documents: [],
                memos: []
            )
        )
    }

    private func makeTaskItem(from page: [String: Any]) -> NotionTaskItem {
        let properties = page["properties"] as? [String: Any] ?? [:]
        return NotionTaskItem(
            id: page["id"] as? String ?? UUID().uuidString,
            title: titleValue(for: "Name", in: properties),
            emoji: emojiValue(from: page),
            status: statusValue(for: "Status", in: properties),
            assignees: peopleValue(for: "Assigned To", in: properties),
            dueDate: dateValue(for: "Due date", in: properties),
            startDate: dateValue(for: "Start Date", in: properties),
            dDayText: formulaStringValue(for: "D-day", in: properties),
            notionURL: urlValue(from: page)
        )
    }

    private func makeDocumentItem(from page: [String: Any]) -> NotionDocumentItem {
        let properties = page["properties"] as? [String: Any] ?? [:]
        return NotionDocumentItem(
            id: page["id"] as? String ?? UUID().uuidString,
            title: titleValue(for: "Name", in: properties),
            emoji: emojiValue(from: page),
            status: statusValue(for: "Status", in: properties),
            author: peopleValue(for: "작성자", in: properties),
            categoryTags: multiSelectValue(for: "분류(내용)", in: properties),
            date: dateValue(for: "날짜", in: properties),
            dueDate: dateValue(for: "Due date", in: properties),
            priority: selectValue(for: "priority", in: properties),
            summary: richTextValue(for: "요약", in: properties),
            notionURL: urlValue(from: page)
        )
    }

    private func makeMemoItem(from page: [String: Any]) -> NotionMemoItem {
        let properties = page["properties"] as? [String: Any] ?? [:]
        return NotionMemoItem(
            id: page["id"] as? String ?? UUID().uuidString,
            title: titleValue(for: "이름", in: properties),
            emoji: emojiValue(from: page),
            status: statusValue(for: "Status", in: properties),
            date: dateValue(for: "날짜", in: properties),
            dueDate: dateValue(for: "Due date", in: properties),
            categoryTags: multiSelectValue(for: "분류(내용)", in: properties),
            priority: selectValue(for: "priority", in: properties),
            summary: richTextValue(for: "요약", in: properties),
            isExternallyShared: checkboxValue(for: "외부공유여부", in: properties),
            notionURL: urlValue(from: page)
        )
    }

    private func makeTaskDetail(
        from page: [String: Any],
        contentBlocks: [NotionLinkedContentBlock]
    ) -> NotionLinkedItemDetail {
        let item = makeTaskItem(from: page)
        return NotionLinkedItemDetail(
            id: item.id,
            kind: .task,
            title: item.title,
            emoji: item.emoji,
            status: item.status,
            summary: [item.assignees.map(\.name).joined(separator: ", "), item.dDayText]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " · "),
            secondaryBadge: item.dDayText.nilIfEmpty,
            notionURL: item.notionURL,
            tags: [],
            metadataRows: [
                .init(title: "담당자", value: item.assignees.map(\.name).joined(separator: ", ").nilIfEmpty ?? "미지정"),
                .init(title: "시작일", value: item.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "마감일", value: item.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "D-day", value: item.dDayText.nilIfEmpty ?? "없음")
            ],
            contentBlocks: contentBlocks
        )
    }

    private func makeDocumentDetail(
        from page: [String: Any],
        contentBlocks: [NotionLinkedContentBlock]
    ) -> NotionLinkedItemDetail {
        let item = makeDocumentItem(from: page)
        return NotionLinkedItemDetail(
            id: item.id,
            kind: .document,
            title: item.title,
            emoji: item.emoji,
            status: item.status,
            summary: item.summary,
            secondaryBadge: item.priority.nilIfEmpty,
            notionURL: item.notionURL,
            tags: item.categoryTags,
            metadataRows: [
                .init(title: "작성자", value: item.author.map(\.name).joined(separator: ", ").nilIfEmpty ?? "미지정"),
                .init(title: "날짜", value: item.date?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "마감일", value: item.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "우선순위", value: item.priority.nilIfEmpty ?? "미지정")
            ],
            contentBlocks: contentBlocks
        )
    }

    private func makeMemoDetail(
        from page: [String: Any],
        contentBlocks: [NotionLinkedContentBlock]
    ) -> NotionLinkedItemDetail {
        let item = makeMemoItem(from: page)
        let secondary = item.isExternallyShared ? "외부공유" : item.priority.nilIfEmpty
        return NotionLinkedItemDetail(
            id: item.id,
            kind: .memo,
            title: item.title,
            emoji: item.emoji,
            status: item.status,
            summary: item.summary,
            secondaryBadge: secondary,
            notionURL: item.notionURL,
            tags: item.categoryTags,
            metadataRows: [
                .init(title: "날짜", value: item.date?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "마감일", value: item.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"),
                .init(title: "우선순위", value: item.priority.nilIfEmpty ?? "미지정"),
                .init(title: "공유", value: item.isExternallyShared ? "외부 공유됨" : "내부 전용")
            ],
            contentBlocks: contentBlocks
        )
    }

    private func makeContentBlock(from block: [String: Any], depth: Int) -> NotionLinkedContentBlock? {
        let blockID = block["id"] as? String ?? UUID().uuidString
        let type = block["type"] as? String ?? ""
        let nested = block[type] as? [String: Any] ?? [:]
        
        // Extract common properties
        let color = nested["color"] as? String
        let blockIcon = extractBlockIcon(from: nested)
        let isChecked = nested["checked"] as? Bool
        let richText = richTextSegments(from: nested["rich_text"] as? [[String: Any]] ?? [])
        let plainText = richText.map(\.text).joined()

        switch type {
        case "heading_1":
            return NotionLinkedContentBlock(id: blockID, style: .heading1, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "heading_2":
            return NotionLinkedContentBlock(id: blockID, style: .heading2, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "heading_3":
            return NotionLinkedContentBlock(id: blockID, style: .heading3, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "paragraph":
            return NotionLinkedContentBlock(id: blockID, style: .body, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "bulleted_list_item":
            return NotionLinkedContentBlock(id: blockID, style: .bullet, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "numbered_list_item":
            return NotionLinkedContentBlock(id: blockID, style: .numbered, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "quote":
            return NotionLinkedContentBlock(id: blockID, style: .quote, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "callout":
            return NotionLinkedContentBlock(id: blockID, style: .callout, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: blockIcon)
        case "code":
            return NotionLinkedContentBlock(id: blockID, style: .code, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "toggle":
            return NotionLinkedContentBlock(id: blockID, style: .note, text: plainText, richText: richText, depth: depth, isChecked: nil, color: color, icon: nil)
        case "to_do":
            guard !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return NotionLinkedContentBlock(id: blockID, style: .todo, text: plainText, richText: richText, depth: depth, isChecked: isChecked, color: color, icon: nil)
        case "divider":
            return NotionLinkedContentBlock(id: blockID, style: .divider, text: "", richText: [], depth: depth, isChecked: nil, color: nil, icon: nil)
        case "child_page":
            let text = nested["title"] as? String ?? "하위 페이지"
            return NotionLinkedContentBlock(id: blockID, style: .note, text: text, richText: [], depth: depth, isChecked: nil, color: nil, icon: nil)
        default:
            return nil
        }
    }

    private func extractBlockIcon(from nested: [String: Any]) -> String? {
        guard let icon = nested["icon"] as? [String: Any] else { return nil }
        if icon["type"] as? String == "emoji" {
            return icon["emoji"] as? String
        }
        // Handle external or file icons if needed
        return nil
    }

    private func richTextSegments(from fragments: [[String: Any]]) -> [NotionRichTextSegment] {
        fragments.compactMap { fragment in
            guard let textContainer = fragment["text"] as? [String: Any],
                  let content = textContainer["content"] as? String else { return nil }
            
            let annotationsDict = fragment["annotations"] as? [String: Any] ?? [:]
            let annotations = NotionRichTextSegment.Annotations(
                bold: annotationsDict["bold"] as? Bool ?? false,
                italic: annotationsDict["italic"] as? Bool ?? false,
                strikethrough: annotationsDict["strikethrough"] as? Bool ?? false,
                underline: annotationsDict["underline"] as? Bool ?? false,
                code: annotationsDict["code"] as? Bool ?? false,
                color: annotationsDict["color"] as? String
            )
            
            return NotionRichTextSegment(
                text: content,
                href: fragment["href"] as? String,
                annotations: annotations
            )
        }
    }

    private func urlValue(from page: [String: Any]) -> URL? {
        guard let value = page["url"] as? String else {
            return nil
        }
        return URL(string: value)
    }

    private func relationIDs(for property: String, in properties: [String: Any]) -> [String] {
        let relationProperty = properties[property] as? [String: Any] ?? [:]
        let relations = relationProperty["relation"] as? [[String: Any]] ?? []
        return relations.compactMap { $0["id"] as? String }
    }

    private func isExcludedLinkedPreviewStatus(_ status: String) -> Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "delayed"
            || normalized == "task done"
            || normalized == "project done"
    }

    private func emojiValue(from page: [String: Any]) -> String? {
        guard let icon = page["icon"] as? [String: Any],
              icon["type"] as? String == "emoji" else {
            return nil
        }
        return icon["emoji"] as? String
    }

    private func titleValue(for key: String, in properties: [String: Any]) -> String {
        guard let property = properties[key] as? [String: Any] else { return "" }
        if property["type"] as? String == "title" {
            return richTextPlainText(from: property["title"] as? [[String: Any]] ?? [])
        }
        return ""
    }

    private func richTextValue(for key: String, in properties: [String: Any]) -> String {
        guard let property = properties[key] as? [String: Any],
              property["type"] as? String == "rich_text" else {
            return ""
        }
        return richTextPlainText(from: property["rich_text"] as? [[String: Any]] ?? [])
    }

    private func statusValue(for key: String, in properties: [String: Any]) -> String {
        guard let property = properties[key] as? [String: Any],
              property["type"] as? String == "status",
              let status = property["status"] as? [String: Any] else {
            return ""
        }
        return status["name"] as? String ?? ""
    }

    private func selectValue(for key: String, in properties: [String: Any]) -> String {
        guard let property = properties[key] as? [String: Any],
              property["type"] as? String == "select",
              let select = property["select"] as? [String: Any] else {
            return ""
        }
        return select["name"] as? String ?? ""
    }

    private func multiSelectValue(for key: String, in properties: [String: Any]) -> [String] {
        guard let property = properties[key] as? [String: Any],
              property["type"] as? String == "multi_select",
              let values = property["multi_select"] as? [[String: Any]] else {
            return []
        }
        return values.compactMap { $0["name"] as? String }
    }

    private func multiSelectPeopleValue(for key: String, in properties: [String: Any]) -> [NotionPersonChip] {
        multiSelectValue(for: key, in: properties).map { NotionPersonChip(name: $0) }
    }

    private func peopleValue(for key: String, in properties: [String: Any]) -> [NotionPersonChip] {
        guard let property = properties[key] as? [String: Any],
              property["type"] as? String == "people",
              let values = property["people"] as? [[String: Any]] else {
            return []
        }

        return values.map { value in
            let id = value["id"] as? String
            let name = value["name"] as? String ?? "이름 없음"
            let email = (value["person"] as? [String: Any])?["email"] as? String
            let avatar = value["avatar_url"] as? String
            return NotionPersonChip(id: id, name: name, email: email, photoURL: avatar)
        }
    }

    private func dateValue(for key: String, in properties: [String: Any]) -> Date? {
        guard let property = properties[key] as? [String: Any],
              property["type"] as? String == "date",
              let date = property["date"] as? [String: Any],
              let start = date["start"] as? String else {
            return nil
        }

        return parseISODate(start)
    }

    private func formulaStringValue(for key: String, in properties: [String: Any]) -> String {
        guard let property = properties[key] as? [String: Any],
              property["type"] as? String == "formula",
              let formula = property["formula"] as? [String: Any] else {
            return ""
        }

        if let string = formula["string"] as? String {
            return string
        }
        if let number = formula["number"] as? NSNumber {
            return "D-\(number.intValue)"
        }
        if let boolean = formula["boolean"] as? Bool {
            return boolean ? "예" : ""
        }
        return ""
    }

    private func checkboxValue(for key: String, in properties: [String: Any]) -> Bool {
        guard let property = properties[key] as? [String: Any],
              property["type"] as? String == "checkbox" else {
            return false
        }
        return property["checkbox"] as? Bool ?? false
    }

    private func richTextPlainText(from fragments: [[String: Any]]) -> String {
        richTextSegments(from: fragments).map(\.text).joined()
    }

    private func mergePeople(_ lhs: [NotionPersonChip], _ rhs: [NotionPersonChip]) -> [NotionPersonChip] {
        var seen = Set<String>()
        var merged: [NotionPersonChip] = []

        for person in lhs + rhs {
            if seen.insert(person.name).inserted {
                merged.append(person)
            }
        }

        return merged
    }

    private func parseISODate(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.date(from: value)
    }

    private func isExcludedProjectStatus(_ status: String) -> Bool {
        configuration.excludedProjectStatuses.contains(status)
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
