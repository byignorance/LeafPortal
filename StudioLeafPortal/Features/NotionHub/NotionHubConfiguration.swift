import Foundation

struct NotionHubConfiguration {
    let secret: String
    let notionVersion: String
    let projectDataSourceID: String
    let todoDataSourceID: String
    let documentDataSourceID: String
    let memoDataSourceID: String
    let excludedProjectStatuses: Set<String>

    static let live = NotionHubConfiguration(
        secret: NotionHubConfigurationLoader.loadSecret(),
        notionVersion: "2025-09-03",
        projectDataSourceID: "f05e757f-daef-46a4-8039-ee08c47cc200",
        todoDataSourceID: "281fae2d-9751-8112-af6f-000b15e6c943",
        documentDataSourceID: "859649f6-698e-459b-b595-c4c8d3cbebdc",
        memoDataSourceID: "281fae2d-9751-815d-ab22-000bde04933b",
        excludedProjectStatuses: ["Project Done", "Cancel"]
    )

    func withSecret(_ secret: String) -> NotionHubConfiguration {
        NotionHubConfiguration(
            secret: secret,
            notionVersion: notionVersion,
            projectDataSourceID: projectDataSourceID,
            todoDataSourceID: todoDataSourceID,
            documentDataSourceID: documentDataSourceID,
            memoDataSourceID: memoDataSourceID,
            excludedProjectStatuses: excludedProjectStatuses
        )
    }
}

struct NotionOAuthConfiguration {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let appRedirectURI: String
    let authorizeURL: String

    static let live = NotionOAuthConfiguration(
        clientID: NotionHubConfigurationLoader.loadValue(for: "NOTION_OAUTH_CLIENT_ID"),
        clientSecret: NotionHubConfigurationLoader.loadValue(for: "NOTION_OAUTH_CLIENT_SECRET"),
        redirectURI: NotionHubConfigurationLoader.loadValue(
            for: "NOTION_OAUTH_REDIRECT_URI",
            defaultValue: "https://app.studioleaf.kr/notion-oauth/callback"
        ),
        appRedirectURI: NotionHubConfigurationLoader.loadValue(
            for: "NOTION_OAUTH_APP_REDIRECT_URI",
            defaultValue: "studioleafportal-notion://oauth/notion"
        ),
        authorizeURL: NotionHubConfigurationLoader.loadValue(
            for: "NOTION_OAUTH_AUTHORIZE_URL",
            defaultValue: "https://api.notion.com/v1/oauth/authorize"
        )
    )

    var isConfigured: Bool {
        !clientID.isEmpty
            && !clientSecret.isEmpty
            && !redirectURI.isEmpty
            && !appRedirectURI.isEmpty
            && !authorizeURL.isEmpty
    }

    var callbackScheme: String? {
        URL(string: appRedirectURI)?.scheme
    }
}

enum NotionHubConfigurationLoader {
    static func loadSecret() -> String {
        loadValue(for: "NOTION_INTERNAL_SECRET")
    }

    static func loadValue(for key: String, defaultValue: String = "") -> String {
        if let environmentValue = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !environmentValue.isEmpty {
            return environmentValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        for candidate in dotenvCandidates() {
            if let value = loadValue(for: key, fromDotEnvAt: candidate) {
                return value
            }
        }

        return defaultValue
    }

    private static func dotenvCandidates() -> [URL] {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        return [
            sourceRoot.appendingPathComponent(".env.local"),
            workingDirectory.appendingPathComponent(".env.local")
        ]
    }

    private static func loadValue(for key: String, fromDotEnvAt url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else {
            return nil
        }

        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                continue
            }

            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }

            let currentKey = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard currentKey == key else {
                continue
            }

            return parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }

        return nil
    }
}

enum NotionHubServiceFactory {
    static func makeRuntimeService(oauthManager: NotionOAuthManager) -> any NotionHubService {
        let configuration = NotionHubConfiguration.live
        if configuration.secret.isEmpty {
            return NotionHubUnavailableService(
                message: "NOTION_INTERNAL_SECRET 설정이 없어 노션 프로젝트를 불러올 수 없습니다."
            )
        }

        return NotionHubCachedService(
            upstream: NotionHubLiveService(configuration: configuration),
            cacheStore: NotionHubCacheStore(),
            policy: NotionHubCachePolicy.defaultPolicy()
        )
    }
}
