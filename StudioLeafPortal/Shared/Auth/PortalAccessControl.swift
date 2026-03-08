import Foundation

struct PortalAccessControlDocument: Equatable {
    var adminUIDs: [String]
    var adminEmails: [String]

    static let bootstrapAdminEmail = "hello@studioleaf.kr"
    static let documentPath = "portalSettings/accessControl"
    static let `default` = PortalAccessControlDocument(adminUIDs: [], adminEmails: [])

    init(adminUIDs: [String], adminEmails: [String]) {
        self.adminUIDs = Array(Set(adminUIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        self.adminEmails = Array(Set(adminEmails.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })).sorted()
    }

    init(dictionary: [String: Any]) {
        self.init(
            adminUIDs: dictionary["adminUIDs"] as? [String] ?? [],
            adminEmails: dictionary["adminEmails"] as? [String] ?? []
        )
    }

    var payload: [String: Any] {
        [
            "adminUIDs": adminUIDs,
            "adminEmails": adminEmails
        ]
    }
}
