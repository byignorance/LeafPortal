import Combine
import Foundation
import WebKit

@MainActor
final class NotionWebSessionManager: ObservableObject {
    static let shared = NotionWebSessionManager()

    @Published private(set) var hasSession = false

    private let dataStore = WKWebsiteDataStore.default()

    private init() {
        Task {
            await refreshSessionStatus()
        }
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        return configuration
    }

    func clearSession() async {
        let cookieStore = dataStore.httpCookieStore
        let cookies = await allCookies(from: cookieStore)
        for cookie in cookies where isNotionCookie(cookie) {
            await delete(cookie: cookie, from: cookieStore)
        }

        let recordTypes = Set([
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache
        ])

        let records = await dataRecords(ofTypes: recordTypes, from: dataStore)
        let notionRecords = records.filter { record in
            record.displayName.localizedCaseInsensitiveContains("notion")
        }

        await removeData(ofTypes: recordTypes, for: notionRecords, from: dataStore)
        hasSession = false
    }

    func refreshSessionStatus() async {
        let cookieStore = dataStore.httpCookieStore
        let cookies = await allCookies(from: cookieStore)
        hasSession = cookies.contains(where: isNotionCookie)
    }

    private func isNotionCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.lowercased()
        return domain.contains("notion.so") || domain.contains("notion.site")
    }

    private func allCookies(from cookieStore: WKHTTPCookieStore) async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            cookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    private func delete(cookie: HTTPCookie, from cookieStore: WKHTTPCookieStore) async {
        await withCheckedContinuation { continuation in
            cookieStore.delete(cookie) {
                continuation.resume()
            }
        }
    }

    private func dataRecords(
        ofTypes recordTypes: Set<String>,
        from dataStore: WKWebsiteDataStore
    ) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { continuation in
            dataStore.fetchDataRecords(ofTypes: recordTypes) { records in
                continuation.resume(returning: records)
            }
        }
    }

    private func removeData(
        ofTypes recordTypes: Set<String>,
        for records: [WKWebsiteDataRecord],
        from dataStore: WKWebsiteDataStore
    ) async {
        await withCheckedContinuation { continuation in
            dataStore.removeData(ofTypes: recordTypes, for: records) {
                continuation.resume()
            }
        }
    }
}
