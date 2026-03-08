import SwiftUI

private struct AccordionRevealModifier: ViewModifier {
    let progress: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: progress, anchor: .top)
            .opacity(opacity)
            .clipped()
    }
}

private extension AnyTransition {
    static var accordionReveal: AnyTransition {
        .modifier(
            active: AccordionRevealModifier(progress: 0.96, opacity: 0),
            identity: AccordionRevealModifier(progress: 1, opacity: 1)
        )
    }
}

private enum PortalOverviewToolCard: String, CaseIterable, Identifiable {
    case renderNotification
    case wakeUpLeaf

    var id: String { rawValue }
}

struct PortalOverviewToolsSection: View {
    @ObservedObject var viewModel: PortalViewModel
    @ObservedObject var sleepManager: SleepGuardManager
    @ObservedObject var notionHubViewModel: NotionHubViewModel
    @ObservedObject var projectChatManager: PortalProjectChatManager
    @ObservedObject var projectArchiveManager: PortalProjectArchiveManager
    let isCollaborationUnlocked: Bool
    @Binding var selectedSection: PortalSection

    @State private var wakeUpLeafDurationInputText = ""
    @State private var expandedCards: Set<PortalOverviewToolCard> = []
    @State private var wakeUpLeafApps: [SleepGuardManager.AppCandidate] = []

    private let themeColor = Color(red: 0.10, green: 0.18, blue: 0.14)
    private let accentColor = Color(red: 0.35, green: 0.80, blue: 0.52)
    private let mutedText = Color(red: 0.34, green: 0.41, blue: 0.53)
    private let surfaceColor = Color(red: 0.96, green: 0.97, blue: 0.97)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            collaborationDashboardSection
            toolLauncherSection
        }
        .task {
            guard isCollaborationUnlocked, notionHubViewModel.projects.isEmpty else { return }
            await notionHubViewModel.loadProjects()
        }
    }

    private var collaborationDashboardSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("협업 업데이트")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.86))
                Spacer()
                Text("최근 흐름")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(themeColor.opacity(0.08))
                    )
            }

            Text("협업 도구는 최근 변경이나 현재 상태를 빠르게 파악하는 대시보드 형태로 먼저 보여줍니다.")
                .font(.system(size: 13))
                .foregroundStyle(mutedText)

            HStack(alignment: .top, spacing: 14) {
                collaborationCard(
                    title: PortalFeatureNaming.projectHub,
                    subtitle: "\(PortalFeatureNaming.notionConnector), \(PortalFeatureNaming.teamMessenger), 공유 링크 한 곳 관리",
                    icon: "archivebox",
                    accent: Color(red: 0.43, green: 0.35, blue: 0.70)
                ) {
                    projectArchiveDashboardContent
                }

                collaborationCard(
                    title: PortalFeatureNaming.teamMessenger,
                    subtitle: "최근 대화와 강조 메시지",
                    icon: "bubble.left.and.bubble.right.fill",
                    accent: themeColor
                ) {
                    projectChatDashboardContent
                }

                collaborationCard(
                    title: PortalFeatureNaming.notionConnector,
                    subtitle: "최근 프로젝트 상태 요약",
                    icon: "books.vertical.fill",
                    accent: Color(red: 0.42, green: 0.52, blue: 0.31)
                ) {
                    notionHubDashboardContent
                }
            }
        }
    }

    private var toolLauncherSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("도구 런처")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.86))
                Spacer()
                Text("기본은 접힘")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(themeColor.opacity(0.08))
                    )
            }

            Text("포털 도구는 헤더만 먼저 보이고, 펼치면 바로 실행 가능한 최소 UI만 드러납니다.")
                .font(.system(size: 13))
                .foregroundStyle(mutedText)

            VStack(spacing: 14) {
                toolAccordionCard(
                    tool: .renderNotification,
                    title: "Render Notification",
                    subtitle: "렌더 완료 감시 도구",
                    status: viewModel.isMonitoring ? "실행 중" : "대기",
                    icon: "sparkles.tv.fill",
                    accent: themeColor,
                    isExpanded: expandedCards.contains(.renderNotification)
                ) {
                    renderNotificationCompactContent
                }

                toolAccordionCard(
                    tool: .wakeUpLeaf,
                    title: "WakeUp Leaf",
                    subtitle: "절전 방지 도구",
                    status: sleepManager.isKeepingAwake ? "실행 중" : "대기",
                    icon: "moon.stars.fill",
                    accent: accentColor,
                    isExpanded: expandedCards.contains(.wakeUpLeaf)
                ) {
                    wakeUpLeafCompactContent
                }
            }
        }
    }

    private var renderNotificationCompactContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("판정 기준", selection: $viewModel.detectionMode) {
                ForEach(DetectionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            if viewModel.detectionMode == .simple {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("감시 대상")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.5))
                        Spacer()
                        Picker("감시 대상", selection: $viewModel.targetKind) {
                            ForEach(MonitorTargetKind.allCases) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: viewModel.targetKind == .file ? "doc.fill" : "folder.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(themeColor.opacity(0.7))

                        Text(viewModel.selectedPathDisplay)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(viewModel.selectedPath == nil ? Color.black.opacity(0.35) : Color.black.opacity(0.82))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        squareIconButton(icon: "ellipsis") {
                            viewModel.selectTarget()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(surfaceColor)
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(themeColor.opacity(0.7))

                        TextField("예: Adobe Premiere Pro 2025", text: $viewModel.targetApplicationName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))

                        squareIconButton(icon: "arrow.clockwise") {
                            viewModel.refreshRunningApplications()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(surfaceColor)
                    )
                }
            }

            HStack(spacing: 10) {
                compactPrimaryButton(
                    title: viewModel.isMonitoring ? "감시 중지" : "감시 시작",
                    icon: viewModel.isMonitoring ? "stop.fill" : "play.fill",
                    destructive: viewModel.isMonitoring,
                    disabled: !viewModel.isMonitoring && !viewModel.canStartWatching
                ) {
                    if viewModel.isMonitoring {
                        viewModel.stopWatching()
                    } else {
                        viewModel.startWatching()
                    }
                }

                compactSecondaryButton(title: "전체 열기", icon: "arrow.up.right.square") {
                    selectedSection = .renderNoti
                }
            }
        }
    }

    private var projectChatDashboardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !isCollaborationUnlocked {
                compactNote(text: "협업 기능은 Firebase 로그인 후 사용할 수 있습니다. 로그인하면 최근 대화와 강조 메시지를 볼 수 있습니다.")
            } else if let bannerMessage = projectChatManager.bannerMessage, !bannerMessage.isEmpty {
                compactNote(text: bannerMessage)
            } else if !projectChatManager.highlightedMessages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(projectChatManager.highlightedMessages.prefix(3))) { item in
                        dashboardUpdateRow(
                            title: item.roomName,
                            subtitle: item.text,
                            trailing: item.keyword
                        )
                    }
                }
            } else if !projectChatManager.allRooms.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(projectChatManager.allRooms.prefix(3))) { room in
                        dashboardUpdateRow(
                            title: room.name,
                            subtitle: room.lastMessageText.isEmpty ? "최근 메시지가 아직 없습니다." : room.lastMessageText,
                            trailing: projectName(for: room.projectID)
                        )
                    }
                }
            } else {
                compactNote(text: "최근 대화 변경 사항이 아직 없습니다. \(PortalFeatureNaming.teamMessenger)를 열면 최신 흐름을 확인할 수 있습니다.")
            }

            HStack(spacing: 10) {
                compactPrimaryButton(
                    title: "\(PortalFeatureNaming.teamMessenger) 열기",
                    icon: "bubble.left.and.bubble.right.fill",
                    destructive: false,
                    disabled: false
                ) {
                    selectedSection = .projectChat
                }
            }
        }
    }

    private var notionHubDashboardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !isCollaborationUnlocked {
                compactNote(text: "협업 기능은 Firebase 로그인 후 사용할 수 있습니다. 로그인하면 최근 프로젝트 상태를 여기에 표시합니다.")
            } else if notionHubViewModel.isLoadingProjects {
                compactNote(text: "프로젝트 상태를 불러오는 중입니다.")
            } else if let errorMessage = notionHubViewModel.errorMessage {
                compactNote(text: errorMessage)
            } else if notionHubViewModel.projects.isEmpty {
                compactNote(text: "표시할 프로젝트가 아직 없습니다. \(PortalFeatureNaming.notionConnector)를 열어 연결 상태를 확인해 주세요.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(notionHubViewModel.projects.prefix(3))) { project in
                        dashboardUpdateRow(
                            title: project.title,
                            subtitle: project.currentSituation.isEmpty ? project.summary : project.currentSituation,
                            trailing: project.status
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                compactPrimaryButton(
                    title: "\(PortalFeatureNaming.notionConnector) 열기",
                    icon: "books.vertical.fill",
                    destructive: false,
                    disabled: false
                ) {
                    selectedSection = .notionHub
                }
            }
        }
    }

    private var projectArchiveDashboardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !isCollaborationUnlocked {
                compactNote(text: "협업 기능은 Firebase 로그인 후 사용할 수 있습니다. 로그인하면 연결된 프로젝트 허브 요약을 볼 수 있습니다.")
            } else if !projectArchiveManager.archives.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(projectArchiveManager.archives.prefix(3))) { archive in
                        dashboardUpdateRow(
                            title: archive.projectName,
                            subtitle: archive.projectSummary.isEmpty
                                ? "요약이 등록되지 않았습니다."
                                : archive.projectSummary,
                            trailing: archive.notionProjectTitle?.isEmpty == false
                                ? (archive.notionProjectTitle ?? "노션 연결")
                                : "바로가기"
                        )
                    }
                }
            } else {
                compactNote(text: "\(PortalFeatureNaming.projectHub)가 없습니다. 새 \(PortalFeatureNaming.projectHub)를 생성한 뒤 프로젝트 링크를 관리하세요.")
            }

            HStack(spacing: 10) {
                compactPrimaryButton(
                    title: "\(PortalFeatureNaming.projectHub) 열기",
                    icon: "archivebox",
                    destructive: false,
                    disabled: false
                ) {
                    selectedSection = .projectArchive
                }
            }
        }
    }

    private var wakeUpLeafCompactContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("WakeUp Leaf 방식", selection: $sleepManager.mode) {
                ForEach(SleepGuardManager.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch sleepManager.mode {
            case .duration:
                HStack(spacing: 10) {
                    ForEach([10, 30, 60, 120], id: \.self) { preset in
                        Button {
                            sleepManager.durationMinutes = preset
                            wakeUpLeafDurationInputText = ""
                        } label: {
                            Text("\(preset)분")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(sleepManager.durationMinutes == preset ? Color.white : Color.black.opacity(0.72))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(sleepManager.durationMinutes == preset ? themeColor : Color.white)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.black.opacity(sleepManager.durationMinutes == preset ? 0 : 0.06), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeColor.opacity(0.7))

                    TextField(
                        "직접 입력",
                        text: Binding(
                            get: { wakeUpLeafDurationInputText },
                            set: { value in
                                let digits = value.filter(\.isNumber)
                                wakeUpLeafDurationInputText = digits
                                if let parsed = Int(digits), !digits.isEmpty {
                                    sleepManager.durationMinutes = min(max(1, parsed), 24 * 60)
                                }
                            }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(width: 92, alignment: .leading)

                    Text("분")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.5))

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(surfaceColor)
                )
            case .unlimited:
                compactNote(text: "최대 24시간 동안 절전 방지를 유지합니다.")
            case .appExit:
                HStack(spacing: 12) {
                    Picker("대상 앱", selection: $sleepManager.selectedAppBundleId) {
                        Text("대상 앱 선택").tag("")
                        ForEach(wakeUpLeafApps) { app in
                            Text(app.name).tag(app.bundleId)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    squareIconButton(icon: "arrow.clockwise") {
                        wakeUpLeafApps = sleepManager.candidateApps()
                        sleepManager.refreshSelectedAppName()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(surfaceColor)
                )
            }

            HStack(spacing: 10) {
                compactPrimaryButton(
                    title: sleepManager.isKeepingAwake ? "WakeUp Leaf 중지" : "WakeUp Leaf 시작",
                    icon: sleepManager.isKeepingAwake ? "stop.fill" : "play.fill",
                    destructive: sleepManager.isKeepingAwake,
                    disabled: !sleepManager.isKeepingAwake && sleepManager.mode == .appExit && sleepManager.selectedAppBundleId.isEmpty
                ) {
                    if sleepManager.isKeepingAwake {
                        sleepManager.stop()
                    } else {
                        _ = sleepManager.start()
                    }
                }

                compactSecondaryButton(title: "전체 열기", icon: "arrow.up.right.square") {
                    selectedSection = .sleepGuard
                }
            }
        }
        .onChange(of: sleepManager.mode) { _, mode in
            if mode == .appExit {
                wakeUpLeafApps = sleepManager.candidateApps()
            }
        }
    }

    private func toolAccordionCard<Content: View>(
        tool: PortalOverviewToolCard,
        title: String,
        subtitle: String,
        status: String,
        icon: String,
        accent: Color,
        isExpanded: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        PortalCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        toggle(tool)
                    }
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accent.opacity(0.1))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(accent.opacity(0.9))
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.84))
                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.46))
                        }

                        Spacer()

                        PortalTagPill(
                            title: status,
                            tint: status == "실행 중" ? accent : Color.black.opacity(0.55),
                            background: Color.white
                        )
                        .overlay(
                            Capsule()
                                .stroke((status == "실행 중" ? accent : Color.black).opacity(0.18), lineWidth: 1)
                        )

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.35))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding(20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .clickableCursor()

                if isExpanded {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                            .overlay(Color.black.opacity(0.06))
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 0) {
                            content()
                        }
                        .padding(20)
                    }
                    .transition(.accordionReveal)
                }
            }
        }
    }

    private func collaborationCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        PortalCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accent.opacity(0.1))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(accent.opacity(0.92))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.84))
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.46))
                    }

                    Spacer()
                }

                content()
            }
        }
    }

    private func dashboardUpdateRow(title: String, subtitle: String, trailing: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .fill(themeColor.opacity(0.14))
                .frame(width: 8, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .lineLimit(1)

                Text(subtitle.isEmpty ? "요약 정보가 아직 없습니다." : subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            PortalTagPill(title: trailing, tint: Color.black.opacity(0.6), background: surfaceColor)
        }
    }

    private func projectName(for projectID: String) -> String {
        projectChatManager.projects.first(where: { $0.id == projectID })?.name ?? "프로젝트"
    }

    private func toggle(_ tool: PortalOverviewToolCard) {
        if expandedCards.contains(tool) {
            expandedCards.remove(tool)
        } else {
            if tool == .wakeUpLeaf, wakeUpLeafApps.isEmpty {
                wakeUpLeafApps = sleepManager.candidateApps()
                sleepManager.refreshSelectedAppName()
            }
            expandedCards.insert(tool)
        }
    }

    private func compactPrimaryButton(
        title: String,
        icon: String,
        destructive: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        PortalCapsuleActionButton(
            title: title,
            icon: icon,
            filled: !destructive,
            destructive: destructive,
            disabled: disabled,
            tint: themeColor,
            action: action
        )
    }

    private func compactSecondaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        PortalCapsuleActionButton(title: title, icon: icon, action: action)
    }

    private func compactInfoChip(title: String, value: String) -> some View {
        PortalTagPill(
            title: "\(title) \(value)",
            tint: Color.black.opacity(0.74),
            background: surfaceColor
        )
    }

    private func squareIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.58))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .clickableCursor()
    }

    private func compactNote(text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(mutedText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(surfaceColor)
            )
    }
}
