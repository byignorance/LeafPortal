import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class PortalMemberDirectoryManager: ObservableObject {
    enum MemberState: String, CaseIterable, Identifiable {
        case active
        case paused
        case disabled

        var id: String { rawValue }

        var title: String {
            switch self {
            case .active:
                return "활성"
            case .paused:
                return "보류"
            case .disabled:
                return "비활성"
            }
        }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case recentSignIn
        case joinedNewest
        case name
        case state

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recentSignIn:
                return "최근 로그인"
            case .joinedNewest:
                return "최근 가입"
            case .name:
                return "이름순"
            case .state:
                return "상태순"
            }
        }
    }

    struct MemberEntry: Identifiable, Equatable {
        let id: String
        let displayName: String
        let email: String
        let photoURL: URL?
        let createdAt: Date?
        let updatedAt: Date?
        let lastSignInAt: Date?
        let isAdmin: Bool
        let memberState: MemberState
        let adminNote: String
    }

    @Published private(set) var members: [MemberEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let database = Firestore.firestore()

    func loadMembers() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snapshot = try await database
                .collection("directoryUsers")
                .order(by: "lastSignInAt", descending: true)
                .getDocuments()

            members = snapshot.documents.map { document in
                let data = document.data()
                let email = (data["email"] as? String) ?? ""
                let state = MemberState(rawValue: (data["memberState"] as? String) ?? "") ?? .active

                return MemberEntry(
                    id: data["uid"] as? String ?? document.documentID,
                    displayName: ((data["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                        ? ((data["displayName"] as? String) ?? "")
                        : "이름 없음",
                    email: email.isEmpty ? "이메일 없음" : email,
                    photoURL: URL(string: (data["photoURL"] as? String) ?? ""),
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
                    lastSignInAt: (data["lastSignInAt"] as? Timestamp)?.dateValue(),
                    isAdmin: (data["isAdmin"] as? Bool) ?? (email.lowercased() == PortalAuthManager.adminEmail),
                    memberState: state,
                    adminNote: ((data["adminNote"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMemberAdminMetadata(
        memberID: String,
        state: MemberState,
        adminNote: String
    ) async throws {
        let note = adminNote.trimmingCharacters(in: .whitespacesAndNewlines)

        var payload: [String: Any] = [
            "memberState": state.rawValue,
            "adminNote": note,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if state == .disabled {
            payload["disabledAt"] = FieldValue.serverTimestamp()
        } else {
            payload["disabledAt"] = FieldValue.delete()
        }

        try await database.collection("directoryUsers").document(memberID).setData(payload, merge: true)

        if let index = members.firstIndex(where: { $0.id == memberID }) {
            let existing = members[index]
            members[index] = MemberEntry(
                id: existing.id,
                displayName: existing.displayName,
                email: existing.email,
                photoURL: existing.photoURL,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                lastSignInAt: existing.lastSignInAt,
                isAdmin: existing.isAdmin,
                memberState: state,
                adminNote: note
            )
        }
    }
}
