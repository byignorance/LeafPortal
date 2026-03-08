import SwiftUI

struct PortalProjectArchiveSection: View {
    @ObservedObject var manager: PortalProjectArchiveManager
    @ObservedObject var notionHubViewModel: NotionHubViewModel
    @ObservedObject var projectChatManager: PortalProjectChatManager
    @ObservedObject var viewModel: PortalViewModel

    @State private var isShowingEditor = false
    @State private var isShowingTemplateSettings = false
    @State private var isShowingStorageSettings = false
    @State private var editingDraft = ProjectArchiveDraft.empty
    @State private var storageSettingsDraft = ProjectArchiveDraft.empty
    @State private var editorMode = ArchiveEditorMode.create
    @State private var archivePendingDeletion: ProjectArchiveSummary?
    @State private var archiveShowingGoogleDriveBrowser: ProjectArchiveSummary?
    @State private var archiveShowingDropboxBrowser: ProjectArchiveSummary?

    private var sortedArchives: [ProjectArchiveSummary] {
        manager.archives.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(PortalFeatureNaming.projectHub)
                    .font(.system(size: 28, weight: .black))
                Spacer()

                if manager.canManageGlobalStorageTemplate {
                    Button {
                        isShowingTemplateSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                            .padding(10)
                            .background(Color.black.opacity(0.04))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("공통 스토리지 템플릿 설정")
                    .clickableCursor()
                }

                Button {
                    openNewArchiveEditor()
                } label: {
                    Text("새 \(PortalFeatureNaming.projectHub) 생성")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.10, green: 0.18, blue: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(manager.isSavingArchive)
                .clickableCursor(enabled: !manager.isSavingArchive)
            }

            if let bannerMessage = manager.bannerMessage, !bannerMessage.isEmpty {
                InlineAlert(text: bannerMessage)
            }

            if let errorMessage = manager.errorMessage, !errorMessage.isEmpty {
                InlineAlert(text: errorMessage, isWarning: true)
            }

            if manager.isLoadingArchives {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.large)
                    Text("\(PortalFeatureNaming.projectHub)를 불러오는 중입니다.")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 80)
            } else if sortedArchives.isEmpty {
                VStack(spacing: 12) {
                    Text("아직 \(PortalFeatureNaming.projectHub)가 없습니다.")
                        .font(.system(size: 18, weight: .bold))
                    Text("\(PortalFeatureNaming.projectHub)를 만들고 \(PortalFeatureNaming.notionConnector), \(PortalFeatureNaming.teamMessenger), 드랍박스/구글드라이브 바로가기를 한 번에 관리하세요.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 80)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                        ForEach(sortedArchives) { archive in
                            archiveCard(for: archive)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            archiveEditor
                .frame(minWidth: 620, minHeight: 680)
        }
        .sheet(isPresented: $isShowingTemplateSettings) {
            PortalProjectArchiveTemplateSettingsSheet(
                manager: manager,
                isShowing: $isShowingTemplateSettings
            )
        }
        .sheet(isPresented: $isShowingStorageSettings) {
            PortalProjectArchiveStorageSettingsSheet(
                manager: manager,
                isShowing: $isShowingStorageSettings,
                draft: $storageSettingsDraft
            )
        }
        .sheet(
            isPresented: Binding(
                get: { archiveShowingGoogleDriveBrowser != nil },
                set: { isPresented in
                    if !isPresented {
                        archiveShowingGoogleDriveBrowser = nil
                    }
                }
            )
        ) {
            if let archiveShowingGoogleDriveBrowser {
                PortalProjectGoogleDriveBrowserSheet(
                    manager: manager,
                    archive: archiveShowingGoogleDriveBrowser,
                    isShowing: Binding(
                        get: { self.archiveShowingGoogleDriveBrowser != nil },
                        set: { isPresented in
                            if !isPresented {
                                self.archiveShowingGoogleDriveBrowser = nil
                            }
                        }
                    )
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: { archiveShowingDropboxBrowser != nil },
                set: { isPresented in
                    if !isPresented {
                        archiveShowingDropboxBrowser = nil
                    }
                }
            )
        ) {
            if let archiveShowingDropboxBrowser {
                PortalProjectDropboxBrowserSheet(
                    manager: manager,
                    archive: archiveShowingDropboxBrowser,
                    isShowing: Binding(
                        get: { self.archiveShowingDropboxBrowser != nil },
                        set: { isPresented in
                            if !isPresented {
                                self.archiveShowingDropboxBrowser = nil
                            }
                        }
                    )
                )
            }
        }
        .confirmationDialog(
            "프로젝트 허브 삭제",
            isPresented: Binding(
                get: { archivePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        archivePendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let archivePendingDeletion {
                Button("Google Drive/Dropbox 폴더까지 삭제", role: .destructive) {
                    Task {
                        _ = await manager.deleteArchive(archivePendingDeletion)
                        self.archivePendingDeletion = nil
                    }
                }
            }

            Button("취소", role: .cancel) {
                archivePendingDeletion = nil
            }
        } message: {
            if let archivePendingDeletion {
                Text("`\((archivePendingDeletion.projectName))` 허브 문서와 연결된 Google Drive/Dropbox 폴더, 채팅 프로젝트를 함께 삭제합니다.")
            }
        }
        .task {
            if notionHubViewModel.projects.isEmpty {
                await notionHubViewModel.loadProjects()
            }
        }
    }

    private var archiveEditor: some View {
        PortalProjectArchiveEditor(
            mode: editorMode,
            draft: $editingDraft,
            notionHubViewModel: notionHubViewModel,
            projectChatManager: projectChatManager,
            isSaving: manager.isSavingArchive,
            onDismiss: {
                isShowingEditor = false
            },
            onSave: {
                Task {
                    await manager.saveArchive(editingDraft)
                    if manager.errorMessage == nil {
                        isShowingEditor = false
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func archiveCard(for archive: ProjectArchiveSummary) -> some View {
        PortalCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(archive.projectName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.88))
                        if !archive.projectSummary.isEmpty {
                            Text(archive.projectSummary)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.58))
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        archiveIconActionButton(
                            systemImage: "externaldrive.fill",
                            helpText: "스토리지 설정"
                        ) {
                            storageSettingsDraft = manager.draft(for: archive)
                            isShowingStorageSettings = true
                        }

                        archiveIconActionButton(
                            systemImage: "square.and.pencil",
                            helpText: "프로젝트 설정"
                        ) {
                            editingDraft = manager.draft(for: archive)
                            editorMode = .edit
                            isShowingEditor = true
                        }

                        archiveIconActionButton(
                            systemImage: "trash",
                            helpText: manager.isDeletingArchive ? "삭제 중..." : "삭제",
                            destructive: true,
                            disabled: manager.isDeletingArchive || !manager.canDeleteArchive(archive)
                        ) {
                            archivePendingDeletion = archive
                        }
                    }
                }

                HStack(spacing: 10) {
                    if let notionURL = archive.notionURL {
                        Link(destination: notionURL) {
                            quickPill(PortalFeatureNaming.notionConnector, icon: "books.vertical.fill")
                        }
                        .buttonStyle(.plain)
                    }

                    if let chatID = archive.chatProjectID {
                        Button {
                            viewModel.selectedSection = .projectChat
                            projectChatManager.selectedProjectID = chatID
                        } label: {
                            quickPill("Chat", icon: "bubble.left.and.bubble.right.fill")
                        }
                        .buttonStyle(.plain)
                        .clickableCursor()
                    }

                    if let googleDriveURL = archive.googleDriveRootWebURL {
                        Button {
                            archiveShowingGoogleDriveBrowser = archive
                        } label: {
                            quickPill("Google Drive", icon: "externaldrive.fill")
                        }
                        .buttonStyle(.plain)
                        .help(googleDriveURL.absoluteString)
                        .clickableCursor()
                    }

                    if let dropboxURL = archive.dropboxRootWebURL {
                        Button {
                            archiveShowingDropboxBrowser = archive
                        } label: {
                            quickPill("Dropbox", icon: "shippingbox.fill")
                        }
                        .buttonStyle(.plain)
                        .help(dropboxURL.absoluteString)
                        .clickableCursor()
                    }
                }

                if !archive.links.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("바로가기")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.45))

                        ForEach(archive.links) { link in
                            if let url = link.url {
                                Link(destination: url) {
                                    quickLinkRow(for: link)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                Text("마지막 수정: \(archive.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.black.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func quickPill(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Color.black.opacity(0.72))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.94, green: 0.96, blue: 0.98))
        )
    }

    private func archiveIconActionButton(
        systemImage: String,
        helpText: String,
        destructive: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        ArchiveCardIconActionButton(
            systemImage: systemImage,
            helpText: helpText,
            destructive: destructive,
            disabled: disabled,
            action: action
        )
    }

    private func quickLinkRow(for link: ProjectArchiveResourceLink) -> some View {
        HStack(spacing: 8) {
            Image(systemName: link.type.systemIcon)
            Text(link.title.isEmpty ? link.type.title : link.title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 10))
                .foregroundStyle(Color.black.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.96, green: 0.97, blue: 0.97))
        )
    }

    private func openNewArchiveEditor() {
        editingDraft = manager.newDraft()
        editorMode = .create
        isShowingEditor = true
    }

    enum ArchiveEditorMode {
        case create
        case edit
    }
}

private struct ArchiveCardIconActionButton: View {
    let systemImage: String
    let helpText: String
    let destructive: Bool
    let disabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(foregroundColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 11)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .clickableCursor(enabled: !disabled)
        .onHover { hovering in
            guard !disabled else {
                isHovered = false
                return
            }
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .overlay(alignment: .bottom) {
            if isHovered {
                Text(helpText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .fixedSize()
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.82))
                    )
                    .offset(y: 34)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .allowsHitTesting(false)
            }
        }
        .zIndex(isHovered ? 10 : 0)
    }

    private var foregroundColor: Color {
        if disabled {
            return Color.black.opacity(0.28)
        }
        return destructive ? Color.red.opacity(0.9) : Color.black.opacity(0.74)
    }

    private var borderColor: Color {
        destructive ? Color.red.opacity(0.14) : Color.black.opacity(0.08)
    }
}

struct PortalProjectArchiveEditor: View {
    enum ActionMode {
        case create
        case edit

        var buttonTitle: String {
            switch self {
            case .create:
                return "생성"
            case .edit:
                return "저장"
            }
        }
    }

    let mode: PortalProjectArchiveSection.ArchiveEditorMode
    @Binding var draft: ProjectArchiveDraft
    @ObservedObject var notionHubViewModel: NotionHubViewModel
    @ObservedObject var projectChatManager: PortalProjectChatManager
    let isSaving: Bool
    let onDismiss: () -> Void
    let onSave: () -> Void

    @State private var activeNotionProjectID = ""
    @State private var activeChatProjectID = ""
    @State private var pendingWorkGroupName = ""

    private var selectedNotionBinding: Binding<String> {
        Binding(
            get: { draft.notionProjectID ?? "" },
            set: { updateNotionSelection($0) }
        )
    }

    private var selectedChatBinding: Binding<String> {
        Binding(
            get: { draft.chatProjectID ?? "" },
            set: { updateChatSelection($0) }
        )
    }

    init(
        mode: PortalProjectArchiveSection.ArchiveEditorMode,
        draft: Binding<ProjectArchiveDraft>,
        notionHubViewModel: NotionHubViewModel,
        projectChatManager: PortalProjectChatManager,
        isSaving: Bool,
        onDismiss: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.mode = mode
        self._draft = draft
        self.notionHubViewModel = notionHubViewModel
        self.projectChatManager = projectChatManager
        self.isSaving = isSaving
        self.onDismiss = onDismiss
        self.onSave = onSave

        _activeNotionProjectID = State(initialValue: draft.wrappedValue.notionProjectID ?? "")
        _activeChatProjectID = State(initialValue: draft.wrappedValue.chatProjectID ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(mode == .create ? "\(PortalFeatureNaming.projectHub) 생성" : "\(PortalFeatureNaming.projectHub) 편집")
                    .font(.system(size: 20, weight: .black))

                Spacer()

                Button("닫기") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionCard {
                        fieldTitle("프로젝트 이름")
                        TextField("예: 8mm 시리즈 프로젝트", text: $draft.projectName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06), lineWidth: 1))
                            )

                        fieldTitle("요약")
                        TextField("한 줄 요약", text: $draft.projectSummary, axis: .vertical)
                            .lineLimit(2...6)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06), lineWidth: 1))
                            )
                    }

                    sectionCard {
                        fieldTitle("프로젝트 코드")
                        TextField("예: HyundaiTutVideo", text: $draft.projectCode)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06), lineWidth: 1))
                            )

                        Text("업로드 시 규칙 기반 파일명을 적용할 때 사용하는 기본 코드입니다.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(red: 0.4, green: 0.46, blue: 0.58))

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                fieldTitle("기본 파일명 방식")
                                Picker("기본 파일명 방식", selection: $draft.namingDefaults.renameMode) {
                                    ForEach(ProjectUploadRenameMode.allCases, id: \.self) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                fieldTitle("기본 버전 방식")
                                Picker("기본 버전 방식", selection: $draft.namingDefaults.versionMode) {
                                    ForEach(ProjectUploadVersionMode.allCases, id: \.self) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                fieldTitle("Date Based 형식")
                                Picker("Date Based 형식", selection: $draft.namingDefaults.dateFormat) {
                                    ForEach(ProjectUploadDateFormat.allCases, id: \.self) { format in
                                        Text(format.title).tag(format)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        Divider()
                            .padding(.vertical, 2)

                        fieldTitle("저장된 작업 묶음")
                        HStack(spacing: 8) {
                            TextField("예: EP01, 교육자료, 인터뷰A", text: $pendingWorkGroupName)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06), lineWidth: 1))
                                )

                            PortalSecondaryButton(title: "추가", disabled: pendingWorkGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                                appendWorkGroup()
                            }
                        }

                        if draft.savedWorkGroups.isEmpty {
                            Text("업로드 중 사용한 작업 묶음은 자동으로 여기에 누적됩니다.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(red: 0.4, green: 0.46, blue: 0.58))
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(draft.savedWorkGroups, id: \.self) { workGroup in
                                    HStack(spacing: 6) {
                                        Text(workGroup)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.76))
                                            .lineLimit(1)
                                        Button {
                                            removeWorkGroup(workGroup)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.45))
                                        }
                                        .buttonStyle(.plain)
                                        .clickableCursor()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.05))
                                    )
                                }
                            }
                        }
                    }

                    sectionCard {
                        fieldTitle("\(PortalFeatureNaming.notionConnector) 프로젝트")
                        Picker("\(PortalFeatureNaming.notionConnector) 프로젝트", selection: selectedNotionBinding) {
                            Text("연결 안 함").tag("")
                            ForEach(notionHubViewModel.projects) { project in
                                Text(project.title).tag(project.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .onAppear {
                            if notionHubViewModel.selectedProjectID == nil && notionHubViewModel.projects.isEmpty {
                                Task {
                                    await notionHubViewModel.loadProjects()
                                }
                            }
                        }

                        if draft.notionProjectID == nil {
                            Text("노션 생성은 제공하지 않고, 기존 노션 프로젝트만 연결합니다.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(red: 0.4, green: 0.46, blue: 0.58))
                        }
                    }

                    sectionCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                fieldTitle("\(PortalFeatureNaming.teamMessenger) 연동")
                                Text("\(PortalFeatureNaming.teamMessenger)를 새로 만들거나 기존 \(PortalFeatureNaming.teamMessenger) 프로젝트를 선택하세요.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 0.44, green: 0.50, blue: 0.6))
                            }

                            Spacer()

                            Toggle("", isOn: $draft.shouldCreateChatProject)
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.10, green: 0.18, blue: 0.14)))
                                .labelsHidden()
                        }

                        if draft.shouldCreateChatProject {
                            Text("\(PortalFeatureNaming.teamMessenger) 새 프로젝트를 함께 만듭니다.")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 0.31, green: 0.42, blue: 0.58))
                        } else {
                            Picker("기존 \(PortalFeatureNaming.teamMessenger) 선택", selection: selectedChatBinding) {
                                Text("선택 안 함").tag("")
                                ForEach(projectChatManager.projects) { project in
                                    Text(project.name).tag(project.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: activeChatProjectID) { _, newValue in
                                activeChatProjectID = newValue
                            }
                        }
                    }

                    sectionCard {
                        fieldTitle("드롭박스 / 구글드라이브 바로가기")
                        VStack(alignment: .leading, spacing: 10) {
                            if draft.links.isEmpty {
                                Text("아직 추가되지 않았습니다.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.black.opacity(0.45))
                                    .padding(.horizontal, 2)
                            } else {
                                ForEach(draft.links.indices, id: \.self) { index in
                                    linkEditRow(index: index)
                                }
                            }

                            Button {
                                draft.links.append(ProjectArchiveResourceLink.empty)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                    Text("바로가기 추가")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .stroke(Color(red: 0.10, green: 0.18, blue: 0.14), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .clickableCursor()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 10) {
                Spacer()

                secondaryPillButton(title: "취소", enabled: true) {
                    onDismiss()
                }

                Button {
                    onSave()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        }

                        Text(isSaving ? "저장 중..." : mode == .create ? "생성" : "저장")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSaving ? Color.gray.opacity(0.35) : Color(red: 0.10, green: 0.18, blue: 0.14))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .clickableCursor(enabled: !isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .onChange(of: draft.shouldCreateChatProject) { _, shouldCreate in
            if shouldCreate {
                draft.chatProjectID = nil
                activeChatProjectID = ""
            }
        }
        .onAppear {
            activeNotionProjectID = draft.notionProjectID ?? ""
            activeChatProjectID = draft.chatProjectID ?? ""
        }
    }

    private func appendWorkGroup() {
        let trimmed = pendingWorkGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if draft.savedWorkGroups.contains(trimmed) == false {
            draft.savedWorkGroups.append(trimmed)
            draft.savedWorkGroups.sort()
        }
        pendingWorkGroupName = ""
    }

    private func removeWorkGroup(_ value: String) {
        draft.savedWorkGroups.removeAll { $0 == value }
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.58))
    }

    private func sectionCard<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        PortalCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
    }

    private func linkEditRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("타입", selection: $draft.links[index].type) {
                ForEach(ProjectArchiveLinkType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                TextField("링크 제목", text: $draft.links[index].title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )

                TextField("URL", text: $draft.links[index].urlString)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )

                Button {
                    draft.links.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.89, green: 0.26, blue: 0.15))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func secondaryPillButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        PortalSecondaryButton(title: title, disabled: !enabled, action: action)
    }

    private func updateNotionSelection(_ notionProjectID: String) {
        activeNotionProjectID = notionProjectID
        guard !notionProjectID.isEmpty else {
            draft.notionProjectID = nil
            draft.notionProjectTitle = nil
            draft.notionProjectURL = nil
            return
        }

        guard let notionProject = notionHubViewModel.projects.first(where: { $0.id == notionProjectID }) else { return }
        draft.notionProjectID = notionProject.id
        draft.notionProjectTitle = notionProject.title
        draft.notionProjectURL = notionProject.notionURL?.absoluteString
    }

    private func updateChatSelection(_ chatProjectID: String) {
        activeChatProjectID = chatProjectID
        draft.chatProjectID = chatProjectID.isEmpty ? nil : chatProjectID
    }
}
