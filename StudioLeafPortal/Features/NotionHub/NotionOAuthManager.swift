import AppKit
import AuthenticationServices
import Combine
import Foundation
import Security

@MainActor
final class NotionOAuthManager: NSObject, ObservableObject {
    struct Session: Codable, Sendable {
        let accessToken: String
        let refreshToken: String?
        let workspaceID: String
        let workspaceName: String?
        let workspaceIcon: String?
        let botID: String
        let ownerName: String?
        let ownerEmail: String?
        let createdAt: Date
    }

    @Published private(set) var session: Session?
    @Published private(set) var isConnecting = false
    @Published private(set) var errorMessage: String?

    var isConnected: Bool {
        session != nil
    }

    var isAvailable: Bool {
        configuration.isConfigured
    }

    var workspaceLabel: String {
        if let workspaceName = session?.workspaceName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !workspaceName.isEmpty {
            return workspaceName
        }

        if let ownerName = session?.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ownerName.isEmpty {
            return ownerName
        }

        return "개인 노션"
    }

    var statusLine: String {
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }

        if isConnecting {
            return "개인 노션 연결 중"
        }

        if session != nil {
            return "\(workspaceLabel) 연결됨"
        }

        if configuration.isConfigured {
            return "개인 노션을 연결하면 사용자 권한 기준으로 문서를 불러옵니다."
        }

        return "공용 Notion 연결을 사용 중입니다."
    }

    private let configuration: NotionOAuthConfiguration
    private var webAuthenticationSession: ASWebAuthenticationSession?
    private let keychainService = "kr.studioleaf.portal.notion.oauth"
    private let keychainAccount = "default"

    override init() {
        self.configuration = .live
        self.session = nil
        super.init()
        self.session = loadStoredSession()
    }

    func currentAccessToken() async -> String? {
        session?.accessToken
    }

    func connect() async -> Bool {
        guard !isConnecting else { return false }
        guard configuration.isConfigured else {
            errorMessage = "NOTION_OAUTH_CLIENT_ID / SECRET / REDIRECT_URI 설정이 필요합니다."
            return false
        }

        isConnecting = true
        errorMessage = nil
        defer {
            isConnecting = false
            webAuthenticationSession = nil
        }

        let state = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        do {
            let callbackURL = try await startAuthorizationFlow(state: state)
            let authorizationCode = try authorizationCode(from: callbackURL, expectedState: state)
            let session = try await exchangeCodeForToken(authorizationCode)
            try save(session: session)
            self.session = session
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func disconnect() async {
        errorMessage = nil
        session = nil
        deleteStoredSession()
        await NotionWebSessionManager.shared.clearSession()
    }

    private func startAuthorizationFlow(state: String) async throws -> URL {
        guard let authorizationURL = makeAuthorizationURL(state: state) else {
            throw NotionOAuthError.invalidAuthorizationURL
        }

        guard let callbackScheme = configuration.callbackScheme else {
            throw NotionOAuthError.invalidRedirectURI
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: NotionOAuthError.missingCallbackURL)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            self.webAuthenticationSession = session

            if !session.start() {
                continuation.resume(throwing: NotionOAuthError.unableToStartSession)
            }
        }
    }

    private func makeAuthorizationURL(state: String) -> URL? {
        guard var components = URLComponents(string: configuration.authorizeURL) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "owner", value: "user"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state)
        ]

        return components.url
    }

    private func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw NotionOAuthError.invalidCallbackURL
        }

        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })

        if let error = queryItems["error"], !error.isEmpty {
            let description = queryItems["error_description"]?.removingPercentEncoding ?? error
            throw NotionOAuthError.authorizationFailed(description)
        }

        if let state = queryItems["state"], state != expectedState {
            throw NotionOAuthError.stateMismatch
        }

        guard let code = queryItems["code"], !code.isEmpty else {
            throw NotionOAuthError.missingAuthorizationCode
        }

        return code
    }

    private func exchangeCodeForToken(_ code: String) async throws -> Session {
        guard let url = URL(string: "https://api.notion.com/v1/oauth/token") else {
            throw NotionOAuthError.invalidTokenEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(basicAuthorizationValue)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(TokenExchangeRequest(
            grantType: "authorization_code",
            code: code,
            redirectURI: configuration.redirectURI
        ))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionOAuthError.invalidTokenResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(TokenErrorResponse.self, from: data)
            let description = sanitized(apiError?.errorDescription) ?? sanitized(apiError?.error)
            throw NotionOAuthError.tokenExchangeFailed(description ?? "status \(httpResponse.statusCode)")
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        return Session(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            workspaceID: tokenResponse.workspaceID,
            workspaceName: tokenResponse.workspaceName,
            workspaceIcon: tokenResponse.workspaceIcon,
            botID: tokenResponse.botID,
            ownerName: tokenResponse.owner?.user?.name,
            ownerEmail: tokenResponse.owner?.user?.person?.email,
            createdAt: Date()
        )
    }

    private var basicAuthorizationValue: String {
        Data("\(configuration.clientID):\(configuration.clientSecret)".utf8).base64EncodedString()
    }

    private func save(session: Session) throws {
        let encoded = try JSONEncoder().encode(session)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]

        let update: [CFString: Any] = [
            kSecValueData: encoded
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status == errSecItemNotFound {
            var createQuery = query
            createQuery[kSecValueData] = encoded
            let createStatus = SecItemAdd(createQuery as CFDictionary, nil)
            guard createStatus == errSecSuccess else {
                throw NotionOAuthError.keychainFailure(createStatus)
            }
            return
        }

        throw NotionOAuthError.keychainFailure(status)
    }

    private func loadStoredSession() -> Session? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let session = try? JSONDecoder().decode(Session.self, from: data) else {
            return nil
        }

        return session
    }

    private func deleteStoredSession() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    private func sanitized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

extension NotionOAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: \.isVisible)
            ?? ASPresentationAnchor()
    }
}

private struct TokenExchangeRequest: Encodable {
    let grantType: String
    let code: String
    let redirectURI: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectURI = "redirect_uri"
    }
}

private struct TokenResponse: Decodable {
    struct Owner: Decodable {
        struct User: Decodable {
            struct Person: Decodable {
                let email: String?
            }

            let name: String?
            let person: Person?
        }

        let user: User?
    }

    let accessToken: String
    let refreshToken: String?
    let botID: String
    let workspaceIcon: String?
    let workspaceName: String?
    let workspaceID: String
    let owner: Owner?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case botID = "bot_id"
        case workspaceIcon = "workspace_icon"
        case workspaceName = "workspace_name"
        case workspaceID = "workspace_id"
        case owner
    }
}

private struct TokenErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private enum NotionOAuthError: LocalizedError {
    case invalidAuthorizationURL
    case invalidRedirectURI
    case unableToStartSession
    case missingCallbackURL
    case invalidCallbackURL
    case stateMismatch
    case missingAuthorizationCode
    case invalidTokenEndpoint
    case invalidTokenResponse
    case authorizationFailed(String)
    case tokenExchangeFailed(String)
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL:
            return "노션 인증 주소를 만들지 못했습니다."
        case .invalidRedirectURI:
            return "노션 Redirect URI 설정이 잘못되었습니다."
        case .unableToStartSession:
            return "노션 인증 세션을 시작하지 못했습니다."
        case .missingCallbackURL:
            return "노션 인증 콜백 URL이 비어 있습니다."
        case .invalidCallbackURL:
            return "노션 인증 콜백 URL을 해석하지 못했습니다."
        case .stateMismatch:
            return "노션 인증 상태 값이 일치하지 않습니다."
        case .missingAuthorizationCode:
            return "노션 인증 코드를 받지 못했습니다."
        case .invalidTokenEndpoint:
            return "노션 토큰 교환 주소가 잘못되었습니다."
        case .invalidTokenResponse:
            return "노션 토큰 응답을 해석하지 못했습니다."
        case .authorizationFailed(let message):
            return "노션 인증이 취소되었거나 실패했습니다. \(message)"
        case .tokenExchangeFailed(let message):
            return "노션 토큰 교환에 실패했습니다. \(message)"
        case .keychainFailure:
            return "노션 로그인 정보를 키체인에 저장하지 못했습니다."
        }
    }
}
