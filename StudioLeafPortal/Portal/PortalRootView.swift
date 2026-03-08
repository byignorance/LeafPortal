import AppKit
import LucideIcons
import SwiftUI

struct PortalRootView: View {
    private enum SettingsPanel: String, CaseIterable, Identifiable {
        case general = "기본 설정"
        case iconManagement = "아이콘 관리"
        case memberManagement = "회원 관리"

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: PortalViewModel
    @ObservedObject var sleepManager: SleepGuardManager
    @ObservedObject var authManager: PortalAuthManager
    @ObservedObject var cloudSyncCoordinator: PortalCloudSyncCoordinator
    @ObservedObject var notionOAuthManager: NotionOAuthManager
    @ObservedObject var notionHubViewModel: NotionHubViewModel
    @ObservedObject var projectChatManager: PortalProjectChatManager
    @ObservedObject var projectArchiveManager: PortalProjectArchiveManager
    @StateObject private var memberDirectoryManager = PortalMemberDirectoryManager()
    @State private var selectedSettingsPanel: SettingsPanel = .general
    @State private var isShowingProjectChatSettingsSheet = false
    @State private var isShowingProjectHubTemplateSettingsSheet = false
    @State private var isShowingExternalStorageAdminSheet = false
    @State private var isClearingNotionSession = false
    @State private var notionSessionStatusLine = "내부 링크는 Notion 웹 세션 로그인 후 같은 창에서 계속 사용할 수 있습니다."

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
                .overlay(Color.black.opacity(0.06))
            mainPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.white)
        .frame(minWidth: 1100, minHeight: 720)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .sheet(isPresented: $isShowingProjectChatSettingsSheet) {
            PortalProjectChatProjectSettingsSheet(
                manager: projectChatManager,
                isShowing: $isShowingProjectChatSettingsSheet
            )
            .frame(minWidth: 560, minHeight: 620)
        }
        .sheet(isPresented: $isShowingProjectHubTemplateSettingsSheet) {
            PortalProjectArchiveTemplateSettingsSheet(
                manager: projectArchiveManager,
                isShowing: $isShowingProjectHubTemplateSettingsSheet
            )
        }
        .sheet(isPresented: $isShowingExternalStorageAdminSheet) {
            PortalExternalStorageAdminSettingsSheet(
                manager: projectArchiveManager,
                isShowing: $isShowingExternalStorageAdminSheet
            )
        }
    }

    private var footer: some View {
        PortalFooterView(
            isSignedIn: authManager.isSignedIn,
            isSigningIn: authManager.status == .signingIn,
            authPrimaryText: authPrimaryText,
            authSecondaryText: authSecondaryText,
            syncLine: footerSyncLine,
            syncState: cloudSyncCoordinator.state,
            avatar: AnyView(authAvatar),
            onSignIn: {
                Task {
                    await authManager.signIn()
                }
            },
            onSignOut: {
                authManager.signOut()
            },
            onOpenSettings: {
                openSettings(panel: .general)
            }
        )
    }

    private var sidebar: some View {
        PortalSidebarView(
            groups: navigationGroups,
            selectedSection: viewModel.selectedSection,
            onSelect: selectSection,
            iconView: { role, size, tint in
                AnyView(roleIcon(role: role, size: size, tint: tint))
            }
        )
    }

    private var mainPanel: some View {
        Group {
            if viewModel.selectedSection == .projectArchive || viewModel.selectedSection == .notionHub || viewModel.selectedSection == .projectChat {
                // High-performance resizable/interactive sections skip global scroll
                VStack(alignment: .leading, spacing: 32) {
                    heroHeader
                    contentForSelectedSection
                        .frame(maxHeight: .infinity)
                }
                .padding(40)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        heroHeader
                        contentForSelectedSection
                    }
                    .padding(40)
                }
            }
        }
        .background(Color.white)
    }

    private var contentForSelectedSection: some View {
        switch viewModel.selectedSection {
        case .overview:
            return AnyView(overviewSection)
        case .projectArchive:
            return AnyView(projectArchiveSection)
        case .projectChat:
            return AnyView(projectChatSection)
        case .notionHub:
            return AnyView(notionHubSection)
        case .renderNoti:
            return AnyView(renderSection)
        case .sleepGuard:
            return AnyView(sleepGuardSection)
        case .activity:
            return AnyView(activitySection)
        case .settings, .iconManagement:
            return AnyView(settingsSection)
        }
    }

    private var heroHeader: some View {
        PortalHeroHeaderView(
            breadcrumbTitle: heroBreadcrumbTitle,
            title: heroTitle,
            subtitle: heroSubtitle,
            heroIconRole: heroIconRole,
            isMonitoring: viewModel.isMonitoring,
            isKeepingAwake: sleepManager.isKeepingAwake,
            showsProjectChatSettings: viewModel.selectedSection == .projectChat,
            isProjectChatSettingsEnabled: projectChatManager.selectedProject != nil,
            onOpenProjectChatSettings: {
                isShowingProjectChatSettingsSheet = true
            },
            iconView: { role, size, tint in
                AnyView(roleIcon(role: role, size: size, tint: tint))
            }
        )
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            sessionBanner

            PortalOverviewToolsSection(
                viewModel: viewModel,
                sleepManager: sleepManager,
                notionHubViewModel: notionHubViewModel,
                projectChatManager: projectChatManager,
                projectArchiveManager: projectArchiveManager,
                isCollaborationUnlocked: authManager.canAccessCollaboration,
                selectedSection: $viewModel.selectedSection
            )

            journeysCard

            HStack(spacing: 24) {
                metricCard(icon: "gauge.with.dots.needle.33percent", tint: Color(red: 0.73, green: 0.93, blue: 0.81), value: "\(max(24, viewModel.observedFileCount * 24))", unit: "fps", label: "평균 흐름")
                metricCard(icon: "thermometer.medium", tint: Color(red: 0.97, green: 0.90, blue: 0.66), value: "\(36 + min(viewModel.observedFileCount, 8))", unit: "°C", label: "시스템 온도")
                metricCard(icon: "clock.fill", tint: Color(red: 0.83, green: 0.90, blue: 0.97), value: "\(viewModel.preliminaryAlertSeconds)·\(viewModel.idleThresholdSeconds)", unit: "초", label: "Simple 기준")
            }
        }
    }

    private var renderSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            sessionBanner
            renderCard
            notificationSettingsCard
            webhookCard
        }
    }

    private var sleepGuardSection: some View {
        SleepGuardSectionView(manager: sleepManager)
    }

    private var projectChatSection: some View {
        Group {
            if authManager.canAccessCollaboration {
                PortalProjectChatSection(
                    manager: projectChatManager,
                    authManager: authManager,
                    viewModel: viewModel,
                    projectArchiveManager: projectArchiveManager
                )
            } else {
                collaborationAccessSection(
                    title: PortalFeatureNaming.teamMessenger,
                    detail: authManager.collaborationAccessDetail(for: PortalFeatureNaming.teamMessenger)
                )
            }
        }
    }

    private var projectArchiveSection: some View {
        Group {
            if authManager.canAccessCollaboration {
                PortalProjectArchiveSection(
                    manager: projectArchiveManager,
                    notionHubViewModel: notionHubViewModel,
                    projectChatManager: projectChatManager,
                    viewModel: viewModel
                )
            } else {
                collaborationAccessSection(
                    title: PortalFeatureNaming.projectHub,
                    detail: authManager.collaborationAccessDetail(for: PortalFeatureNaming.projectHub)
                )
            }
        }
    }

    private var notionHubSection: some View {
        Group {
            if authManager.canAccessCollaboration {
                NotionHubSectionView(
                    viewModel: notionHubViewModel,
                    oauthManager: notionOAuthManager
                )
            .onAppear {
                notionHubViewModel.updateCurrentMember(name: authManager.currentUser?.displayName)
            }
            .onChange(of: authManager.currentUser?.displayName) { _, displayName in
                notionHubViewModel.updateCurrentMember(name: displayName)
            }
            } else {
                collaborationAccessSection(
                    title: PortalFeatureNaming.notionConnector,
                    detail: authManager.collaborationAccessDetail(for: PortalFeatureNaming.notionConnector)
                )
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                filterChip(title: "기능", value: "전체")
                filterChip(title: "상태", value: "전체")
                filterChip(title: "날짜", value: "오늘")
                Spacer()
                actionButton(title: "로그 비우기", filled: true, disabled: viewModel.activityLogs.isEmpty) {
                    viewModel.clearLogs()
                }
            }

            softCard(padding: 0) {
                VStack(spacing: 0) {
                    HStack {
                        logHeader("시각", width: 150)
                        logHeader("출처", width: 160)
                        logHeader("상태", width: 140)
                        logHeader("이벤트 세부", width: nil)
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.035))

                    if viewModel.activityLogs.isEmpty {
                        VStack(spacing: 10) {
                            Text("아직 기록이 없습니다.")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Render Notification 감시를 시작하면 이곳에 결과가 쌓입니다.")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 56)
                    } else {
                        ForEach(viewModel.activityLogs) { entry in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 15, weight: .bold))
                                    Text(entry.timestamp.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 150, alignment: .leading)

                                HStack(spacing: 12) {
                                    roundedAppBadge
                                    Text("Render Notification")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .frame(width: 160, alignment: .leading)

                                statusPill(kind: entry.kind)
                                    .frame(width: 140, alignment: .leading)

                                Text(entry.detail)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.black.opacity(0.78))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 26)
                            .padding(.vertical, 22)

                            Divider()
                                .padding(.leading, 26)
                        }
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsPanelPicker

            if selectedSettingsPanel == .general {
                softCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("공통 포털 설정")
                            .font(.system(size: 15, weight: .semibold))
                        Text("환경설정 페이지는 studioLEAF Portal 전체에 영향을 주는 정책과 안내만 담당합니다. 앱 실행 정책은 여기서 관리하고, 기능 전용 알림과 감시 기준, 외부 연동은 각 기능 화면 안에서 관리합니다.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                softCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("앱 실행 설정")
                            .font(.system(size: 15, weight: .semibold))

                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                            Text("로그인 시 studioLEAF Portal 실행")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.84))
                                Text("맥 로그인 직후 포털 앱을 자동으로 실행합니다. WakeUp Leaf 전용이 아니라 포털 전체에 적용됩니다.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { sleepManager.launchAtLoginEnabled },
                                    set: { sleepManager.toggleLaunchAtLogin(enabled: $0) }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.10, green: 0.18, blue: 0.14)))
                        }
                    }
                }

                softCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("기능별 설정 이동")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Render Notification의 감시 기준, 사운드, Discord Webhook은 기능 페이지 안에서 조정합니다. 아이콘 관리는 환경설정 내부 메뉴에서 관리합니다.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))

                        HStack(spacing: 12) {
                            actionButton(title: "Render Notification 열기", filled: true, disabled: false) {
                                selectSection(.renderNoti)
                            }

                            actionButton(title: "WakeUp Leaf 열기", filled: false, disabled: false) {
                                selectSection(.sleepGuard)
                            }

                            actionButton(title: "아이콘 관리 열기", filled: false, disabled: false) {
                                selectedSettingsPanel = .iconManagement
                            }
                        }
                    }
                }

                softCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(PortalFeatureNaming.projectHub) 스토리지")
                            .font(.system(size: 15, weight: .semibold))
                        Text("공통 Drive / Dropbox 폴더 템플릿은 여기서 관리하고, 프로젝트별 오버라이드는 각 Project Hub 카드의 스토리지 설정에서 조정합니다.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))

                        HStack(spacing: 12) {
                            actionButton(title: "Project Hub 열기", filled: false, disabled: false) {
                                selectSection(.projectArchive)
                            }

                            actionButton(
                                title: projectArchiveManager.canManageGlobalStorageTemplate ? "스토리지 템플릿 관리" : "스토리지 템플릿 보기",
                                filled: true,
                                disabled: !authManager.isSignedIn
                            ) {
                                isShowingProjectHubTemplateSettingsSheet = true
                            }
                        }
                    }
                }

                softCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("외부 스토리지 계정")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Google Drive / Dropbox 조회 및 업로드는 앱 로그인 계정이 아니라 `pd@studioleaf.kr` 실행 계정으로 처리합니다. 이 패널은 해당 연결 메타와 상태를 관리합니다.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))

                        HStack(spacing: 12) {
                            actionButton(
                                title: projectArchiveManager.canManageGlobalStorageTemplate ? "외부 계정 관리" : "외부 계정 상태 보기",
                                filled: true,
                                disabled: !authManager.isSignedIn
                            ) {
                                isShowingExternalStorageAdminSheet = true
                            }

                            if projectArchiveManager.isLoadingExternalStorageAccounts {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Drive: \(projectArchiveManager.externalStorageAccounts.googleDrive.connectionState.title) · Dropbox: \(projectArchiveManager.externalStorageAccounts.dropbox.connectionState.title)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.55))
                            }
                        }
                    }
                }

                softCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(PortalFeatureNaming.notionConnector) 세션")
                            .font(.system(size: 15, weight: .semibold))
                        Text(notionSessionStatusLine)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            actionButton(title: "Notion Connector 열기", filled: false, disabled: false) {
                                selectSection(.notionHub)
                            }

                            actionButton(
                                title: isClearingNotionSession ? "세션 초기화 중..." : "Notion 세션 초기화",
                                filled: true,
                                disabled: isClearingNotionSession
                            ) {
                                Task {
                                    isClearingNotionSession = true
                                    await NotionWebSessionManager.shared.clearSession()
                                    notionSessionStatusLine = "Notion 웹 세션을 초기화했습니다. 내부 링크를 다시 열면 로그인 페이지가 다시 나타날 수 있습니다."
                                    isClearingNotionSession = false
                                }
                            }
                        }
                    }
                }

                softCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("확장 정책")
                            .font(.system(size: 15, weight: .semibold))
                        Text("새 기능이 추가되면 기능 전용 설정은 해당 기능 섹션 안에서 소유하고, 이 페이지는 공통 포털 정책과 진입점만 유지합니다.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                    }
                }
            } else if selectedSettingsPanel == .iconManagement {
                iconManagementSection
            } else {
                memberManagementSection
            }
        }
    }

    private var settingsPanelPicker: some View {
        HStack(spacing: 8) {
            ForEach(availableSettingsPanels) { panel in
                Button {
                    selectedSettingsPanel = panel
                } label: {
                    Text(panel.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(selectedSettingsPanel == panel ? .white : Color.black.opacity(0.62))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedSettingsPanel == panel ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.black.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .clickableCursor()
            }
        }
    }

    private var memberManagementSection: some View {
        PortalMemberManagementSectionView(
            authManager: authManager,
            manager: memberDirectoryManager
        )
    }

    private var sessionBanner: some View {
        EmptyView() // Removed the heavy gradient banner, using the new flat Watching Path card instead.
    }

    private var renderCard: some View {
        softCard {
            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.08))
                        .frame(width: 42, height: 42)
                        .overlay(
                            roleIcon(
                                role: .sidebarRenderNoti,
                                size: 18,
                                tint: Color(red: 0.10, green: 0.18, blue: 0.14)
                            )
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("감시 상태")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Text("선택한 기준으로 렌더 완료를 실시간 추적합니다.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.45))
                    }

                    Spacer()
                }

                // 1. 상태 바와 시작버튼이 제일 위에
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(red: 0.35, green: 0.80, blue: 0.52))
                            Text(viewModel.detailLine.isEmpty ? "렌더 데이터를 기다리는 중..." : viewModel.detailLine)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.8))
                        }
                        
                        Spacer()

                        HStack(spacing: 12) {
                            let isDisabled = !viewModel.canStartWatching && !viewModel.isMonitoring
                            Button {
                                if viewModel.isMonitoring { viewModel.stopWatching() } else { viewModel.startWatching() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.isMonitoring ? "stop.fill" : "play.fill")
                                        .font(.system(size: 10))
                                    Text(viewModel.isMonitoring ? "감시 중지" : "감시 시작")
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(
                                viewModel.isMonitoring ? Color.red :
                                isDisabled ? Color.black.opacity(0.25) :
                                Color.white
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.isMonitoring ? Color.red.opacity(0.08) :
                                isDisabled ? Color.clear :
                                Color(red: 0.10, green: 0.18, blue: 0.14)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isDisabled ? Color.black.opacity(0.12) : Color.clear, lineWidth: 1)
                            )
                            .clipShape(Capsule())
                            .shadow(color: isDisabled ? .clear : Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.25), radius: 4, y: 2)
                            .disabled(isDisabled)
                            .clickableCursor()
                        }
                    }

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(viewModel.isMonitoring ? Color(red: 0.35, green: 0.80, blue: 0.52) : Color.clear)
                            .frame(width: max(0, min(1, viewModel.progressValue)) * 300, height: 6)
                            .cornerRadius(3)
                    }
                }

                Divider()

                // 2. 판정과 실행 보드
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.08))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "gauge.with.dots.needle.33percent")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                                )
                            Text("판정 기준")
                                .font(.system(size: 16, weight: .bold))
                        }
                        
                        Spacer()
                        
                        Picker("판정 기준", selection: $viewModel.detectionMode) {
                            ForEach(DetectionMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }

                    if viewModel.detectionMode == .simple {
                        // 단순 모드: 감시 대상 (파일/폴더) 선택
                        VStack(alignment: .leading, spacing: 16) {
                            Text("파일/폴더의 변화가 멈춘 시간을 기준으로 렌더 완료를 판단합니다.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))

                            HStack {
                                Text("감시 대상")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                Picker("감시 대상", selection: $viewModel.targetKind) {
                                    ForEach(MonitorTargetKind.allCases) { kind in
                                        Text(kind.rawValue).tag(kind)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                            }

                            HStack(spacing: 12) {
                                Image(systemName: viewModel.targetKind == .file ? "doc.fill" : "folder.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.5))

                                Text(viewModel.selectedPathDisplay)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(viewModel.selectedPath == nil ? Color.black.opacity(0.35) : Color.black.opacity(0.85))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                Button {
                                    viewModel.selectTarget()
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.5))
                                        .frame(width: 28, height: 28)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                }
                                .buttonStyle(.plain)
                                .clickableCursor()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.96, green: 0.97, blue: 0.97))
                            .cornerRadius(10)
                        }
                    } else {
                        // 고도화 모드: 프로그램 선택
                        VStack(alignment: .leading, spacing: 16) {
                            Text("대상 프로그램의 CPU 활동을 렌더 시작과 종료를 판단합니다.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))

                            HStack(spacing: 12) {
                                Image(systemName: "app.dashed")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.5))

                                TextField("예: Adobe Premiere Pro 2025", text: $viewModel.targetApplicationName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))

                                Spacer()

                                Menu {
                                    if !viewModel.recentTargetApplications.isEmpty {
                                        Section("최근 선택") {
                                            ForEach(viewModel.recentTargetApplications, id: \.self) { appName in
                                                Button(appName) { viewModel.selectTargetApplicationName(appName) }
                                            }
                                        }
                                    }
                                    if !viewModel.adobeRunningApplications.isEmpty {
                                        Section("Adobe 계열") {
                                            ForEach(viewModel.adobeRunningApplications, id: \.self) { appName in
                                                Button(appName) { viewModel.selectTargetApplicationName(appName) }
                                            }
                                        }
                                    }
                                    if !viewModel.otherRunningApplications.isEmpty {
                                        Section("기타 실행 중인 앱") {
                                            ForEach(viewModel.otherRunningApplications, id: \.self) { appName in
                                                Button(appName) { viewModel.selectTargetApplicationName(appName) }
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.5))
                                        .frame(width: 28, height: 28)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .clickableCursor()
                                
                                Button {
                                    viewModel.refreshRunningApplications()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.black.opacity(0.5))
                                        .frame(width: 28, height: 28)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                }
                                .buttonStyle(.plain)
                                .clickableCursor()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.96, green: 0.97, blue: 0.97))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private var journeysCard: some View {
        softCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    roleIcon(role: .journeys, size: 18, tint: Color(red: 0.55, green: 0.61, blue: 0.72))
                    Text("최근 기록")
                        .font(.system(size: 22, weight: .black))
                }

                if viewModel.activityLogs.isEmpty {
                    Text("아직 최근 여정이 없습니다.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.activityLogs.prefix(2)) { entry in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(color(for: entry.kind).opacity(0.15))
                                .frame(width: 58, height: 58)
                                .overlay(
                                    Image(systemName: entry.kind == .success ? "checkmark.circle" : entry.kind == .warning ? "clock.arrow.circlepath" : "exclamationmark.triangle")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(color(for: entry.kind))
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.detail)
                                    .font(.system(size: 15, weight: .semibold))
                                    .lineLimit(1)
                                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(entry.kind.title)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.04))
                                .clipShape(Capsule())
                        }

                        if entry.id != viewModel.activityLogs.prefix(2).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var notificationSettingsCard: some View {
        softCard {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.08))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                        )
                    Text("알림 설정")
                        .font(.system(size: 18, weight: .bold))
                }

                VStack(spacing: 20) {
                    HStack(alignment: .top, spacing: 0) {
                        // macOS 알림
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(Color.black.opacity(0.7))
                                Toggle("macOS 알림", isOn: $viewModel.notificationEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.10, green: 0.18, blue: 0.14)))
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text("렌더 완료 이벤트를 시스템 알림 배너로 표시합니다.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 24)

                        // 시스템 사운드
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(Color.black.opacity(0.7))
                                Toggle("시스템 사운드", isOn: $viewModel.soundEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.10, green: 0.18, blue: 0.14)))
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text("완료 시 설정된 사운드를 재생합니다.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if viewModel.soundEnabled {
                        Divider()
                        
                        VStack(spacing: 12) {
                            soundPickerRow(
                                title: "1차 알림",
                                subtitle: "\(viewModel.preliminaryAlertSeconds)초 정지 시 재생",
                                selection: $viewModel.preliminarySoundName,
                                options: SoundOption.systemOptions,
                                importAction: viewModel.importPreliminarySound
                            )
                            soundPickerRow(
                                title: "확정 알림",
                                subtitle: "렌더 확정 판단시 재생",
                                selection: $viewModel.completionSoundName,
                                options: SoundOption.completionOptions,
                                importAction: viewModel.importCompletionSound
                            )
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                    .foregroundStyle(Color.black.opacity(0.7))
                                Toggle("Messages (Mac)", isOn: $viewModel.messagesEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.10, green: 0.18, blue: 0.14)))
                                    .font(.system(size: 15, weight: .bold))
                                    .clickableCursor()
                            }
                            
                            Text("이 Mac의 Messages 앱으로 완료 알림을 보냅니다.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.black.opacity(0.42))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.messagesEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("받는 사람")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.5))
                                    
                                    customTextField("전화번호 또는 Apple ID 이메일", text: $viewModel.messagesRecipient)
                                }

                                HStack(alignment: .top, spacing: 20) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("전송 방식")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.5))
                                        Picker("전송 방식", selection: $viewModel.messagesServiceMode) {
                                            ForEach(MessagesServiceMode.allCases) { mode in
                                                Text(mode.rawValue).tag(mode)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 180)
                                        .clickableCursor()
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("테스트")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.5))
                                        secondaryButton(title: "테스트 전송") {
                                            viewModel.sendMessagesTest()
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("메시지 내용")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.5))
                                    
                                    customTextField("Render Notification: {target} 렌더 완료 ({time})", text: $viewModel.messagesTemplate, isVertical: true)
                                    
                                    Text("{target}, {time}, {app} 치환자를 사용할 수 있습니다.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.black.opacity(0.42))
                                        .padding(.leading, 4)
                                }

                                InlineAlert(text: "이 Mac의 Messages 앱에 로그인되어 있어야 합니다. 한국 번호는 01012345678처럼 입력해도 자동으로 포맷팅을 시도합니다.")
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.96, green: 0.97, blue: 0.97).opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var webhookCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        roleIcon(role: .webhook, size: 15, tint: Color.orange.opacity(0.7))
                        Text("Discord Webhook")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.8))
                        
                        Spacer()
                        
                        Text("개발 예정")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange.opacity(0.7))
                    }
                    Text("원격 수신 채널 후보입니다. 현재는 설정 저장만 가능합니다.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.black.opacity(0.45))
                }

                Spacer()

                Text("개발 전")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.orange.opacity(0.8))
            }
            .padding(16)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.96, green: 0.97, blue: 0.97))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(0.12), lineWidth: 1)
                    )
            )

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Discord 채널 선택", isOn: $viewModel.discordEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color.orange.opacity(0.8)))
                    .font(.system(size: 14, weight: .bold))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Webhook URL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.5))
                    
                    customTextField("https://discord.com/api/webhooks/...", text: $viewModel.webhookURLString)
                }
                .opacity(viewModel.discordEnabled ? 1 : 0.55)

                Text("Discord는 아직 개발 전입니다. 지금은 추후 연결을 위해 선택과 URL 입력만 저장합니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange.opacity(0.9))
            }
        }
    }

    private func soundPickerRow(
        title: String,
        subtitle: String,
        selection: Binding<String>,
        options: [SoundOption],
        importAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.46))
                if let localURL = SoundOption.localFileURL(from: selection.wrappedValue) {
                    Text("선택 파일: \(localURL.lastPathComponent)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.74))
                }
            }

            Spacer()

            Picker(title, selection: selection) {
                if SoundOption.localFileURL(from: selection.wrappedValue) != nil {
                    Text(SoundOption.title(for: selection.wrappedValue, options: options)).tag(selection.wrappedValue)
                }
                ForEach(options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            .clickableCursor()

            secondaryButton(title: "파일 선택") {
                importAction()
            }

            secondaryButton(title: "미리듣기") {
                viewModel.previewSound(named: selection.wrappedValue)
            }
        }
    }

    private var iconManagementSection: some View {
        PortalIconManagementSection(viewModel: viewModel)
    }

    // Top tab removed, using breadcrumbs in hero header instead.

    private func softCard<Content: View>(padding: CGFloat = 24, @ViewBuilder content: @escaping () -> Content) -> some View {
        PortalCard(padding: padding, content: content)
    }

    private func metricCard(icon: String, tint: Color, value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.85))
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.4))
                }
                
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.black.opacity(0.5))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.98, green: 0.98, blue: 0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // settingRow has been replaced by toggleCard

    private func filterChip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(Color.black.opacity(0.4))
            Text(value)
                .foregroundStyle(Color.black.opacity(0.8))
        }
        .font(.system(size: 11, weight: .bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func actionButton(title: String, filled: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(filled ? Color.white : (disabled ? Color.secondary : Color.black.opacity(0.8)))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            filled
                            ? (disabled ? Color.gray.opacity(0.35) : Color(red: 0.10, green: 0.18, blue: 0.14))
                            : Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(filled ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .clickableCursor(enabled: !disabled)
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            secondaryButtonLabel(title: title)
        }
        .buttonStyle(.plain)
        .clickableCursor()
    }

    private func secondaryButtonLabel(title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.76))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }

    private func customTextField(_ prompt: String, text: Binding<String>, isVertical: Bool = false) -> some View {
        Group {
            if isVertical {
                TextField(prompt, text: text, axis: .vertical)
                    .lineLimit(3...6)
            } else {
                TextField(prompt, text: text)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func logHeader(_ title: String, width: CGFloat?) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(Color.black.opacity(0.4))
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private var roundedAppBadge: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.68, green: 0.10, blue: 0.12))
            .frame(width: 34, height: 34)
            .overlay(
                Text("Pr")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    private func statusPill(kind: ActivityLogEntry.Kind) -> some View {
        HStack(spacing: 6) {
            Image(systemName: kind == .success ? "checkmark.circle.fill" : kind == .warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .font(.system(size: 10))
            Text(kind.title)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(color(for: kind))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .stroke(color(for: kind).opacity(0.3), lineWidth: 1)
        )
    }

    private var heroTitle: String {
        switch viewModel.selectedSection {
        case .overview:
            return "studioLEAF 포털"
        case .projectChat:
            return PortalFeatureNaming.teamMessenger
        case .projectArchive:
            return PortalFeatureNaming.projectHub
        case .notionHub:
            return PortalFeatureNaming.notionConnector
        case .renderNoti:
            return "Render Notification"
        case .sleepGuard:
            return "WakeUp Leaf"
        case .activity:
            return "스튜디오 기록"
        case .settings:
            return "환경설정"
        case .iconManagement:
            return "아이콘 관리"
        }
    }

    private var heroBreadcrumbTitle: String {
        switch viewModel.selectedSection {
        case .overview:
            return "앱 포털"
        case .renderNoti:
            return "Render Noti"
        default:
            return heroTitle
        }
    }

    private var navigationGroups: [PortalNavigationGroupModel] {
        [
            PortalNavigationGroupModel(
                title: "협업",
                items: [
                    PortalNavigationItemModel(section: .projectArchive, title: PortalFeatureNaming.projectHub, iconRole: .sidebarProjectArchive),
                    PortalNavigationItemModel(section: .projectChat, title: PortalFeatureNaming.teamMessenger, iconRole: .sidebarProjectChat),
                    PortalNavigationItemModel(section: .notionHub, title: PortalFeatureNaming.notionConnector, iconRole: .sidebarNotionHub)
                ]
            ),
            PortalNavigationGroupModel(
                title: "도구",
                items: [
                    PortalNavigationItemModel(section: .renderNoti, title: "Render Noti", iconRole: .sidebarRenderNoti),
                    PortalNavigationItemModel(section: .sleepGuard, title: "WakeUp Leaf", iconRole: .sidebarSleepGuard)
                ]
            ),
            PortalNavigationGroupModel(
                title: "설정",
                items: [
                    PortalNavigationItemModel(section: .activity, title: "활동 로그", iconRole: .sidebarActivity),
                    PortalNavigationItemModel(section: .settings, title: "환경설정", iconRole: .sidebarSettings)
                ]
            )
        ]
    }

    private var heroSubtitle: String {
        switch viewModel.selectedSection {
        case .overview:
            return "통합 대시보드"
        case .projectChat:
            return "팀 협업 메신저"
        case .projectArchive:
            return "프로젝트 자료 허브와 연결 관리"
        case .notionHub:
            return "노션 프로젝트 연결 허브"
        case .renderNoti:
            return "렌더 완료를 감시하고 알림으로 알려줍니다."
        case .sleepGuard:
            return "맥이 잠들지 않도록 시간 또는 앱 기준으로 유지합니다."
        case .activity:
            return "활동 아카이브"
        case .settings:
            return "앱 기본 설정"
        case .iconManagement:
            return "비주얼 커스터마이징"
        }
    }

    private var heroIconRole: PortalIconRole {
        switch viewModel.selectedSection {
        case .overview:
            return .sidebarOverview
        case .projectChat:
            return .sidebarProjectChat
        case .projectArchive:
            return .sidebarProjectArchive
        case .notionHub:
            return .sidebarNotionHub
        case .renderNoti:
            return .sidebarRenderNoti
        case .sleepGuard:
            return .sidebarSleepGuard
        case .activity:
            return .sidebarActivity
        case .settings:
            return .sidebarSettings
        case .iconManagement:
            return .sidebarIconManagement
        }
    }

    private func selectSection(_ section: PortalSection) {
        if section == .settings {
            selectedSettingsPanel = .general
        } else if section == .iconManagement {
            viewModel.selectedSection = .settings
            selectedSettingsPanel = .iconManagement
            return
        }

        viewModel.selectedSection = section
    }

    private func openSettings(panel: SettingsPanel) {
        if panel == .memberManagement && !authManager.isAdmin {
            selectedSettingsPanel = .general
        } else {
            selectedSettingsPanel = panel
        }
        viewModel.selectedSection = .settings
    }

    private var availableSettingsPanels: [SettingsPanel] {
        authManager.isAdmin ? [.general, .iconManagement, .memberManagement] : [.general, .iconManagement]
    }

    private func collaborationAccessSection(title: String, detail: String) -> some View {
        softCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.84))

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.black.opacity(0.54))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    actionButton(
                        title: authManager.status == .signingIn ? "로그인 중..." : "Firebase 로그인",
                        filled: true,
                        disabled: authManager.status == .signingIn || authManager.isSignedIn
                    ) {
                        Task {
                            await authManager.signIn()
                        }
                    }

                    actionButton(title: "대시보드로 이동", filled: false, disabled: false) {
                        viewModel.selectedSection = .overview
                    }
                }
            }
        }
    }

    private func color(for kind: ActivityLogEntry.Kind) -> Color {
        switch kind {
        case .success:
            return Color(red: 0.14, green: 0.62, blue: 0.38)
        case .warning:
            return Color(red: 0.86, green: 0.56, blue: 0.12)
        case .error:
            return Color(red: 0.83, green: 0.24, blue: 0.18)
        }
    }

    private var authPrimaryText: String {
        if let currentUser = authManager.currentUser {
            return currentUser.displayName
        }
        return authManager.statusLine
    }

    private var authSecondaryText: String {
        if let currentUser = authManager.currentUser {
            return currentUser.email
        }
        return "로그인 필요"
    }

    private var footerSyncLine: String {
        let timeText: String

        switch cloudSyncCoordinator.state {
        case .synced(let date):
            timeText = date.formatted(date: .omitted, time: .shortened)
        case .syncing:
            timeText = "동기화 중"
        case .pendingChanges:
            timeText = "변경 대기"
        case .failed:
            timeText = "오류"
        case .idle:
            timeText = authManager.isSignedIn ? "아직 없음" : "로그인 필요"
        }

        return "마지막 동기화 시점 : \(timeText)"
    }

    @ViewBuilder
    private var authAvatar: some View {
        if let photoURL = authManager.currentUser?.photoURL {
            AsyncImage(url: photoURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                initialsAvatar
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        Circle()
            .fill(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.12))
            .frame(width: 34, height: 34)
            .overlay(
                Text(authManager.currentUser?.initials ?? "G")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
            )
    }

    @ViewBuilder
    private func roleIcon(role: PortalIconRole, size: CGFloat, tint: Color) -> some View {
        switch viewModel.selection(for: role) {
        case .custom:
            if let asset = viewModel.customIcon(for: role),
               let image = NSImage(contentsOf: asset.fileURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: role.defaultSymbol)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(tint)
            }
        case .lucide(let lucideID):
            if let image = lucideImage(named: lucideID) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundStyle(tint)
            } else {
                Image(systemName: role.defaultSymbol)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(tint)
            }
        case .system:
            Image(systemName: viewModel.symbol(for: role))
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint)
        }
    }

    private func lucideImage(named lucideID: String) -> NSImage? {
        guard let image = NSImage.image(lucideId: lucideID)?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        return image
    }

}

struct InlineAlert: View {
    let text: String
    var isWarning: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(
                    isWarning
                    ? Color(red: 0.86, green: 0.56, blue: 0.12)
                    : Color(red: 0.18, green: 0.56, blue: 0.34)
                )
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.78))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isWarning
                    ? Color(red: 0.99, green: 0.95, blue: 0.88)
                    : Color(red: 0.92, green: 0.97, blue: 0.93)
                )
        )
    }
}

struct ClickableCursorModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content.onHover { hovering in
            guard enabled else { return }
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

extension View {
    func clickableCursor(enabled: Bool = true) -> some View {
        modifier(ClickableCursorModifier(enabled: enabled))
    }
}
