import Combine
import FirebaseFirestore
import Foundation
import UniformTypeIdentifiers

@MainActor
final class PortalProjectArchiveManager: ObservableObject {
    struct UploadProgressState: Equatable {
        let provider: ProjectStorageProvider
        let fileName: String
        let fractionCompleted: Double
        let bytesSent: Int64
        let totalBytes: Int64

        var providerTitle: String { provider.title }

        var percentageText: String {
            "\(Int((fractionCompleted * 100).rounded()))%"
        }

        var byteCountText: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "\(formatter.string(fromByteCount: bytesSent)) / \(formatter.string(fromByteCount: totalBytes))"
        }
    }

    private struct GoogleDriveFolderCacheEntry {
        let listing: ProjectGoogleDriveFolderListing
        let fetchedAt: Date
    }
    private struct DropboxFolderCacheEntry {
        let listing: ProjectDropboxFolderListing
        let fetchedAt: Date
    }

    @Published private(set) var archives: [ProjectArchiveSummary] = []
    @Published var selectedArchiveID: String?
    @Published private(set) var isLoadingArchives = false
    @Published private(set) var isSavingArchive = false
    @Published private(set) var isCreatingArchive = false
    @Published private(set) var storageTemplate = ProjectStorageTemplateDocument.default
    @Published private(set) var isLoadingStorageTemplate = false
    @Published private(set) var isSavingStorageTemplate = false
    @Published private(set) var externalStorageAccounts = ProjectExternalStorageAccountsDocument.default
    @Published private(set) var isLoadingExternalStorageAccounts = false
    @Published private(set) var isSavingExternalStorageAccounts = false
    @Published private(set) var isValidatingGoogleDriveAdminSetup = false
    @Published private(set) var isValidatingDropboxAdminSetup = false
    @Published private(set) var isProvisioningGoogleDriveFolders = false
    @Published private(set) var isProvisioningDropboxFolders = false
    @Published private(set) var isLoadingGoogleDriveFolderContents = false
    @Published private(set) var isLoadingDropboxFolderContents = false
    @Published private(set) var isUploadingGoogleDriveFile = false
    @Published private(set) var isUploadingDropboxFile = false
    @Published private(set) var uploadProgress: UploadProgressState?
    @Published private(set) var isDeletingArchive = false
    @Published var bannerMessage: String?
    @Published var errorMessage: String?

    var selectedArchive: ProjectArchiveSummary? {
        guard let selectedArchiveID else { return nil }
        return archives.first(where: { $0.id == selectedArchiveID })
    }

    var connectedChatArchive: ProjectArchiveSummary? {
        guard let selectedProjectID = projectChatManager.selectedProjectID else { return nil }
        return archive(forChatProjectID: selectedProjectID)
    }

    private let authManager: PortalAuthManager
    private let projectChatManager: PortalProjectChatManager
    private let database = Firestore.firestore()
    private let googleDriveListingCacheTTL: TimeInterval = 45
    private let dropboxListingCacheTTL: TimeInterval = 45
    private var cancellables = Set<AnyCancellable>()
    private var archivesListener: ListenerRegistration?
    private var storageTemplateListener: ListenerRegistration?
    private var externalStorageAccountsListener: ListenerRegistration?
    private var googleDriveFolderListingCache: [String: GoogleDriveFolderCacheEntry] = [:]
    private var dropboxFolderListingCache: [String: DropboxFolderCacheEntry] = [:]

    init(authManager: PortalAuthManager, projectChatManager: PortalProjectChatManager) {
        self.authManager = authManager
        self.projectChatManager = projectChatManager

        authManager.$collaborationUserID
            .removeDuplicates()
            .sink { [weak self] userID in
                Task { @MainActor [weak self] in
                    self?.handleAuthenticationChange(userID: userID)
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        archivesListener?.remove()
        storageTemplateListener?.remove()
        externalStorageAccountsListener?.remove()
    }

    var canManageGlobalStorageTemplate: Bool {
        authManager.isAdmin
    }

    func canDeleteArchive(_ archive: ProjectArchiveSummary) -> Bool {
        guard let currentUserID = authManager.currentUser?.id else { return false }
        return archive.ownerID == currentUserID
    }

    func archive(forChatProjectID chatProjectID: String) -> ProjectArchiveSummary? {
        archives.first(where: { $0.chatProjectID == chatProjectID })
    }

    func draft(for archive: ProjectArchiveSummary) -> ProjectArchiveDraft {
        archive.asDraft()
    }

    func newDraft() -> ProjectArchiveDraft {
        var draft = ProjectArchiveDraft.empty
        draft.applyTemplate(storageTemplate)
        return draft
    }

    func saveArchive(_ draft: ProjectArchiveDraft) async {
        guard authManager.currentUser != nil else {
            errorMessage = "\(PortalFeatureNaming.projectHub)를 저장하려면 먼저 로그인해 주세요."
            return
        }

        let trimmedName = draft.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "프로젝트 이름을 입력해 주세요."
            return
        }

        let willCreateArchive = draft.id == nil
        isSavingArchive = true
        errorMessage = nil
        bannerMessage = nil
        if willCreateArchive {
            isCreatingArchive = true
        }

        defer {
            isSavingArchive = false
            if willCreateArchive {
                isCreatingArchive = false
            }
        }

        var resolvedDraft = draft
        resolvedDraft.projectName = trimmedName
        resolvedDraft.projectSummary = draft.projectSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedDraft.projectCode = normalizedProjectCode(from: draft.projectCode)
        resolvedDraft.googleDriveRootFolderID = resolvedDraft.googleDriveRootFolderID?.trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedDraft.googleDriveRootTitle = resolvedDraft.googleDriveRootTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedDraft.googleDriveRootWebURL = resolvedDraft.googleDriveRootWebURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedDraft.dropboxRootPath = resolvedDraft.dropboxRootPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedDraft.dropboxRootTitle = resolvedDraft.dropboxRootTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedDraft.dropboxRootWebURL = resolvedDraft.dropboxRootWebURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        resolvedDraft.storageFolders = sanitizeStorageFolders(resolvedDraft.storageFolders)

        var maybeChatProjectID = resolvedDraft.chatProjectID
        if resolvedDraft.shouldCreateChatProject {
            maybeChatProjectID = await createLinkedChatProjectIfNeeded(for: resolvedDraft)
            guard maybeChatProjectID != nil else {
                isSavingArchive = false
                return
            }
            resolvedDraft.chatProjectID = maybeChatProjectID
            resolvedDraft.shouldCreateChatProject = false
        }

        guard let currentUser = authManager.currentUser else {
            errorMessage = "\(PortalFeatureNaming.projectHub) 저장 중 사용자 정보를 찾지 못했습니다."
            isSavingArchive = false
            return
        }

        let validLinks = resolvedDraft.links.filter { !$0.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let archiveReference: DocumentReference

        if let existingID = resolvedDraft.id {
            archiveReference = database.collection("projectArchives").document(existingID)
        } else {
            archiveReference = database.collection("projectArchives").document()
        }

        let memberIDs = archiveMemberIDs(for: maybeChatProjectID)
        var payload: [String: Any] = [
            "name": resolvedDraft.projectName,
            "summary": resolvedDraft.projectSummary,
            "projectCode": resolvedDraft.projectCode,
            "uploadNamingDefaults": resolvedDraft.namingDefaults.payload,
            "savedWorkGroups": resolvedDraft.savedWorkGroups
                .map { normalizedWorkGroupName(from: $0) }
                .filter { !$0.isEmpty },
            "memberIds": memberIDs,
            "resourceLinks": validLinks.map(\.payload),
            "storageTemplateVersion": max(1, resolvedDraft.storageTemplateVersion),
            "storageFolders": resolvedDraft.storageFolders.map(\.payload),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let notionProjectID = resolvedDraft.notionProjectID,
           let notionTitle = resolvedDraft.notionProjectTitle,
           !notionProjectID.isEmpty {
            payload["notionProjectId"] = notionProjectID
            payload["notionProjectTitle"] = notionTitle
            payload["notionProjectURL"] = resolvedDraft.notionProjectURL ?? ""
        } else {
            payload["notionProjectId"] = NSNull()
            payload["notionProjectTitle"] = NSNull()
            payload["notionProjectURL"] = NSNull()
        }

        if let chatProjectID = maybeChatProjectID, !chatProjectID.isEmpty {
            payload["chatProjectId"] = chatProjectID
        } else {
            payload["chatProjectId"] = NSNull()
        }

        if let googleDriveRootFolderID = normalizedOrNil(resolvedDraft.googleDriveRootFolderID) {
            payload["googleDriveRootFolderId"] = googleDriveRootFolderID
            payload["googleDriveRootTitle"] = normalizedOrNil(resolvedDraft.googleDriveRootTitle) ?? ""
            payload["googleDriveRootWebURL"] = normalizedOrNil(resolvedDraft.googleDriveRootWebURL) ?? ""
        } else {
            payload["googleDriveRootFolderId"] = NSNull()
            payload["googleDriveRootTitle"] = NSNull()
            payload["googleDriveRootWebURL"] = NSNull()
        }

        if let dropboxRootPath = normalizedOrNil(resolvedDraft.dropboxRootPath) {
            payload["dropboxRootPath"] = dropboxRootPath
            payload["dropboxRootTitle"] = normalizedOrNil(resolvedDraft.dropboxRootTitle) ?? ""
            payload["dropboxRootWebURL"] = normalizedOrNil(resolvedDraft.dropboxRootWebURL) ?? ""
        } else {
            payload["dropboxRootPath"] = NSNull()
            payload["dropboxRootTitle"] = NSNull()
            payload["dropboxRootWebURL"] = NSNull()
        }

        do {
            if resolvedDraft.id == nil {
                payload["ownerId"] = currentUser.id
                payload["ownerDisplayName"] = currentUser.displayName
                payload["createdAt"] = FieldValue.serverTimestamp()
                try await archiveReference.setData(payload)

                var preparedTargets: [String] = []
                var provisionErrors: [String] = []
                if await provisionGoogleDriveFolders(for: archiveReference.documentID, suppressSuccessBanner: true) {
                    preparedTargets.append("Google Drive")
                } else {
                    provisionErrors.append("Google Drive")
                }

                if await provisionDropboxFolders(for: archiveReference.documentID, suppressSuccessBanner: true) {
                    preparedTargets.append("Dropbox")
                } else {
                    provisionErrors.append("Dropbox")
                }

                if provisionErrors.isEmpty {
                    bannerMessage = "\(PortalFeatureNaming.projectHub)를 생성하고 \(preparedTargets.joined(separator: ", ")) 폴더를 준비했습니다."
                } else if !preparedTargets.isEmpty {
                    let skipped = provisionErrors.joined(separator: ", ")
                    bannerMessage = "\(PortalFeatureNaming.projectHub)를 생성했습니다. \(preparedTargets.joined(separator: ", "))만 준비했고, \(skipped) 연동은 미완료입니다."
                    errorMessage = "일부 스토리지 연동이 완료되지 않았습니다."
                } else {
                    bannerMessage = "\(PortalFeatureNaming.projectHub)를 생성했습니다."
                }
            } else {
                try await archiveReference.setData(payload, merge: true)
                bannerMessage = "\(PortalFeatureNaming.projectHub)를 저장했습니다."
            }

            selectedArchiveID = archiveReference.documentID
        } catch {
            errorMessage = "\(PortalFeatureNaming.projectHub) 저장에 실패했습니다. \(error.localizedDescription)"
        }
    }

    func saveStorageTemplate(_ template: ProjectStorageTemplateDocument) async {
        guard canManageGlobalStorageTemplate,
              let currentUser = authManager.currentUser else {
            errorMessage = "공통 스토리지 템플릿은 관리자만 저장할 수 있습니다."
            return
        }

        isSavingStorageTemplate = true
        defer { isSavingStorageTemplate = false }
        errorMessage = nil

        let nextTemplate = ProjectStorageTemplateDocument(
            version: max(1, template.version),
            folders: sanitizeStorageFolders(template.folders),
            updatedAt: template.updatedAt,
            updatedByEmail: currentUser.email.lowercased(),
            updatedByName: currentUser.displayName
        )

        do {
            try await database.document(ProjectStoragePolicy.templateDocumentPath).setData(nextTemplate.payload, merge: true)
            storageTemplate = nextTemplate
            bannerMessage = "프로젝트 허브 스토리지 템플릿을 저장했습니다."
        } catch {
            errorMessage = "공통 스토리지 템플릿 저장에 실패했습니다. \(error.localizedDescription)"
        }
    }

    func saveExternalStorageAccounts(_ document: ProjectExternalStorageAccountsDocument) async {
        guard canManageGlobalStorageTemplate,
              let currentUser = authManager.currentUser else {
            errorMessage = "외부 스토리지 계정 설정은 관리자만 저장할 수 있습니다."
            return
        }

        isSavingExternalStorageAccounts = true
        defer { isSavingExternalStorageAccounts = false }

        let nextDocument = ProjectExternalStorageAccountsDocument(
            googleDrive: sanitizedAccountStatus(document.googleDrive),
            dropbox: sanitizedAccountStatus(document.dropbox),
            updatedAt: document.updatedAt,
            updatedByEmail: currentUser.email.lowercased(),
            updatedByName: currentUser.displayName
        )

        do {
            try await database.document(ProjectStoragePolicy.externalAccountsDocumentPath).setData(nextDocument.payload, merge: true)
            bannerMessage = "외부 스토리지 계정 메타 정보를 저장했습니다."
        } catch {
            errorMessage = "외부 스토리지 계정 메타 정보 저장에 실패했습니다. \(error.localizedDescription)"
        }
    }

    func validateGoogleDriveAdminSetup() async {
        guard canManageGlobalStorageTemplate else {
            errorMessage = "Google Drive 연결 검증은 관리자만 실행할 수 있습니다."
            return
        }

        isValidatingGoogleDriveAdminSetup = true
        defer { isValidatingGoogleDriveAdminSetup = false }

        do {
            let result = try await enqueueArchiveJob(
                type: "validateGoogleDriveAdmin",
                archiveID: nil,
                year: nil
            )

            guard
                let sharedDriveName = result["sharedDriveName"] as? String,
                let rootFolderName = result["rootFolderName"] as? String
            else {
                throw ArchiveCallableError.invalidPayload
            }

            bannerMessage = "Google Drive 연결을 확인했습니다. \(sharedDriveName) / \(rootFolderName)"
            errorMessage = nil
        } catch {
            errorMessage = "Google Drive 연결 검증에 실패했습니다. \(callableErrorMessage(from: error))"
        }
    }

    func validateDropboxAdminSetup() async {
        guard canManageGlobalStorageTemplate else {
            errorMessage = "Dropbox 연결 검증은 관리자만 실행할 수 있습니다."
            return
        }

        isValidatingDropboxAdminSetup = true
        defer { isValidatingDropboxAdminSetup = false }

        do {
            let result = try await enqueueArchiveJob(
                type: "validateDropboxAdmin",
                archiveID: nil,
                year: nil
            )

            guard
                let account = result["account"] as? [String: Any],
                let accountEmail = account["email"] as? String
            else {
                throw ArchiveCallableError.invalidPayload
            }

            bannerMessage = "Dropbox 연결을 확인했습니다. \(accountEmail)"
            errorMessage = nil
        } catch {
            errorMessage = "Dropbox 연결 검증에 실패했습니다. \(callableErrorMessage(from: error))"
        }
    }

    func provisionGoogleDriveFolders(
        for archiveID: String,
        year: Int? = nil,
        suppressSuccessBanner: Bool = false
    ) async -> Bool {
        guard !archiveID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "먼저 프로젝트 허브를 저장한 뒤 Google Drive 폴더를 생성해 주세요."
            return false
        }

        isProvisioningGoogleDriveFolders = true
        defer { isProvisioningGoogleDriveFolders = false }

        do {
            let data = try await enqueueArchiveJob(
                type: "provisionGoogleDriveFolders",
                archiveID: archiveID,
                year: year
            )

            guard
                let projectFolderName = data["projectFolderName"] as? String
            else {
                throw ArchiveCallableError.invalidPayload
            }

            if !suppressSuccessBanner {
                bannerMessage = "Google Drive 프로젝트 폴더를 준비했습니다. \(projectFolderName)"
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Google Drive 프로젝트 폴더 생성에 실패했습니다. \(callableErrorMessage(from: error))"
            return false
        }
    }

    func provisionDropboxFolders(
        for archiveID: String,
        year: Int? = nil,
        suppressSuccessBanner: Bool = false
    ) async -> Bool {
        guard !archiveID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "먼저 프로젝트 허브를 저장한 뒤 Dropbox 폴더를 생성해 주세요."
            return false
        }

        isProvisioningDropboxFolders = true
        defer { isProvisioningDropboxFolders = false }

        do {
            let data = try await enqueueArchiveJob(
                type: "provisionDropboxFolders",
                archiveID: archiveID,
                year: year
            )

            guard let projectRootPath = data["projectRootPath"] as? String else {
                throw ArchiveCallableError.invalidPayload
            }

            if !suppressSuccessBanner {
                bannerMessage = "Dropbox 프로젝트 폴더를 준비했습니다. \(projectRootPath)"
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Dropbox 프로젝트 폴더 생성에 실패했습니다. \(callableErrorMessage(from: error))"
            return false
        }
    }

    func deleteArchive(_ archive: ProjectArchiveSummary) async -> Bool {
        guard authManager.currentUser != nil else {
            errorMessage = "\(PortalFeatureNaming.projectHub)를 삭제하려면 먼저 로그인해 주세요."
            return false
        }

        isDeletingArchive = true
        defer { isDeletingArchive = false }

        errorMessage = nil
        var failures: [String] = []

        if archive.googleDriveRootFolderID != nil {
            do {
                _ = try await enqueueArchiveJob(
                    type: "deleteGoogleDriveFolders",
                    archiveID: archive.id,
                    year: nil
                )
            } catch {
                failures.append("Google Drive: \(callableErrorMessage(from: error))")
            }
        }

        if archive.dropboxRootPath != nil {
            do {
                _ = try await enqueueArchiveJob(
                    type: "deleteDropboxFolders",
                    archiveID: archive.id,
                    year: nil
                )
            } catch {
                failures.append("Dropbox: \(callableErrorMessage(from: error))")
            }
        }

        if let chatProjectID = archive.chatProjectID,
           let linkedChatProject = projectChatManager.projects.first(where: { $0.id == chatProjectID }) {
            let deletedChat = await projectChatManager.deleteProject(linkedChatProject)
            if !deletedChat {
                if let chatError = projectChatManager.errorMessage, !chatError.isEmpty {
                    errorMessage = chatError
                } else {
                    errorMessage = "연결된 채팅 프로젝트 삭제에 실패했습니다."
                }
                return false
            }
        }

        do {
            try await database.collection("projectArchives").document(archive.id).delete()
            if selectedArchiveID == archive.id {
                selectedArchiveID = archives.first(where: { $0.id != archive.id })?.id
            }

            if failures.isEmpty {
                bannerMessage = "\(PortalFeatureNaming.projectHub), Google Drive, Dropbox 폴더, 연결 채팅을 삭제했습니다."
            } else {
                errorMessage = "\(PortalFeatureNaming.projectHub) 문서는 삭제되었지만 일부 연동 항목 삭제에 실패했습니다: \(failures.joined(separator: ", "))"
            }
            return true
        } catch {
            errorMessage = "\(PortalFeatureNaming.projectHub) 삭제에 실패했습니다. \(error.localizedDescription)"
            return false
        }
    }

    func googleDriveVisibleFolders(for archive: ProjectArchiveSummary) -> [ProjectStorageFolder] {
        archive.storageFolders
            .filter { $0.provider == .googleDrive }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func dropboxVisibleFolders(for archive: ProjectArchiveSummary) -> [ProjectStorageFolder] {
        archive.storageFolders
            .filter { $0.provider == .dropbox }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func loadGoogleDriveFolderListing(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder,
        forceRefresh: Bool = false
    ) async -> ProjectGoogleDriveFolderListing? {
        guard archive.googleDriveRootFolderID != nil else {
            errorMessage = "Google Drive 프로젝트 폴더가 아직 준비되지 않았습니다."
            return nil
        }

        if !forceRefresh,
           let cachedListing = cachedGoogleDriveFolderListing(archive: archive, folder: folder) {
            return cachedListing
        }

        isLoadingGoogleDriveFolderContents = true
        defer { isLoadingGoogleDriveFolderContents = false }

        do {
            let result = try await enqueueArchiveJob(
                type: "listGoogleDriveFolderContents",
                archiveID: archive.id,
                year: nil,
                extraPayload: [
                    "relativePath": folder.normalizedRelativePath
                ]
            )

            guard let listing = ProjectGoogleDriveFolderListing(
                archiveID: archive.id,
                relativePath: folder.normalizedRelativePath,
                dictionary: result
            ) else {
                throw ArchiveCallableError.invalidPayload
            }

            storeGoogleDriveFolderListingInCache(listing)
            errorMessage = nil
            return listing
        } catch {
            errorMessage = "Google Drive 파일 목록을 불러오지 못했습니다. \(callableErrorMessage(from: error))"
            return nil
        }
    }

    func loadGoogleDriveFolderItemCount(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder
    ) async -> Int? {
        guard archive.googleDriveRootFolderID != nil else {
            return nil
        }

        if let cachedCount = cachedGoogleDriveFolderItemCount(archive: archive, folder: folder) {
            return cachedCount
        }

        do {
            let result = try await enqueueArchiveJob(
                type: "listGoogleDriveFolderContents",
                archiveID: archive.id,
                year: nil,
                extraPayload: [
                    "relativePath": folder.normalizedRelativePath
                ]
            )

            guard let listing = ProjectGoogleDriveFolderListing(
                archiveID: archive.id,
                relativePath: folder.normalizedRelativePath,
                dictionary: result
            ) else {
                return nil
            }

            storeGoogleDriveFolderListingInCache(listing)
            return listing.items.filter { !$0.isFolder }.count
        } catch {
            return nil
        }
    }

    func loadDropboxFolderListing(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder,
        forceRefresh: Bool = false
    ) async -> ProjectDropboxFolderListing? {
        guard archive.dropboxRootPath != nil else {
            errorMessage = "Dropbox 프로젝트 폴더가 아직 준비되지 않았습니다."
            return nil
        }

        if !forceRefresh,
           let cachedListing = cachedDropboxFolderListing(archive: archive, folder: folder) {
            return cachedListing
        }

        isLoadingDropboxFolderContents = true
        defer { isLoadingDropboxFolderContents = false }

        do {
            let result = try await enqueueArchiveJob(
                type: "listDropboxFolderContents",
                archiveID: archive.id,
                year: nil,
                extraPayload: [
                    "relativePath": folder.normalizedRelativePath
                ]
            )

            guard let listing = ProjectDropboxFolderListing(
                archiveID: archive.id,
                relativePath: folder.normalizedRelativePath,
                dictionary: result
            ) else {
                throw ArchiveCallableError.invalidPayload
            }

            storeDropboxFolderListingInCache(listing)
            errorMessage = nil
            return listing
        } catch {
            errorMessage = "Dropbox 파일 목록을 불러오지 못했습니다. \(callableErrorMessage(from: error))"
            return nil
        }
    }

    func loadDropboxFolderItemCount(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder
    ) async -> Int? {
        guard archive.dropboxRootPath != nil else {
            return nil
        }

        if let cachedCount = cachedDropboxFolderItemCount(archive: archive, folder: folder) {
            return cachedCount
        }

        do {
            let result = try await enqueueArchiveJob(
                type: "listDropboxFolderContents",
                archiveID: archive.id,
                year: nil,
                extraPayload: [
                    "relativePath": folder.normalizedRelativePath
                ]
            )

            guard let listing = ProjectDropboxFolderListing(
                archiveID: archive.id,
                relativePath: folder.normalizedRelativePath,
                dictionary: result
            ) else {
                return nil
            }

            storeDropboxFolderListingInCache(listing)
            return listing.items.filter { !$0.isFolder }.count
        } catch {
            return nil
        }
    }

    func uploadFileToGoogleDrive(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder,
        fileURL: URL,
        workGroupName: String,
        renameMode: ProjectUploadRenameMode,
        projectCode: String,
        preset: ProjectUploadPreset?,
        versionMode: ProjectUploadVersionMode,
        dateFormat: ProjectUploadDateFormat,
        sequenceToken: String,
        metadataKeywords: String,
        supplementaryDescription: String
    ) async -> ProjectGoogleDriveUploadResult? {
        guard archive.googleDriveRootFolderID != nil else {
            errorMessage = "Google Drive 프로젝트 폴더가 아직 준비되지 않았습니다."
            return nil
        }

        let mimeType = inferredMimeType(for: fileURL)
        let normalizedWorkGroupName = normalizedWorkGroupName(from: workGroupName)
        let relativePath = resolvedUploadRelativePath(basePath: folder.normalizedRelativePath, workGroupName: normalizedWorkGroupName)
        let fileName = resolvedUploadFileName(
            originalFileURL: fileURL,
            renameMode: renameMode,
            projectCode: projectCode,
            preset: preset,
            versionMode: versionMode,
            dateFormat: dateFormat,
            sequenceToken: sequenceToken
        )

        let fileSize: Int64
        do {
            fileSize = Int64(try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        } catch {
            errorMessage = "업로드 파일 정보를 읽지 못했습니다. \(error.localizedDescription)"
            return nil
        }

        isUploadingGoogleDriveFile = true
        beginUploadProgress(provider: .googleDrive, fileName: fileName, totalBytes: fileSize)
        defer {
            isUploadingGoogleDriveFile = false
            clearUploadProgress()
        }

        do {
            let normalizedKeywords = normalizedKeywordTokens(from: metadataKeywords)
            let normalizedDescription = enrichedUploadDescription(
                supplementaryDescription: supplementaryDescription,
                originalFileName: fileURL.lastPathComponent,
                uploadedFileName: fileName,
                workGroupName: normalizedWorkGroupName,
                preset: preset,
                renameMode: renameMode
            )

            let sessionPayload = try await enqueueArchiveJob(
                type: "createGoogleDriveUploadSession",
                archiveID: archive.id,
                year: nil,
                extraPayload: [
                    "relativePath": relativePath,
                    "fileName": fileName,
                    "mimeType": mimeType,
                    "keywords": normalizedKeywords,
                    "supplementaryDescription": normalizedDescription
                ]
            )

            guard let uploadSession = ProjectGoogleDriveUploadSession(dictionary: sessionPayload),
                  let uploadURL = uploadSession.uploadURL else {
                throw ArchiveCallableError.invalidPayload
            }

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
            request.setValue(String(fileSize), forHTTPHeaderField: "Content-Length")
            if fileSize > 0 {
                request.setValue("bytes 0-\(fileSize - 1)/\(fileSize)", forHTTPHeaderField: "Content-Range")
            }

            let uploader = ArchiveFileUploadClient()
            let (responseData, response) = try await uploader.upload(
                request: request,
                fromFile: fileURL
            ) { [weak self] _, totalBytesSent, totalBytesExpected in
                Task { @MainActor [weak self] in
                    self?.updateUploadProgress(
                        provider: .googleDrive,
                        fileName: fileName,
                        bytesSent: totalBytesSent,
                        totalBytes: max(totalBytesExpected, fileSize)
                    )
                }
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ArchiveCallableError.invalidPayload
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseText = String(data: responseData, encoding: .utf8) ?? "알 수 없는 응답"
                throw ArchiveCallableError.jobFailed(responseText)
            }

            let rawObject = try JSONSerialization.jsonObject(with: responseData)
            guard let rawDictionary = rawObject as? [String: Any],
                  let uploadedFileID = rawDictionary["id"] as? String,
                  let uploadedFileName = rawDictionary["name"] as? String,
                  let uploadedMimeType = rawDictionary["mimeType"] as? String,
                  let webViewLink = rawDictionary["webViewLink"] as? String else {
                throw ArchiveCallableError.invalidPayload
            }

            let uploadResult = ProjectGoogleDriveUploadResult(
                fileID: uploadedFileID,
                fileName: uploadedFileName,
                webViewURLString: webViewLink,
                folderID: uploadSession.folderID,
                folderTitle: uploadSession.folderTitle,
                relativePath: uploadSession.relativePath,
                mimeType: uploadedMimeType,
                iconLink: rawDictionary["iconLink"] as? String,
                thumbnailLink: rawDictionary["thumbnailLink"] as? String,
                size: parseGoogleDriveFileSize(from: rawDictionary["size"]),
                modifiedTime: parseGoogleDriveModifiedTime(from: rawDictionary["modifiedTime"])
            )

            invalidateGoogleDriveFolderListingCache(
                archiveID: archive.id,
                relativePath: folder.normalizedRelativePath
            )
            if !normalizedWorkGroupName.isEmpty {
                await rememberWorkGroup(named: normalizedWorkGroupName, archiveID: archive.id)
            }
            bannerMessage = "\(uploadResult.fileName)을(를) \(folder.title) 폴더에 업로드했습니다."
            errorMessage = nil
            return uploadResult
        } catch {
            errorMessage = "Google Drive 파일 업로드에 실패했습니다. \(callableErrorMessage(from: error))"
            return nil
        }
    }

    func uploadFileToDropbox(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder,
        fileURL: URL,
        workGroupName: String,
        renameMode: ProjectUploadRenameMode,
        projectCode: String,
        preset: ProjectUploadPreset?,
        versionMode: ProjectUploadVersionMode,
        dateFormat: ProjectUploadDateFormat,
        sequenceToken: String,
        metadataKeywords: String,
        supplementaryDescription: String
    ) async -> ProjectDropboxUploadResult? {
        guard folder.provider == .dropbox else {
            errorMessage = "Dropbox로 지정된 폴더에서만 업로드할 수 있습니다."
            return nil
        }
        guard archive.dropboxRootPath != nil else {
            errorMessage = "Dropbox 프로젝트 폴더가 아직 준비되지 않았습니다."
            return nil
        }

        let mimeType = inferredMimeType(for: fileURL)
        let normalizedWorkGroupName = normalizedWorkGroupName(from: workGroupName)
        let relativePath = resolvedUploadRelativePath(basePath: folder.normalizedRelativePath, workGroupName: normalizedWorkGroupName)
        let fileName = resolvedUploadFileName(
            originalFileURL: fileURL,
            renameMode: renameMode,
            projectCode: projectCode,
            preset: preset,
            versionMode: versionMode,
            dateFormat: dateFormat,
            sequenceToken: sequenceToken
        )
        let uploadFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if uploadFileName.isEmpty {
            errorMessage = "업로드할 파일명이 비어 있습니다."
            return nil
        }

        let fileSize: Int64
        do {
            fileSize = Int64(try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        } catch {
            errorMessage = "업로드 파일 정보를 읽지 못했습니다. \(error.localizedDescription)"
            return nil
        }

        isUploadingDropboxFile = true
        beginUploadProgress(provider: .dropbox, fileName: uploadFileName, totalBytes: fileSize)
        defer {
            isUploadingDropboxFile = false
            clearUploadProgress()
        }

        do {
            let normalizedKeywords = normalizedKeywordTokens(from: metadataKeywords)
            let normalizedDescription = enrichedUploadDescription(
                supplementaryDescription: supplementaryDescription,
                originalFileName: fileURL.lastPathComponent,
                uploadedFileName: uploadFileName,
                workGroupName: normalizedWorkGroupName,
                preset: preset,
                renameMode: renameMode
            )

            let sessionPayload = try await enqueueArchiveJob(
                type: "createDropboxUploadSession",
                archiveID: archive.id,
                year: nil,
                extraPayload: [
                    "relativePath": relativePath,
                    "fileName": uploadFileName,
                    "keywords": normalizedKeywords,
                    "supplementaryDescription": normalizedDescription,
                ]
            )

            guard let session = ProjectDropboxUploadSession(dictionary: sessionPayload) else {
                throw ArchiveCallableError.invalidPayload
            }

            let apiArg: [String: Any] = [
                "path": session.uploadPath,
                "mode": [".tag": "add"],
                "autorename": true,
                "mute": false,
            ]

            guard let uploadURL = URL(string: "https://content.dropboxapi.com/2/files/upload") else {
                throw ArchiveCallableError.invalidPayload
            }

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue(try makeDropboxAPIArgHeaderValue(from: apiArg), forHTTPHeaderField: "Dropbox-API-Arg")
            if let pathRootHeader = session.pathRootHeader, !pathRootHeader.isEmpty {
                request.setValue(pathRootHeader, forHTTPHeaderField: "Dropbox-API-Path-Root")
            }

            let uploader = ArchiveFileUploadClient()
            let (responseData, response) = try await uploader.upload(
                request: request,
                fromFile: fileURL
            ) { [weak self] _, totalBytesSent, totalBytesExpected in
                Task { @MainActor [weak self] in
                    self?.updateUploadProgress(
                        provider: .dropbox,
                        fileName: uploadFileName,
                        bytesSent: totalBytesSent,
                        totalBytes: max(totalBytesExpected, fileSize)
                    )
                }
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ArchiveCallableError.invalidPayload
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                let responseText = String(data: responseData, encoding: .utf8) ?? "알 수 없는 응답"
                throw ArchiveCallableError.jobFailed(responseText)
            }

            let rawObject = try JSONSerialization.jsonObject(with: responseData)
            guard let rawDictionary = rawObject as? [String: Any],
                  let uploadedFileID = rawDictionary["id"] as? String,
                  let uploadedFileName = rawDictionary["name"] as? String else {
                throw ArchiveCallableError.invalidPayload
            }

            let uploadResult = ProjectDropboxUploadResult(
                fileID: uploadedFileID,
                fileName: uploadedFileName,
                webViewURLString: session.webViewLink,
                folderPath: session.folderPath,
                folderTitle: session.folderTitle,
                relativePath: session.relativePath,
                mimeType: mimeType,
                size: parseDropboxSize(from: rawDictionary["size"]),
                modifiedTime: parseDropboxModifiedTime(from: rawDictionary["server_modified"] ?? rawDictionary["client_modified"])
            )

            invalidateDropboxFolderListingCache(
                archiveID: archive.id,
                relativePath: folder.normalizedRelativePath
            )
            if !normalizedWorkGroupName.isEmpty {
                await rememberWorkGroup(named: normalizedWorkGroupName, archiveID: archive.id)
            }
            bannerMessage = "\(uploadResult.fileName)을(를) \(folder.title) 폴더에 업로드했습니다."
            errorMessage = nil
            return uploadResult
        } catch {
            errorMessage = "Dropbox 파일 업로드에 실패했습니다. \(callableErrorMessage(from: error))"
            return nil
        }
    }

    private func normalizedKeywordTokens(from value: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n")
        return value
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, token in
                if !result.contains(token) {
                    result.append(token)
                }
            }
    }

    private func normalizedProjectCode(from value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined()
    }

    private func normalizedWorkGroupName(from value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: "/\\"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private func resolvedUploadRelativePath(basePath: String, workGroupName: String) -> String {
        guard !workGroupName.isEmpty else {
            return basePath
        }
        return [basePath, workGroupName]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    private func rememberWorkGroup(named value: String, archiveID: String) async {
        let normalizedValue = normalizedWorkGroupName(from: value)
        guard !normalizedValue.isEmpty else { return }
        do {
            try await database.collection("projectArchives").document(archiveID).setData(
                ["savedWorkGroups": FieldValue.arrayUnion([normalizedValue])],
                merge: true
            )
        } catch {
            // Keep upload success path intact even if suggestion persistence fails.
        }
    }

    func previewUploadFileName(
        originalFileURL: URL,
        renameMode: ProjectUploadRenameMode,
        projectCode: String,
        preset: ProjectUploadPreset?,
        versionMode: ProjectUploadVersionMode,
        dateFormat: ProjectUploadDateFormat,
        sequenceToken: String
    ) -> String {
        resolvedUploadFileName(
            originalFileURL: originalFileURL,
            renameMode: renameMode,
            projectCode: projectCode,
            preset: preset,
            versionMode: versionMode,
            dateFormat: dateFormat,
            sequenceToken: sequenceToken
        )
    }

    private func resolvedUploadFileName(
        originalFileURL: URL,
        renameMode: ProjectUploadRenameMode,
        projectCode: String,
        preset: ProjectUploadPreset?,
        versionMode: ProjectUploadVersionMode,
        dateFormat: ProjectUploadDateFormat,
        sequenceToken: String
    ) -> String {
        let originalFileName = originalFileURL.lastPathComponent
        guard renameMode == .applyNamingRule,
              let preset else {
            return originalFileName
        }

        let sanitizedProjectCode = normalizedProjectCode(from: projectCode)
        guard !sanitizedProjectCode.isEmpty else {
            return originalFileName
        }

        let token: String
        switch versionMode {
        case .dateBased:
            token = formattedDateToken(from: Date(), format: dateFormat)
        case .sequenceBased:
            let sanitized = sequenceToken
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined()
            token = sanitized.isEmpty ? "v01" : sanitized
        }

        let stem: String
        if preset.category == .edit {
            stem = [preset.rawValue, sanitizedProjectCode, token].joined(separator: "_")
        } else {
            stem = [sanitizedProjectCode, preset.rawValue, token].joined(separator: "_")
        }

        let fileExtension = originalFileURL.pathExtension
        return fileExtension.isEmpty ? stem : "\(stem).\(fileExtension)"
    }

    private func formattedDateToken(from date: Date, format: ProjectUploadDateFormat) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = format == .mmdd ? "MMdd" : "yyMMdd"
        return formatter.string(from: date)
    }

    private func enrichedUploadDescription(
        supplementaryDescription: String,
        originalFileName: String,
        uploadedFileName: String,
        workGroupName: String,
        preset: ProjectUploadPreset?,
        renameMode: ProjectUploadRenameMode
    ) -> String {
        var lines: [String] = []
        let trimmedDescription = supplementaryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty {
            lines.append(trimmedDescription)
        }
        lines.append("originalFileName: \(originalFileName)")
        lines.append("uploadedFileName: \(uploadedFileName)")
        if !workGroupName.isEmpty {
            lines.append("workGroup: \(workGroupName)")
        }
        if let preset {
            lines.append("preset: \(preset.rawValue)")
        }
        lines.append("renameRuleApplied: \(renameMode == .applyNamingRule ? "true" : "false")")
        return lines.joined(separator: "\n")
    }

    private func makeDropboxAPIArgHeaderValue(from object: [String: Any]) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ArchiveCallableError.invalidPayload
        }

        var result = ""
        result.reserveCapacity(jsonString.count)

        for scalar in jsonString.unicodeScalars {
            if scalar.isASCII {
                result.unicodeScalars.append(scalar)
                continue
            }

            let value = scalar.value
            if value <= 0xFFFF {
                result.append(String(format: "\\u%04X", value))
            } else {
                let base = value - 0x10000
                let high = 0xD800 + (base >> 10)
                let low = 0xDC00 + (base & 0x3FF)
                result.append(String(format: "\\u%04X\\u%04X", high, low))
            }
        }

        return result
    }

    private func parseGoogleDriveFileSize(from value: Any?) -> Int64? {
        if let sizeValue = value as? Int64 {
            return sizeValue
        }
        if let sizeValue = value as? Double {
            return Int64(sizeValue)
        }
        if let sizeValue = value as? String {
            return Int64(sizeValue)
        }
        if let sizeValue = value as? NSNumber {
            return sizeValue.int64Value
        }
        return nil
    }

    private func parseGoogleDriveModifiedTime(from value: Any?) -> Date? {
        guard let rawValue = value as? String else {
            return nil
        }
        if let date = iso8601DateFormatterWithFractional.date(from: rawValue) {
            return date
        }
        return iso8601DateFormatterWithoutFractional.date(from: rawValue)
    }

    private func parseDropboxSize(from value: Any?) -> Int64? {
        if let sizeValue = value as? Int64 {
            return sizeValue
        }
        if let sizeValue = value as? Double {
            return Int64(sizeValue)
        }
        if let sizeValue = value as? Int {
            return Int64(sizeValue)
        }
        if let sizeValue = value as? String {
            return Int64(sizeValue)
        }
        if let sizeValue = value as? NSNumber {
            return sizeValue.int64Value
        }
        return nil
    }

    private func parseDropboxModifiedTime(from value: Any?) -> Date? {
        guard let rawValue = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: rawValue) {
            return date
        }
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        return fallbackFormatter.date(from: rawValue)
    }

    private var iso8601DateFormatterWithFractional: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private var iso8601DateFormatterWithoutFractional: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    private func createLinkedChatProjectIfNeeded(for draft: ProjectArchiveDraft) async -> String? {
        guard let chatProjectID = await projectChatManager.createProject(
            name: draft.projectName,
            summary: draft.projectSummary,
            inviteEmailsRaw: "",
            shouldCreateDefaultRoom: true,
            autoSelectAfterCreate: false,
            trackProgress: false
        ) else {
            errorMessage = "연결된 \(PortalFeatureNaming.teamMessenger) 프로젝트를 생성하지 못했습니다."
            return nil
        }

        return chatProjectID
    }

    private func archiveMemberIDs(for chatProjectID: String?) -> [String] {
        guard let chatProjectID,
              let project = projectChatManager.projects.first(where: { $0.id == chatProjectID }) else {
            return [ownerID]
        }

        return project.memberIDs
    }

    private var ownerID: String {
        authManager.currentUser?.id ?? ""
    }

    private func handleAuthenticationChange(userID: String?) {
        archivesListener?.remove()
        storageTemplateListener?.remove()
        externalStorageAccountsListener?.remove()
        archives = []
        selectedArchiveID = nil
        isLoadingArchives = false
        storageTemplate = .default
        externalStorageAccounts = .default
        googleDriveFolderListingCache.removeAll()
        dropboxFolderListingCache.removeAll()

        guard let userID else {
            return
        }

        subscribeArchives(for: userID)
        subscribeStorageTemplate()
        subscribeExternalStorageAccounts()
    }

    private func subscribeArchives(for userID: String) {
        isLoadingArchives = true

        archivesListener = database
            .collection("projectArchives")
            .whereField("memberIds", arrayContains: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = "\(PortalFeatureNaming.projectHub) 목록을 불러오지 못했습니다. \(error.localizedDescription)"
                        self.isLoadingArchives = false
                        return
                    }

                    let nextArchives = snapshot?.documents
                        .compactMap(ProjectArchiveSummary.init(document:))
                        .sorted { $0.updatedAt > $1.updatedAt } ?? []

                    self.archives = nextArchives
                    if let selectedArchiveID = self.selectedArchiveID,
                       !nextArchives.contains(where: { $0.id == selectedArchiveID }) {
                        self.selectedArchiveID = nextArchives.first?.id
                    } else if self.selectedArchiveID == nil {
                        self.selectedArchiveID = nextArchives.first?.id
                    }

                    self.isLoadingArchives = false
                }
            }
    }

    private func subscribeStorageTemplate() {
        isLoadingStorageTemplate = true

        storageTemplateListener = database
            .document(ProjectStoragePolicy.templateDocumentPath)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = "공통 스토리지 템플릿을 불러오지 못했습니다. \(error.localizedDescription)"
                        self.isLoadingStorageTemplate = false
                        return
                    }

                    let data = snapshot?.data() ?? [:]
                    self.storageTemplate = snapshot?.exists == true
                        ? ProjectStorageTemplateDocument(dictionary: data)
                        : .default
                    self.isLoadingStorageTemplate = false
                }
            }
    }

    private func subscribeExternalStorageAccounts() {
        isLoadingExternalStorageAccounts = true

        externalStorageAccountsListener = database
            .document(ProjectStoragePolicy.externalAccountsDocumentPath)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = "외부 스토리지 계정 상태를 불러오지 못했습니다. \(error.localizedDescription)"
                        self.isLoadingExternalStorageAccounts = false
                        return
                    }

                    let data = snapshot?.data() ?? [:]
                    self.externalStorageAccounts = snapshot?.exists == true
                        ? ProjectExternalStorageAccountsDocument(dictionary: data)
                        : .default
                    self.isLoadingExternalStorageAccounts = false
                }
            }
    }

    private func sanitizeStorageFolders(_ folders: [ProjectStorageFolder]) -> [ProjectStorageFolder] {
        let source = folders.isEmpty ? ProjectStorageFolder.default : folders
        return source.enumerated().map { index, folder in
            ProjectStorageFolder(
                id: folder.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "folder-\(index)" : folder.id.trimmingCharacters(in: .whitespacesAndNewlines),
                title: folder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "폴더 \(index + 1)" : folder.title.trimmingCharacters(in: .whitespacesAndNewlines),
                provider: folder.provider,
                relativePath: folder.normalizedRelativePath.isEmpty ? "folder-\(index + 1)" : folder.normalizedRelativePath,
                keywords: folder.keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                sortOrder: folder.sortOrder,
                isRequired: folder.isRequired
            )
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func normalizedOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    func cachedGoogleDriveFolderListing(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder
    ) -> ProjectGoogleDriveFolderListing? {
        let key = googleDriveFolderCacheKey(
            archiveID: archive.id,
            relativePath: folder.normalizedRelativePath
        )
        guard let entry = googleDriveFolderListingCache[key] else {
            return nil
        }
        guard Date().timeIntervalSince(entry.fetchedAt) <= googleDriveListingCacheTTL else {
            googleDriveFolderListingCache[key] = nil
            return nil
        }
        return entry.listing
    }

    func cachedGoogleDriveFolderItemCount(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder
    ) -> Int? {
        cachedGoogleDriveFolderListing(archive: archive, folder: folder)?
            .items
            .filter { !$0.isFolder }
            .count
    }

    func cachedDropboxFolderListing(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder
    ) -> ProjectDropboxFolderListing? {
        let key = dropboxFolderCacheKey(
            archiveID: archive.id,
            relativePath: folder.normalizedRelativePath
        )
        guard let entry = dropboxFolderListingCache[key] else {
            return nil
        }
        guard Date().timeIntervalSince(entry.fetchedAt) <= dropboxListingCacheTTL else {
            dropboxFolderListingCache[key] = nil
            return nil
        }
        return entry.listing
    }

    func cachedDropboxFolderItemCount(
        archive: ProjectArchiveSummary,
        folder: ProjectStorageFolder
    ) -> Int? {
        cachedDropboxFolderListing(archive: archive, folder: folder)?
            .items
            .filter { !$0.isFolder }
            .count
    }

    func invalidateGoogleDriveFolderListingCache(
        archiveID: String,
        relativePath: String? = nil
    ) {
        if let relativePath {
            googleDriveFolderListingCache[
                googleDriveFolderCacheKey(archiveID: archiveID, relativePath: relativePath)
            ] = nil
            return
        }

        googleDriveFolderListingCache = googleDriveFolderListingCache.filter { key, _ in
            !key.hasPrefix("\(archiveID)|")
        }
    }

    func invalidateDropboxFolderListingCache(
        archiveID: String,
        relativePath: String? = nil
    ) {
        if let relativePath {
            dropboxFolderListingCache[
                dropboxFolderCacheKey(archiveID: archiveID, relativePath: relativePath)
            ] = nil
            return
        }

        dropboxFolderListingCache = dropboxFolderListingCache.filter { key, _ in
            !key.hasPrefix("\(archiveID)|")
        }
    }

    private func storeGoogleDriveFolderListingInCache(_ listing: ProjectGoogleDriveFolderListing) {
        googleDriveFolderListingCache[
            googleDriveFolderCacheKey(
                archiveID: listing.archiveID,
                relativePath: listing.relativePath
            )
        ] = GoogleDriveFolderCacheEntry(
            listing: listing,
            fetchedAt: Date()
        )
    }

    private func storeDropboxFolderListingInCache(_ listing: ProjectDropboxFolderListing) {
        dropboxFolderListingCache[
            dropboxFolderCacheKey(
                archiveID: listing.archiveID,
                relativePath: listing.relativePath
            )
        ] = DropboxFolderCacheEntry(
            listing: listing,
            fetchedAt: Date()
        )
    }

    private func googleDriveFolderCacheKey(archiveID: String, relativePath: String) -> String {
        "\(archiveID)|\(relativePath)"
    }

    private func dropboxFolderCacheKey(archiveID: String, relativePath: String) -> String {
        "\(archiveID)|\(relativePath)"
    }

    private func sanitizedAccountStatus(_ status: ProjectStorageProviderAccountStatus) -> ProjectStorageProviderAccountStatus {
        ProjectStorageProviderAccountStatus(
            provider: status.provider,
            executionEmail: normalizedOrNil(status.executionEmail) ?? ProjectStoragePolicy.operatorEmail,
            accountLabel: normalizedOrNil(status.accountLabel) ?? "",
            connectionState: status.connectionState,
            notes: normalizedOrNil(status.notes) ?? "",
            lastValidatedAt: status.lastValidatedAt
        )
    }

    private func enqueueArchiveJob(
        type: String,
        archiveID: String?,
        year: Int?,
        extraPayload: [String: Any] = [:],
        timeoutNanoseconds: UInt64 = 60_000_000_000
    ) async throws -> [String: Any] {
        guard let currentUser = authManager.currentUser else {
            throw ArchiveCallableError.notSignedIn
        }

        let jobReference = database.collection("projectArchiveJobs").document()
        var payload: [String: Any] = [
            "type": type,
            "requestedById": currentUser.id,
            "requestedByEmail": currentUser.email.lowercased(),
            "status": "queued",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let archiveID {
            payload["archiveId"] = archiveID
        }
        if let year {
            payload["year"] = year
        }
        for (key, value) in extraPayload {
            payload[key] = value
        }

        try await jobReference.setData(payload)
        return try await waitForArchiveJobCompletion(
            jobReference,
            timeoutNanoseconds: timeoutNanoseconds
        )
    }

    private func waitForArchiveJobCompletion(
        _ jobReference: DocumentReference,
        timeoutNanoseconds: UInt64 = 60_000_000_000,
        pollIntervalNanoseconds: UInt64 = 600_000_000
    ) async throws -> [String: Any] {
        let startedAt = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - startedAt < timeoutNanoseconds {
            let snapshot = try await jobReference.getDocument()
            let data = snapshot.data() ?? [:]
            let status = data["status"] as? String ?? "queued"

            switch status {
            case "completed":
                return data["result"] as? [String: Any] ?? [:]
            case "failed":
                throw ArchiveCallableError.jobFailed(data["errorMessage"] as? String ?? "Google Drive 작업이 실패했습니다.")
            default:
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }
        }

        throw ArchiveCallableError.jobTimedOut
    }

    private func callableErrorMessage(from error: Error) -> String {
        if case let ArchiveCallableError.jobFailed(message) = error {
            return message
        }
        switch error {
        case ArchiveCallableError.invalidPayload:
            return "응답 형식을 읽지 못했습니다."
        case ArchiveCallableError.notSignedIn:
            return "로그인이 필요합니다."
        case ArchiveCallableError.jobTimedOut:
            return "작업 시간이 초과되었습니다. 잠시 뒤 다시 확인해 주세요."
        default:
            return error.localizedDescription
        }
    }

    private func inferredMimeType(for fileURL: URL) -> String {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let mimeType = type.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }

    private func beginUploadProgress(provider: ProjectStorageProvider, fileName: String, totalBytes: Int64) {
        let safeTotal = max(totalBytes, 1)
        uploadProgress = UploadProgressState(
            provider: provider,
            fileName: fileName,
            fractionCompleted: 0,
            bytesSent: 0,
            totalBytes: safeTotal
        )
    }

    private func updateUploadProgress(
        provider: ProjectStorageProvider,
        fileName: String,
        bytesSent: Int64,
        totalBytes: Int64
    ) {
        let safeTotal = max(totalBytes, 1)
        let clampedSent = min(max(bytesSent, 0), safeTotal)
        uploadProgress = UploadProgressState(
            provider: provider,
            fileName: fileName,
            fractionCompleted: Double(clampedSent) / Double(safeTotal),
            bytesSent: clampedSent,
            totalBytes: safeTotal
        )
    }

    private func clearUploadProgress() {
        uploadProgress = nil
    }

}

private final class ArchiveFileUploadClient: NSObject, URLSessionTaskDelegate {
    private var progressHandlers: [String: @Sendable (Int64, Int64, Int64) -> Void] = [:]

    func upload(
        request: URLRequest,
        fromFile fileURL: URL,
        progress: @escaping @Sendable (Int64, Int64, Int64) -> Void
    ) async throws -> (Data, URLResponse) {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { continuation in
            let uploadID = UUID().uuidString
            let task = session.uploadTask(with: request, fromFile: fileURL) { [weak self] data, response, error in
                defer { session.finishTasksAndInvalidate() }
                self?.progressHandlers[uploadID] = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let response else {
                    continuation.resume(throwing: ArchiveCallableError.invalidPayload)
                    return
                }

                continuation.resume(returning: (data, response))
            }

            task.taskDescription = uploadID
            progressHandlers[uploadID] = progress
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard let uploadID = task.taskDescription else { return }
        progressHandlers[uploadID]?(bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }
}

private enum ArchiveCallableError: Error {
    case invalidPayload
    case notSignedIn
    case jobTimedOut
    case jobFailed(String)
}
