import Foundation

nonisolated struct NotionHubCachePolicy: Sendable {
    let projectTTL: TimeInterval
    let detailTTL: TimeInterval
    let linkedItemTTL: TimeInterval

    static func defaultPolicy() -> NotionHubCachePolicy {
        NotionHubCachePolicy(
            projectTTL: 60 * 10,
            detailTTL: 60 * 15,
            linkedItemTTL: 60 * 20
        )
    }
}

nonisolated struct NotionHubCacheSnapshot: Codable, Sendable {
    nonisolated struct ProjectsEntry: Codable, Sendable {
        let cachedAt: Date
        let projects: [NotionProjectSummary]
    }

    nonisolated struct DetailEntry: Codable, Sendable {
        let cachedAt: Date
        let detail: NotionProjectDetail
    }

    nonisolated struct LinkedItemEntry: Codable, Sendable {
        let cachedAt: Date
        let detail: NotionLinkedItemDetail
    }

    var projectsEntry: ProjectsEntry?
    var detailEntries: [String: DetailEntry]
    var linkedItemEntries: [String: LinkedItemEntry]

    static func emptySnapshot() -> NotionHubCacheSnapshot {
        NotionHubCacheSnapshot(
            projectsEntry: nil,
            detailEntries: [:],
            linkedItemEntries: [:]
        )
    }
}

actor NotionHubCacheStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "NotionHubCache.json") {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.fileURL = baseURL.appendingPathComponent(filename)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSnapshot() -> NotionHubCacheSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? decoder.decode(NotionHubCacheSnapshot.self, from: data) else {
            return .emptySnapshot()
        }

        return snapshot
    }

    func saveProjects(_ projects: [NotionProjectSummary]) {
        var snapshot = loadSnapshot()
        snapshot.projectsEntry = .init(cachedAt: .now, projects: projects)
        persist(snapshot)
    }

    func saveDetail(_ detail: NotionProjectDetail, for projectID: String) {
        var snapshot = loadSnapshot()
        snapshot.detailEntries[projectID] = .init(cachedAt: .now, detail: detail)
        persist(snapshot)
    }

    func saveLinkedItemDetail(_ detail: NotionLinkedItemDetail, for cacheKey: String) {
        var snapshot = loadSnapshot()
        snapshot.linkedItemEntries[cacheKey] = .init(cachedAt: .now, detail: detail)
        persist(snapshot)
    }

    func cachedProjects() -> NotionHubCacheSnapshot.ProjectsEntry? {
        loadSnapshot().projectsEntry
    }

    func cachedDetail(projectID: String) -> NotionHubCacheSnapshot.DetailEntry? {
        loadSnapshot().detailEntries[projectID]
    }

    func cachedLinkedItemDetail(cacheKey: String) -> NotionHubCacheSnapshot.LinkedItemEntry? {
        loadSnapshot().linkedItemEntries[cacheKey]
    }

    private func persist(_ snapshot: NotionHubCacheSnapshot) {
        do {
            let parentDirectory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Cache write failures should not block the feature.
        }
    }
}
