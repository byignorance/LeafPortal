import Foundation

actor NotionHubAdaptiveService: NotionHubService {
    private let fallbackConfiguration: NotionHubConfiguration
    private let oauthAccessTokenProvider: @Sendable () async -> String?

    init(
        fallbackConfiguration: NotionHubConfiguration,
        oauthAccessTokenProvider: @escaping @Sendable () async -> String?
    ) {
        self.fallbackConfiguration = fallbackConfiguration
        self.oauthAccessTokenProvider = oauthAccessTokenProvider
    }

    func fetchProjects(forceRefresh: Bool) async throws -> [NotionProjectSummary] {
        let service = try await makeActiveService()
        return try await service.fetchProjects(forceRefresh: forceRefresh)
    }

    func fetchProjectDetail(projectID: String, forceRefresh: Bool) async throws -> NotionProjectDetail {
        let service = try await makeActiveService()
        return try await service.fetchProjectDetail(projectID: projectID, forceRefresh: forceRefresh)
    }

    func fetchLinkedItemDetail(itemID: String, kind: NotionLinkedItemKind, forceRefresh: Bool) async throws -> NotionLinkedItemDetail {
        let service = try await makeActiveService()
        return try await service.fetchLinkedItemDetail(itemID: itemID, kind: kind, forceRefresh: forceRefresh)
    }

    private func makeActiveService() async throws -> NotionHubLiveService {
        let fallbackConfiguration = self.fallbackConfiguration
        let trimmedToken = await oauthAccessTokenProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedToken, !trimmedToken.isEmpty {
            let personalConfiguration = NotionHubConfiguration(
                secret: trimmedToken,
                notionVersion: fallbackConfiguration.notionVersion,
                projectDataSourceID: fallbackConfiguration.projectDataSourceID,
                todoDataSourceID: fallbackConfiguration.todoDataSourceID,
                documentDataSourceID: fallbackConfiguration.documentDataSourceID,
                memoDataSourceID: fallbackConfiguration.memoDataSourceID,
                excludedProjectStatuses: fallbackConfiguration.excludedProjectStatuses
            )
            return await NotionHubLiveService(
                configuration: personalConfiguration
            )
        }

        if !fallbackConfiguration.secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return await NotionHubLiveService(configuration: fallbackConfiguration)
        }

        throw NotionHubServiceError.configurationMissing(
            "개인 노션 연결 또는 NOTION_INTERNAL_SECRET 설정이 필요합니다."
        )
    }
}
