import SwiftUI

struct PortalProjectArchiveTemplateSettingsSheet: View {
    @ObservedObject var manager: PortalProjectArchiveManager
    @Binding var isShowing: Bool

    @State private var draftTemplate = ProjectStorageTemplateDocument.default

    var body: some View {
        TeamMessengerSettingsSheetShell(
            title: "\(PortalFeatureNaming.projectHub) 스토리지 템플릿",
            subtitle: manager.canManageGlobalStorageTemplate
                ? "공통 Google Drive / Dropbox 폴더 구조를 관리합니다."
                : "관리자만 수정할 수 있고, 다른 사용자는 조회만 가능합니다.",
            onClose: {
                isShowing = false
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    roleGuideCard
                    templateFoldersCard
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 760, minHeight: 720)
        .onAppear {
            draftTemplate = manager.storageTemplate
        }
        .onChange(of: manager.storageTemplate) { _, newValue in
            draftTemplate = newValue
        }
    }

    private var roleGuideCard: some View {
        ProjectArchiveSettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                ProjectArchiveSettingsSectionHeader(
                    title: "기본 분리 정책",
                    subtitle: "문서/자료는 Google Drive, 편집 산출물은 Dropbox로 기본 라우팅합니다."
                )

                HStack(spacing: 10) {
                    ProjectArchiveProviderBadge(provider: .googleDrive)
                    Text("문서, 참고자료, 일정, 회의록, 스크립트, 관리 자료")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.62))
                }

                HStack(spacing: 10) {
                    ProjectArchiveProviderBadge(provider: .dropbox)
                    Text("원본 소스, 그래픽, 렌더, 편집본, 납품본, 리뷰용")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.62))
                }

                if manager.isLoadingStorageTemplate {
                    ProgressView("공통 템플릿을 불러오는 중...")
                        .controlSize(.small)
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
    }

    private var templateFoldersCard: some View {
        ProjectArchiveSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                ProjectArchiveSettingsSectionHeader(
                    title: "공통 폴더 구조",
                    subtitle: "새 프로젝트 허브에 기본 적용되는 논리 폴더 트리입니다."
                )

                ForEach(Array(draftTemplate.folders.indices), id: \.self) { index in
                    ProjectArchiveStorageFolderEditorRow(folder: $draftTemplate.folders[index], canRemove: true) {
                        removeTemplateFolder(at: index)
                    }
                }

                HStack(spacing: 10) {
                    ProjectArchiveBorderButton(title: "기본 구조로 리셋") {
                        draftTemplate = .default
                    }

                    ProjectArchiveBorderButton(title: "폴더 추가") {
                        appendTemplateFolder()
                    }

                    Spacer()

                    Button {
                        Task {
                            var nextTemplate = draftTemplate
                            nextTemplate.version = max(manager.storageTemplate.version + 1, 1)
                            await manager.saveStorageTemplate(nextTemplate)
                            if manager.errorMessage == nil {
                                isShowing = false
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if manager.isSavingStorageTemplate {
                                ProgressView().controlSize(.small)
                            }
                            Text(manager.isSavingStorageTemplate ? "저장 중..." : "현재 내용으로 기본값 저장")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(manager.canManageGlobalStorageTemplate ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.gray.opacity(0.35))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!manager.canManageGlobalStorageTemplate || manager.isSavingStorageTemplate)
                    .clickableCursor(enabled: manager.canManageGlobalStorageTemplate && !manager.isSavingStorageTemplate)
                }

                if !manager.canManageGlobalStorageTemplate {
                    Text("`hello@studioleaf.kr` 관리자 로그인 상태에서만 공통 템플릿을 수정할 수 있습니다.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.50, green: 0.34, blue: 0.16))
                }
            }
        }
    }

    private func appendTemplateFolder() {
        let nextOrder = (draftTemplate.folders.map(\.sortOrder).max() ?? -1) + 1
        draftTemplate.folders.append(
            ProjectStorageFolder(
                id: "folder-\(nextOrder + 1)",
                title: "새 폴더",
                provider: .googleDrive,
                relativePath: "new-folder-\(nextOrder + 1)",
                keywords: [],
                sortOrder: nextOrder,
                isRequired: false
            )
        )
    }

    private func removeTemplateFolder(at index: Int) {
        guard draftTemplate.folders.indices.contains(index) else { return }
        draftTemplate.folders.remove(at: index)
    }
}

struct PortalProjectArchiveStorageSettingsSheet: View {
    @ObservedObject var manager: PortalProjectArchiveManager
    @Binding var isShowing: Bool
    @Binding var draft: ProjectArchiveDraft

    var body: some View {
        TeamMessengerSettingsSheetShell(
            title: "\(draft.projectName.isEmpty ? PortalFeatureNaming.projectHub : draft.projectName) 스토리지 설정",
            subtitle: "프로젝트별 Drive / Dropbox 루트와 폴더 오버라이드를 관리합니다.",
            onClose: {
                isShowing = false
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rootConnectionsCard
                    projectFoldersCard
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 820, minHeight: 760)
    }

    private var rootConnectionsCard: some View {
        ProjectArchiveSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                ProjectArchiveSettingsSectionHeader(
                    title: "스토리지 연결",
                    subtitle: "Google Drive / Dropbox 모두 프로젝트 루트를 기준으로 폴더를 생성합니다."
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Google Drive 프로젝트 폴더")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.7))

                    Text("신규 프로젝트 허브 저장 시 `Project Hub Root / 연도 / 연도_프로젝트명` 아래에 자동 생성됩니다.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.58))

                    ProjectArchiveReadOnlyValueRow(
                        title: "폴더 ID",
                        value: draft.googleDriveRootFolderID ?? "아직 생성되지 않음"
                    )
                    ProjectArchiveReadOnlyValueRow(
                        title: "표시 이름",
                        value: draft.googleDriveRootTitle ?? "아직 생성되지 않음"
                    )
                    ProjectArchiveReadOnlyValueRow(
                        title: "웹 URL",
                        value: draft.googleDriveRootWebURL ?? "아직 생성되지 않음"
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Dropbox 루트")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.7))

                    Text("비워두면 공통 기본 루트(/01_ProjectHub) 아래에 프로젝트 폴더가 생성됩니다.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.58))

                    ProjectArchiveSettingsTextField(title: "루트 path", text: binding(default: "", for: \.dropboxRootPath), placeholder: "/01_ProjectHub")
                    ProjectArchiveSettingsTextField(title: "표시 이름", text: binding(default: "", for: \.dropboxRootTitle), placeholder: "예: 2026 캠페인 산출물")
                    ProjectArchiveSettingsTextField(title: "웹 URL", text: binding(default: "", for: \.dropboxRootWebURL), placeholder: "https://www.dropbox.com/home/...")

                    HStack {
                        Spacer()

                        if let archiveID = draft.id {
                            ProjectArchiveBorderButton(
                                title: manager.isProvisioningDropboxFolders ? "Dropbox 폴더 생성 중..." : "Dropbox 폴더 생성",
                                isDisabled: manager.isProvisioningDropboxFolders || manager.isSavingArchive
                            ) {
                                Task {
                                    let success = await manager.provisionDropboxFolders(for: archiveID)
                                    if success,
                                       let refreshedArchive = manager.archives.first(where: { $0.id == archiveID }) {
                                        draft = manager.draft(for: refreshedArchive)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var projectFoldersCard: some View {
        let googleDriveAlreadyProvisioned = !(draft.googleDriveRootFolderID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let dropboxAlreadyProvisioned = !(draft.dropboxRootPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        return ProjectArchiveSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                ProjectArchiveSettingsSectionHeader(
                    title: "프로젝트별 폴더 구조",
                    subtitle: "공통 템플릿을 복제한 뒤 프로젝트에 맞게 이름, 경로, 분류 키워드를 조정합니다."
                )

                HStack(spacing: 10) {
                    ProjectArchiveBorderButton(title: "공통 템플릿 다시 적용") {
                        draft.applyTemplate(manager.storageTemplate)
                    }

                    ProjectArchiveBorderButton(
                        title: "폴더 추가"
                    ) {
                        appendProjectFolder()
                    }

                    if let archiveID = draft.id {
                        ProjectArchiveBorderButton(
                            title: manager.isProvisioningGoogleDriveFolders
                                ? "Google Drive 생성 중..."
                                : (googleDriveAlreadyProvisioned ? "Google Drive 준비 완료" : "Google Drive 폴더 생성"),
                            isDisabled: manager.isProvisioningGoogleDriveFolders || manager.isSavingArchive || googleDriveAlreadyProvisioned
                        ) {
                            Task {
                                let success = await manager.provisionGoogleDriveFolders(for: archiveID)
                                if success,
                                   let refreshedArchive = manager.archives.first(where: { $0.id == archiveID }) {
                                    draft = manager.draft(for: refreshedArchive)
                                }
                            }
                        }

                        ProjectArchiveBorderButton(
                            title: manager.isProvisioningDropboxFolders
                                ? "Dropbox 생성 중..."
                                : (dropboxAlreadyProvisioned ? "Dropbox 준비 완료" : "Dropbox 폴더 생성"),
                            isDisabled: manager.isProvisioningDropboxFolders || manager.isSavingArchive || dropboxAlreadyProvisioned
                        ) {
                            Task {
                                let success = await manager.provisionDropboxFolders(for: archiveID)
                                if success,
                                   let refreshedArchive = manager.archives.first(where: { $0.id == archiveID }) {
                                    draft = manager.draft(for: refreshedArchive)
                                }
                            }
                        }
                    }

                    Spacer()

                    Button {
                        Task {
                            await manager.saveArchive(draft)
                            if manager.errorMessage == nil {
                                isShowing = false
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if manager.isSavingArchive {
                                ProgressView().controlSize(.small)
                            }
                            Text(manager.isSavingArchive ? "저장 중..." : "프로젝트 설정 저장")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(manager.isSavingArchive ? Color.gray.opacity(0.35) : Color(red: 0.10, green: 0.18, blue: 0.14))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.isSavingArchive)
                    .clickableCursor(enabled: !manager.isSavingArchive)
                }

                ForEach(Array(draft.storageFolders.indices), id: \.self) { index in
                    ProjectArchiveStorageFolderEditorRow(
                        folder: $draft.storageFolders[index],
                        canRemove: !draft.storageFolders[index].isRequired
                    ) {
                        removeProjectFolder(at: index)
                    }
                }

                if draft.id == nil {
                    Text("Google Drive 자동 폴더 생성은 프로젝트 허브를 한 번 저장한 뒤 사용할 수 있습니다.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.45))
                } else {
                    Text("스토리지 루트가 이미 준비된 경우 생성 버튼은 비활성화됩니다. 신규 허브 생성 시에는 자동으로 실행되고, 누락되었거나 다시 맞춰야 할 때만 수동으로 사용하면 됩니다.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
            }
        }
    }

    private func binding(default fallback: String, for keyPath: WritableKeyPath<ProjectArchiveDraft, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? fallback },
            set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func appendProjectFolder() {
        let nextOrder = (draft.storageFolders.map(\.sortOrder).max() ?? -1) + 1
        draft.storageFolders.append(
            ProjectStorageFolder(
                id: "project-folder-\(nextOrder + 1)",
                title: "프로젝트 폴더",
                provider: .googleDrive,
                relativePath: "project-folder-\(nextOrder + 1)",
                keywords: [],
                sortOrder: nextOrder,
                isRequired: false
            )
        )
    }

    private func removeProjectFolder(at index: Int) {
        guard draft.storageFolders.indices.contains(index) else { return }
        draft.storageFolders.remove(at: index)
    }
}

struct PortalExternalStorageAdminSettingsSheet: View {
    @ObservedObject var manager: PortalProjectArchiveManager
    @Binding var isShowing: Bool

    var body: some View {
        TeamMessengerSettingsSheetShell(
            title: "외부 스토리지 계정 관리",
            subtitle: manager.canManageGlobalStorageTemplate
                ? "`pd@studioleaf.kr` 실행 계정 기준의 연결 검증 결과를 표시합니다."
                : "관리자만 실제 연결 검증을 실행할 수 있고, 현재 연결 상태만 조회할 수 있습니다.",
            onClose: {
                isShowing = false
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    guideCard
                    providerCard(
                        title: "Google Drive",
                        status: manager.externalStorageAccounts.googleDrive
                    )
                    providerCard(
                        title: "Dropbox",
                        status: manager.externalStorageAccounts.dropbox
                    )
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 720, minHeight: 700)
    }

    private var guideCard: some View {
        ProjectArchiveSettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                ProjectArchiveSettingsSectionHeader(
                    title: "운영 방식",
                    subtitle: "앱 로그인 계정과 외부 스토리지 실행 계정은 분리합니다. 이 화면은 사용자가 값을 직접 입력하는 곳이 아니라, Functions + Secret Manager 기준의 현재 연결 상태를 보여주는 상태판입니다."
                )

                if manager.isLoadingExternalStorageAccounts {
                    ProgressView("현재 상태를 불러오는 중...")
                        .controlSize(.small)
                        .font(.system(size: 12, weight: .medium))
                } else {
                    Text("Google Drive와 Dropbox 모두 Functions와 Secret Manager를 통해 실제 연결 검증이 가능합니다.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.6))
                }

                externalStorageDocumentMeta
            }
        }
    }

    private func providerCard(
        title: String,
        status: ProjectStorageProviderAccountStatus
    ) -> some View {
        ProjectArchiveSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    ProjectArchiveProviderBadge(provider: status.provider)
                }

                readOnlyField(
                    title: "실행 계정 이메일",
                    value: status.executionEmail.isEmpty ? ProjectStoragePolicy.operatorEmail : status.executionEmail
                )

                readOnlyField(
                    title: "표시 라벨",
                    value: status.accountLabel.isEmpty ? "아직 확인되지 않음" : status.accountLabel
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("연결 상태")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.52))

                    HStack(spacing: 10) {
                        statusBadge(status.connectionState)
                        Text(connectionStateDescription(status.connectionState))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                }

                readOnlyField(
                    title: "관리 메모",
                    value: status.notes.isEmpty ? "기록 없음" : status.notes
                )

                Text(lastValidatedText(for: status))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.48))

                validationButton(for: status.provider)
            }
        }
    }

    private func validationButton(for provider: ProjectStorageProvider) -> some View {
        HStack {
            Spacer()

            Button {
                Task {
                    if provider == .googleDrive {
                        await manager.validateGoogleDriveAdminSetup()
                    } else {
                        await manager.validateDropboxAdminSetup()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if provider == .googleDrive {
                        if manager.isValidatingGoogleDriveAdminSetup {
                            ProgressView().controlSize(.small)
                        }
                    } else {
                        if manager.isValidatingDropboxAdminSetup {
                            ProgressView().controlSize(.small)
                        }
                    }

                    Text(
                        provider == .googleDrive
                            ? (manager.isValidatingGoogleDriveAdminSetup ? "검증 중..." : "실제 연결 검증")
                            : (manager.isValidatingDropboxAdminSetup ? "검증 중..." : "Dropbox 연결 검증")
                    )
                    .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(manager.canManageGlobalStorageTemplate ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.gray.opacity(0.35))
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !manager.canManageGlobalStorageTemplate
                || (provider == .googleDrive && manager.isValidatingGoogleDriveAdminSetup)
                || (provider == .dropbox && manager.isValidatingDropboxAdminSetup)
            )
            .clickableCursor(
                enabled: manager.canManageGlobalStorageTemplate
                && !((provider == .googleDrive && manager.isValidatingGoogleDriveAdminSetup)
                || (provider == .dropbox && manager.isValidatingDropboxAdminSetup))
            )
        }
    }

    private var externalStorageDocumentMeta: some View {
        VStack(alignment: .leading, spacing: 4) {
            if manager.externalStorageAccounts.updatedAt > .distantPast {
                Text(
                    "최근 상태 갱신: \(manager.externalStorageAccounts.updatedAt.formatted(date: .abbreviated, time: .shortened))"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.48))
            }

            if !manager.externalStorageAccounts.updatedByEmail.isEmpty {
                Text("갱신 주체: \(manager.externalStorageAccounts.updatedByEmail)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.48))
            }
        }
    }

    private func readOnlyField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.52))

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(ProjectArchiveSettingsFieldBackground())
        }
    }

    private func statusBadge(_ state: ProjectStorageConnectionState) -> some View {
        Text(state.title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(statusTint(state).text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(statusTint(state).background)
            )
    }

    private func statusTint(_ state: ProjectStorageConnectionState) -> (text: Color, background: Color) {
        switch state {
        case .connected:
            return (Color(red: 0.11, green: 0.39, blue: 0.21), Color(red: 0.90, green: 0.97, blue: 0.91))
        case .pending:
            return (Color(red: 0.56, green: 0.34, blue: 0.04), Color(red: 0.98, green: 0.94, blue: 0.84))
        case .needsReconnect:
            return (Color(red: 0.70, green: 0.19, blue: 0.14), Color(red: 0.99, green: 0.90, blue: 0.88))
        case .notConfigured:
            return (Color.black.opacity(0.58), Color.black.opacity(0.07))
        }
    }

    private func connectionStateDescription(_ state: ProjectStorageConnectionState) -> String {
        switch state {
        case .connected:
            return "최근 연결 검증이 성공했습니다."
        case .pending:
            return "연결 준비 중이거나 설정이 아직 마무리되지 않았습니다."
        case .needsReconnect:
            return "토큰 또는 권한 상태를 다시 확인해야 합니다."
        case .notConfigured:
            return "아직 검증 이력이 없거나 연결이 준비되지 않았습니다."
        }
    }

    private func lastValidatedText(for status: ProjectStorageProviderAccountStatus) -> String {
        if let lastValidatedAt = status.lastValidatedAt {
            return "마지막 확인: \(lastValidatedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "마지막 확인 기록이 없습니다."
    }
}

private struct ProjectArchiveStorageFolderEditorRow: View {
    @Binding var folder: ProjectStorageFolder
    let canRemove: Bool
    let onRemove: () -> Void

    private var keywordsBinding: Binding<String> {
        Binding(
            get: { folder.keywords.joined(separator: ", ") },
            set: { folder.keywords = csvList(from: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ROW 1
            HStack(alignment: .top, spacing: 14) {
                // Column 1: Folder Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("폴더 이름")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.52))
                    TextField("예: 커뮤니케이션", text: $folder.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(ProjectArchiveSettingsFieldBackground())
                }
                .frame(maxWidth: .infinity)

                // Column 2: Provider
                VStack(alignment: .leading, spacing: 6) {
                    Text("스토리지")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.52))
                    Picker("", selection: $folder.provider) {
                        ForEach(ProjectStorageProvider.allCases, id: \.self) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(height: 36)
                }
                .frame(width: 110, alignment: .leading)

                // Column 3: Relative Path + Remove Button
                HStack(alignment: .top, spacing: 12) {
                    ProjectArchiveSettingsTextField(title: "상대 경로", text: $folder.relativePath, placeholder: "예: 00_Communication")
                        .frame(width: 170)

                    if canRemove {
                        VStack(spacing: 6) {
                            Text("삭제")
                                .font(.system(size: 11, weight: .bold))
                                .opacity(0)
                            
                            Button {
                                onRemove()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(red: 0.90, green: 0.28, blue: 0.18))
                            }
                            .buttonStyle(.plain)
                            .clickableCursor()
                            .frame(width: 20, height: 36)
                        }
                    } else {
                        Spacer().frame(width: 20)
                    }
                }
            }

            // ROW 2
            HStack(alignment: .top, spacing: 14) {
                // Column 1: Keywords
                ProjectArchiveSettingsTextField(title: "키워드", text: keywordsBinding, placeholder: "예: 문서, 기획, 최종본")
                    .frame(maxWidth: .infinity)

                // Column 2: Is Required
                VStack(alignment: .leading, spacing: 6) {
                    Text("필수 여부")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.52))
                    Toggle("", isOn: $folder.isRequired)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .frame(height: 36)
                }
                .frame(width: 110, alignment: .leading)

                // Column 3: Sort Order
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("정렬 순서")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.52))
                        Stepper(value: $folder.sortOrder, in: 0...999) {
                            Text("\(folder.sortOrder)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.7))
                                .padding(.leading, 2)
                        }
                        .frame(height: 36)
                    }
                    .frame(width: 170, alignment: .leading)

                    Spacer().frame(width: 20)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.025))
        )
    }

    private func csvList(from string: String) -> [String] {
        string
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct ProjectArchiveSettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        PortalCard(padding: 18) {
            content()
        }
    }
}

private struct ProjectArchiveSettingsSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.84))
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProjectArchiveSettingsTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.52))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(ProjectArchiveSettingsFieldBackground())
        }
    }
}

private struct ProjectArchiveSettingsFieldBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct ProjectArchiveReadOnlyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.52))

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(ProjectArchiveSettingsFieldBackground())
                .textSelection(.enabled)
        }
    }
}

private struct ProjectArchiveBorderButton: View {
    let title: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(isDisabled ? 0.34 : 0.72))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .stroke(Color.black.opacity(isDisabled ? 0.08 : 0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .clickableCursor(enabled: !isDisabled)
    }
}

private struct ProjectArchiveProviderBadge: View {
    let provider: ProjectStorageProvider

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: provider.systemIcon)
            Text(provider.title)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Color.black.opacity(0.7))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.05))
        )
    }
}
