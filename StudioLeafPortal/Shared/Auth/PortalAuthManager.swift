import AppKit
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn

@MainActor
final class PortalAuthManager: ObservableObject {
    static let adminEmail = PortalAccessControlDocument.bootstrapAdminEmail

    struct SessionUser: Equatable, Identifiable {
        let id: String
        let displayName: String
        let email: String
        let photoURL: URL?
        let isAdmin: Bool

        var initials: String {
            let source = displayName.isEmpty ? email : displayName
            let parts = source.split(separator: " ")
            let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
            if !letters.isEmpty {
                return letters.uppercased()
            }
            return String(source.prefix(1)).uppercased()
        }
    }

    enum Status: Equatable {
        case signedOut
        case signingIn
        case signedIn
    }

    enum CollaborationAccessState: Equatable {
        case signedOut
        case pendingMemberRecord
        case active
        case paused
        case disabled
    }

    @Published private(set) var currentUser: SessionUser?
    @Published private(set) var status: Status = .signedOut
    @Published private(set) var statusLine = "로컬 설정만 사용 중"
    @Published private(set) var detailLine = "로그인하면 설정을 클라우드에 동기화할 수 있습니다."
    @Published private(set) var collaborationAccessState: CollaborationAccessState = .signedOut
    @Published private(set) var collaborationUserID: String?
    @Published var errorMessage: String?

    private let database = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var directoryStateListener: ListenerRegistration?
    private var accessControlListener: ListenerRegistration?
    private var accessControl = PortalAccessControlDocument.default
    private var portalAdminClaim = false

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.handleAuthStateChanged(user)
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
        directoryStateListener?.remove()
        accessControlListener?.remove()
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    var isAdmin: Bool {
        currentUser?.isAdmin == true
    }

    var canAccessCollaboration: Bool {
        collaborationAccessState == .active && collaborationUserID != nil
    }

    var collaborationStatusLine: String {
        switch collaborationAccessState {
        case .signedOut:
            return "Firebase 로그인이 필요합니다."
        case .pendingMemberRecord:
            return "회원 상태를 확인하는 중입니다."
        case .active:
            return "협업 기능을 사용할 수 있습니다."
        case .paused:
            return "협업 기능이 보류 상태입니다."
        case .disabled:
            return "협업 기능이 비활성 상태입니다."
        }
    }

    func collaborationAccessDetail(for featureName: String) -> String {
        switch collaborationAccessState {
        case .signedOut:
            return "\(featureName)는 Firebase 로그인 후 사용할 수 있습니다."
        case .pendingMemberRecord:
            return "현재 계정의 협업 권한을 확인하는 중입니다. 회원 상태 동기화가 끝나면 \(featureName) 접근 여부가 결정됩니다."
        case .active:
            return "\(featureName)를 사용할 수 있습니다."
        case .paused:
            return "현재 계정은 협업 기능 보류 상태입니다. 관리자에게 \(featureName) 접근 권한 재활성화를 요청해 주세요."
        case .disabled:
            return "현재 계정은 협업 기능이 비활성 상태입니다. \(featureName)에 접근할 수 없습니다."
        }
    }

    func signIn() async {
        guard status != .signingIn else { return }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase client ID를 읽지 못했습니다."
            return
        }
        guard let presentingWindow = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first else {
            errorMessage = "로그인 창을 띄울 메인 창을 찾지 못했습니다."
            return
        }

        errorMessage = nil
        status = .signingIn
        statusLine = "Google 로그인 진행 중"
        detailLine = "브라우저 인증이 끝나면 포털 계정으로 연결됩니다."

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow)
            let googleUser = signInResult.user

            guard let idToken = googleUser.idToken?.tokenString else {
                throw PortalAuthError.missingIDToken
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: googleUser.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            try await upsertUserProfile(for: authResult.user)

            status = .signedIn
            statusLine = "클라우드 계정 연결됨"
            detailLine = "설정 동기화를 시작할 수 있습니다."
        } catch {
            status = .signedOut
            statusLine = "로그인 실패"
            detailLine = "Google 로그인 연결이 완료되지 않았습니다."
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    func signOut() {
        errorMessage = nil
        GIDSignIn.sharedInstance.signOut()

        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    func handleRedirectURL(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    func updateSyncStatus(state: PortalCloudSyncCoordinator.SyncState) {
        switch state {
        case .idle:
            if currentUser == nil {
                statusLine = "로컬 설정만 사용 중"
                detailLine = "로그인하면 설정을 클라우드에 동기화할 수 있습니다."
            } else {
                statusLine = "계정 연결됨"
                detailLine = "동기화를 시작할 준비가 되었습니다."
            }
        case .pendingChanges:
            statusLine = "동기화 대기 중"
            detailLine = "변경 사항이 있어 다음 동기화 주기에 클라우드로 저장됩니다."
        case .syncing:
            statusLine = "클라우드 동기화 중"
            detailLine = "현재 장치 설정을 계정과 맞추는 중입니다."
        case .synced(let date):
            statusLine = "클라우드 동기화 완료"
            detailLine = "\(date.formatted(date: .omitted, time: .shortened)) 기준으로 모든 설정이 저장되었습니다."
        case .failed(let message):
            statusLine = "동기화 오류"
            detailLine = message
        }
    }

    private func handleAuthStateChanged(_ user: FirebaseAuth.User?) {
        guard let user else {
            directoryStateListener?.remove()
            accessControlListener?.remove()
            currentUser = nil
            status = .signedOut
            statusLine = "로컬 설정만 사용 중"
            detailLine = "로그인하면 설정을 클라우드에 동기화할 수 있습니다."
            collaborationAccessState = .signedOut
            collaborationUserID = nil
            portalAdminClaim = false
            accessControl = .default
            return
        }

        refreshCurrentUserSnapshot(from: user)

        if status != .signingIn {
            status = .signedIn
            statusLine = "계정 연결됨"
            detailLine = "클라우드 설정 동기화를 준비했습니다."
        }

        subscribeAccessControl()
        subscribeDirectoryState(for: user.uid)
        Task { [weak self] in
            await self?.refreshPortalAdminClaim(for: user)
        }
    }

    private func upsertUserProfile(for user: FirebaseAuth.User) async throws {
        let profileReference = database
            .collection("users")
            .document(user.uid)
            .collection("profile")
            .document("main")
        let directoryReference = database
            .collection("directoryUsers")
            .document(user.uid)

        let existingSnapshot = try await profileReference.getDocument()

        var data: [String: Any] = [
            "uid": user.uid,
            "displayName": user.displayName ?? "",
            "email": user.email ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "providers": user.providerData.map(\.providerID),
            "lastSignInAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if !existingSnapshot.exists {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        try await profileReference.setData(data, merge: true)

        var directoryData: [String: Any] = [
            "uid": user.uid,
            "displayName": user.displayName ?? "",
            "email": user.email ?? "",
            "emailLowercased": (user.email ?? "").lowercased(),
            "photoURL": user.photoURL?.absoluteString ?? "",
            "isAdmin": effectiveAdminStatus(uid: user.uid, email: user.email ?? ""),
            "lastSignInAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if !existingSnapshot.exists {
            directoryData["createdAt"] = FieldValue.serverTimestamp()
            directoryData["memberState"] = "active"
            directoryData["adminNote"] = ""
        }

        try await directoryReference.setData(directoryData, merge: true)
    }

    private func subscribeAccessControl() {
        accessControlListener?.remove()
        accessControl = .default

        accessControlListener = database.document(PortalAccessControlDocument.documentPath)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let data = snapshot?.data() {
                        self.accessControl = PortalAccessControlDocument(dictionary: data)
                    } else {
                        self.accessControl = .default
                    }

                    self.refreshCurrentUserSnapshot(from: Auth.auth().currentUser)
                    await self.syncCurrentDirectoryAdminFlagIfNeeded()
                }
            }
    }

    private func subscribeDirectoryState(for userID: String) {
        directoryStateListener?.remove()
        collaborationAccessState = .pendingMemberRecord
        collaborationUserID = nil

        directoryStateListener = database
            .collection("directoryUsers")
            .document(userID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if error != nil {
                        self.collaborationAccessState = .pendingMemberRecord
                        self.collaborationUserID = nil
                        return
                    }

                    guard let snapshot, snapshot.exists else {
                        self.collaborationAccessState = .pendingMemberRecord
                        self.collaborationUserID = nil
                        return
                    }

                    let rawState = snapshot.data()?["memberState"] as? String
                    let memberState = PortalMemberDirectoryManager.MemberState(rawValue: rawState ?? "active") ?? .active

                    switch memberState {
                    case .active:
                        self.collaborationAccessState = .active
                        self.collaborationUserID = userID
                    case .paused:
                        self.collaborationAccessState = .paused
                        self.collaborationUserID = nil
                    case .disabled:
                        self.collaborationAccessState = .disabled
                        self.collaborationUserID = nil
                    }
                }
            }
    }

    private func refreshCurrentUserSnapshot(from user: FirebaseAuth.User?) {
        guard let user else {
            currentUser = nil
            return
        }

        currentUser = SessionUser(
            id: user.uid,
            displayName: user.displayName ?? "studioLEAF 사용자",
            email: user.email ?? "이메일 없음",
            photoURL: user.photoURL,
            isAdmin: effectiveAdminStatus(uid: user.uid, email: user.email ?? "")
        )
    }

    private func effectiveAdminStatus(uid: String, email: String) -> Bool {
        let normalizedEmail = email.lowercased()
        return portalAdminClaim
            || normalizedEmail == Self.adminEmail
            || accessControl.adminUIDs.contains(uid)
            || accessControl.adminEmails.contains(normalizedEmail)
    }

    private func refreshPortalAdminClaim(for user: FirebaseAuth.User) async {
        do {
            let tokenResult = try await user.getIDTokenResult()
            portalAdminClaim = (tokenResult.claims["portalAdmin"] as? Bool) == true
        } catch {
            portalAdminClaim = false
        }

        refreshCurrentUserSnapshot(from: user)
        await syncCurrentDirectoryAdminFlagIfNeeded()
    }

    private func syncCurrentDirectoryAdminFlagIfNeeded() async {
        guard let user = Auth.auth().currentUser else { return }

        let desiredAdminState = effectiveAdminStatus(uid: user.uid, email: user.email ?? "")
        let reference = database.collection("directoryUsers").document(user.uid)

        do {
            let snapshot = try await reference.getDocument()
            let existingAdminState = snapshot.data()?["isAdmin"] as? Bool ?? false

            guard existingAdminState != desiredAdminState else { return }

            try await reference.setData([
                "isAdmin": desiredAdminState,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            return
        }
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        if let error = error as NSError?, error.code == GIDSignInError.canceled.rawValue {
            return "Google 로그인이 취소되었습니다."
        }

        switch error {
        case PortalAuthError.missingIDToken:
            return "Google 계정 토큰을 읽지 못했습니다."
        default:
            return error.localizedDescription
        }
    }
}

private enum PortalAuthError: LocalizedError {
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .missingIDToken:
            return "Google ID 토큰이 비어 있습니다."
        }
    }
}
