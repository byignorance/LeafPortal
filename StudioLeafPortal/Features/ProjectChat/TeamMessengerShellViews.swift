import SwiftUI

struct TeamMessengerWorkspaceView: View {
    let leftColumn: AnyView
    let rightColumn: AnyView

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftColumn
                .frame(width: 280)
                .background(Color.white)

            Divider()
                .frame(width: 1)
                .overlay(Color.black.opacity(0.14))

            rightColumn
        }
    }
}

struct TeamMessengerLeftColumnView: View {
    let topBar: AnyView
    let content: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color.white)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                        .padding(.horizontal, 24)
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

struct TeamMessengerHeaderBarView: View {
    let roomName: String
    let canOpenProjectHub: Bool
    let onOpenProjectHub: () -> Void
    let isSearchVisible: Bool
    let onToggleSearch: () -> Void
    let showsRoomSettings: Bool
    let onOpenRoomSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.6))

            Text(roomName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))

            Spacer()

            if canOpenProjectHub {
                PortalCapsuleActionButton(
                    title: "\(PortalFeatureNaming.projectHub) 열기",
                    filled: true,
                    tint: Color(red: 0.10, green: 0.18, blue: 0.14),
                    action: onOpenProjectHub
                )
            }

            if showsRoomSettings {
                Button(action: onToggleSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSearchVisible ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.black.opacity(0.4))
                        .padding(8)
                        .background(isSearchVisible ? Color.black.opacity(0.05) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .clickableCursor()

                Button(action: onOpenRoomSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                        .padding(8)
                        .background(Color.black.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("메신저 룸 설정")
                .clickableCursor()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(VStack { Spacer(); Divider() })
    }
}

struct TeamMessengerSearchBarView: View {
    @Binding var text: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.3))

                TextField("대화 내용 검색...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.black.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()
        }
        .background(Color.white)
    }
}

struct TeamMessengerPlaceholderView: View {
    let title: String

    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.42))
                .padding(40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TeamMessengerSignedOutStateView: View {
    let isSigningIn: Bool
    let onSignIn: () -> Void

    var body: some View {
        PortalCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(PortalFeatureNaming.teamMessenger)는 로그인 후 사용할 수 있습니다.")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.86))

                Text("Google 계정으로 로그인하면 \(PortalFeatureNaming.teamMessenger) 프로젝트, 참여자 제한, 설정 동기화를 같은 계정 단위로 사용할 수 있습니다.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onSignIn) {
                    Text(isSigningIn ? "연결 중..." : "Google로 로그인")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.10, green: 0.18, blue: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isSigningIn)
                .opacity(isSigningIn ? 0.65 : 1)
                .clickableCursor(enabled: !isSigningIn)
            }
        }
    }
}

struct TeamMessengerProjectCreationSheetView: View {
    @ObservedObject var manager: PortalProjectChatManager
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("새 \(PortalFeatureNaming.teamMessenger) 프로젝트")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("닫기") {
                    isShowing = false
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            PortalCard(padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("새 \(PortalFeatureNaming.teamMessenger) 프로젝트")
                        .font(.system(size: 16, weight: .bold))

                    Text("\(PortalFeatureNaming.projectHub)와 별개로 프로젝트 단위 메신저를 바로 만들 수 있습니다.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.black.opacity(0.55))

                    TextField("프로젝트 이름", text: $manager.projectNameDraft)
                        .textFieldStyle(.roundedBorder)

                    TextField("프로젝트 설명", text: $manager.projectSummaryDraft, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)

                    TextField("초대 이메일, 콤마로 구분", text: $manager.inviteEmailsDraft, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        PortalTagPill(
                            title: manager.statusLine,
                            tint: Color.black.opacity(0.72),
                            background: Color(red: 0.91, green: 0.95, blue: 0.99)
                        )

                        Spacer()

                        PortalCapsuleActionButton(
                            title: manager.isCreatingProject ? "생성 중..." : "프로젝트 만들기",
                            filled: true,
                            disabled: manager.isCreatingProject,
                            tint: Color(red: 0.10, green: 0.18, blue: 0.14)
                        ) {
                            Task {
                                await manager.createProject()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            manager.projectNameDraft = ""
            manager.projectSummaryDraft = ""
            manager.inviteEmailsDraft = ""
        }
        .frame(minWidth: 520, minHeight: 460)
    }
}

struct TeamMessengerThreadContainerView<Content: View>: View {
    let title: String
    let subtitle: String
    let statusTitle: String
    let pinnedCount: Int
    let keywordCount: Int
    let activePanel: String?
    let onTogglePinned: () -> Void
    let onToggleKeyword: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String,
        statusTitle: String,
        pinnedCount: Int,
        keywordCount: Int,
        activePanel: String?,
        onTogglePinned: @escaping () -> Void,
        onToggleKeyword: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusTitle = statusTitle
        self.pinnedCount = pinnedCount
        self.keywordCount = keywordCount
        self.activePanel = activePanel
        self.onTogglePinned = onTogglePinned
        self.onToggleKeyword = onToggleKeyword
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.84))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.46))
                }

                Spacer()

                HStack(spacing: 8) {
                    focusChip(title: "고정", count: pinnedCount, isActive: activePanel == "pinned", action: onTogglePinned)
                    focusChip(title: "주요키워드", count: keywordCount, isActive: activePanel == "keywords", action: onToggleKeyword)
                    PortalTagPill(title: statusTitle, tint: Color.black.opacity(0.72), background: Color(red: 0.95, green: 0.97, blue: 0.96))
                }
            }
            .padding(.bottom, 8)

            content()
        }
    }

    private func focusChip(title: String, count: Int, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isActive ? Color.white.opacity(0.18) : Color.black.opacity(0.05))
                        )
                }
            }
            .foregroundStyle(isActive ? Color.white : Color(red: 0.10, green: 0.18, blue: 0.14))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color(red: 0.95, green: 0.97, blue: 0.96))
            )
        }
        .buttonStyle(.plain)
        .clickableCursor()
    }
}

struct TeamMessengerComposerContainerView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Divider()
                    .allowsHitTesting(false)
            }
    }
}

struct TeamMessengerSettingsSheetShell<Content: View>: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.52))
                }

                Spacer()

                Button("닫기") {
                    onClose()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.black.opacity(0.62))
                .padding(.top, 4)
            }

            content()
        }
        .padding(22)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
    }
}
