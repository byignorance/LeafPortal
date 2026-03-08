import SwiftUI

struct PortalNavigationGroupModel: Identifiable {
    let title: String
    let items: [PortalNavigationItemModel]

    var id: String { title }
}

struct PortalNavigationItemModel: Identifiable {
    let section: PortalSection
    let title: String
    let iconRole: PortalIconRole

    var id: String { section.id }
}

struct PortalSidebarView: View {
    let groups: [PortalNavigationGroupModel]
    let selectedSection: PortalSection
    let onSelect: (PortalSection) -> Void
    let iconView: (PortalIconRole, CGFloat, Color) -> AnyView

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Button {
                        onSelect(.overview)
                    } label: {
                        HStack(spacing: 14) {
                            Image(.appLogo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 9))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("LEAF PORTAL")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.88))
                                Text("Dashboard")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(0.5)
                                    .foregroundStyle(Color.black.opacity(0.38))
                            }

                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .clickableCursor()
                    .padding(.top, 38)
                    .padding(.horizontal, 24)

                    VStack(spacing: 24) {
                        ForEach(groups) { group in
                            sidebarGroup(group)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 24)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .defaultScrollAnchor(.top)
        }
        .frame(width: 250, alignment: .topLeading)
        .background(Color(red: 0.96, green: 0.97, blue: 0.97))
    }

    private func sidebarGroup(_ group: PortalNavigationGroupModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.title)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Color.black.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

            ForEach(group.items) { item in
                Button {
                    onSelect(item.section)
                } label: {
                    HStack(spacing: 12) {
                        iconView(
                            item.iconRole,
                            15,
                            selectedSection == item.section ? .white : Color.black.opacity(0.7)
                        )
                        .frame(width: 18)

                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        if selectedSection == item.section {
                            Circle()
                                .fill(Color(red: 0.35, green: 0.80, blue: 0.52))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundStyle(selectedSection == item.section ? Color.white : Color.black.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSection == item.section ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .clickableCursor()
            }
        }
    }
}

struct PortalHeroHeaderView: View {
    let breadcrumbTitle: String
    let title: String
    let subtitle: String
    let heroIconRole: PortalIconRole
    let isMonitoring: Bool
    let isKeepingAwake: Bool
    let showsProjectChatSettings: Bool
    let isProjectChatSettingsEnabled: Bool
    let onOpenProjectChatSettings: () -> Void
    let iconView: (PortalIconRole, CGFloat, Color) -> AnyView

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("LEAF PORTAL")
                        .foregroundStyle(Color.black.opacity(0.4))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.3))
                    Text(breadcrumbTitle)
                        .foregroundStyle(Color.black.opacity(0.8))
                }
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.08))
                        .frame(width: 34, height: 34)
                        .overlay(
                            iconView(
                                heroIconRole,
                                16,
                                Color(red: 0.10, green: 0.18, blue: 0.14)
                            )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 10) {
                            Text(title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            if showsProjectChatSettings {
                                Button(action: onOpenProjectChatSettings) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.08))
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("\(PortalFeatureNaming.teamMessenger) 설정")
                                .disabled(!isProjectChatSettingsEnabled)
                                .opacity(isProjectChatSettingsEnabled ? 1 : 0.45)
                                .clickableCursor(enabled: isProjectChatSettingsEnabled)
                            }
                        }

                        Text(subtitle)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(Color.black.opacity(0.36))
                    }
                }
            }

            Spacer()

            if isMonitoring || isKeepingAwake {
                HStack(spacing: 10) {
                    if isMonitoring {
                        PortalStatusBadge(
                            color: Color(red: 0.10, green: 0.18, blue: 0.14),
                            title: "실시간 감시 중"
                        )
                    }
                    if isKeepingAwake {
                        PortalStatusBadge(
                            color: Color(red: 0.35, green: 0.80, blue: 0.52),
                            title: "WakeUp Leaf 활성"
                        )
                    }
                }
            }
        }
        .padding(.bottom, 10)
    }
}

struct PortalFooterView: View {
    let isSignedIn: Bool
    let isSigningIn: Bool
    let authPrimaryText: String
    let authSecondaryText: String
    let syncLine: String
    let syncState: PortalCloudSyncCoordinator.SyncState
    let avatar: AnyView
    let onSignIn: () -> Void
    let onSignOut: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 12) {
                if isSignedIn {
                    avatar

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authPrimaryText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .lineLimit(1)
                        Text(authSecondaryText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.46))
                            .lineLimit(1)
                    }

                    PortalSecondaryButton(title: "로그아웃", action: onSignOut)
                } else {
                    Button(action: onSignIn) {
                        HStack(spacing: 8) {
                            Image(systemName: isSigningIn ? "hourglass" : "globe")
                                .font(.system(size: 11, weight: .bold))
                            Text(isSigningIn ? "연결 중..." : "Google로 로그인")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(red: 0.10, green: 0.18, blue: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.65 : 1)
                    .clickableCursor(enabled: !isSigningIn)
                }
            }

            Divider()
                .frame(height: 22)
                .overlay(Color.black.opacity(0.08))

            HStack(spacing: 12) {
                PortalSyncStatusPill(state: syncState)
                Text(syncLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 24)

            PortalSecondaryButton(
                title: "환경설정",
                icon: "gearshape.fill",
                action: onOpenSettings
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(minHeight: 76)
        .background(
            Color(red: 0.965, green: 0.972, blue: 0.969)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 1)
                }
        )
    }
}
