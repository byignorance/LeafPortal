import Foundation

struct NotionDatabaseTarget {
    let name: String
    let databaseID: String
}

struct NotionPropertySummary {
    let name: String
    let type: String
}

enum NotionSchemaDumpError: LocalizedError {
    case missingSecret
    case invalidResponse(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingSecret:
            return "NOTION_INTERNAL_SECRET environment variable is missing."
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .apiError(let message):
            return "Notion API error: \(message)"
        }
    }
}

enum NotionSchemaDumpTool {
    private static let notionVersion = "2025-09-03"

    private static let targets: [NotionDatabaseTarget] = [
        .init(name: "Project", databaseID: "a4a818d848e643f096cf218a5a52351d"),
        .init(name: "To-do", databaseID: "281fae2d975180db8b14cd08f8d54309"),
        .init(name: "Document", databaseID: "62b0ea2ef3ed46bea80a2882f2ce8433"),
        .init(name: "Memo", databaseID: "281fae2d97518076a03cec06a9b542b8")
    ]

    static func run() async throws {
        let secret = try loadSecret()

        for target in targets {
            let database = try await fetchJSON(
                path: "/v1/databases/\(target.databaseID)",
                secret: secret
            )
            let dataSourceIDs = extractDataSourceIDs(from: database)

            print("=== \(target.name) ===")
            print("Database ID: \(target.databaseID)")

            if dataSourceIDs.isEmpty {
                print("No data sources returned. Check whether the original database was shared with the integration.")
                print("")
                continue
            }

            for (index, dataSourceID) in dataSourceIDs.enumerated() {
                let dataSource = try await fetchJSON(
                    path: "/v1/data_sources/\(dataSourceID)",
                    secret: secret
                )
                let properties = extractProperties(from: dataSource)
                let label = dataSourceIDs.count == 1 ? "Properties" : "Data Source \(index + 1) Properties"

                print("\(label):")
                for property in properties.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                    print("- \(property.name) [\(property.type)]")
                }
            }

            print("")
        }
    }

    private static func loadSecret() throws -> String {
        let secret = ProcessInfo.processInfo.environment["NOTION_INTERNAL_SECRET"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !secret.isEmpty else {
            throw NotionSchemaDumpError.missingSecret
        }
        return secret
    }

    private static func fetchJSON(path: String, secret: String) async throws -> [String: Any] {
        guard let url = URL(string: "https://api.notion.com\(path)") else {
            throw NotionSchemaDumpError.invalidResponse("Bad URL for path \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NotionSchemaDumpError.invalidResponse("Missing HTTP response")
        }

        let payload = try JSONSerialization.jsonObject(with: data, options: [])
        guard let object = payload as? [String: Any] else {
            throw NotionSchemaDumpError.invalidResponse("Payload is not a JSON object")
        }

        guard (200..<300).contains(http.statusCode) else {
            let code = object["code"] as? String ?? "unknown_error"
            let message = object["message"] as? String ?? "status \(http.statusCode)"
            throw NotionSchemaDumpError.apiError("\(code): \(message)")
        }

        return object
    }

    private static func extractDataSourceIDs(from database: [String: Any]) -> [String] {
        guard let dataSources = database["data_sources"] as? [[String: Any]] else {
            return []
        }

        return dataSources.compactMap { source in
            source["id"] as? String
        }
    }

    private static func extractProperties(from dataSource: [String: Any]) -> [NotionPropertySummary] {
        guard let properties = dataSource["properties"] as? [String: [String: Any]] else {
            return []
        }

        return properties.compactMap { name, value in
            guard let type = value["type"] as? String else {
                return nil
            }
            return NotionPropertySummary(name: name, type: type)
        }
    }
}

let semaphore = DispatchSemaphore(value: 0)
var exitCode: Int32 = 0

Task {
    do {
        try await NotionSchemaDumpTool.run()
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exitCode = 1
    }
    semaphore.signal()
}

semaphore.wait()
exit(exitCode)
