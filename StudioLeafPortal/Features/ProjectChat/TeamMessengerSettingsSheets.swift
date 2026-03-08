import SwiftUI

struct PortalProjectChatProjectSettingsSheet: View {
    @ObservedObject var manager: PortalProjectChatManager
    @Binding var isShowing: Bool
    @State private var roomPendingDeletion: PortalProjectChatManager.RoomSummary?

    var body: some View {
        TeamMessengerSettingsSheetShell(
            title: PortalFeatureNaming.teamMessenger,
            subtitle: manager.allRooms.isEmpty ? "채팅방이 없습니다." : "전체 채팅방 설정",
            onClose: {
                isShowing = false
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    notificationSettingsCard
                    keywordManagementCard
                    archiveManagementCard
                }
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog(
            "채팅방을 삭제할까요?",
            isPresented: Binding(
                get: { roomPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        roomPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                guard let roomPendingDeletion else { return }
                Task {
                    await manager.deleteRoom(roomPendingDeletion)
                    self.roomPendingDeletion = nil
                }
            }
            Button("취소", role: .cancel) {
                roomPendingDeletion = nil
            }
        } message: {
            if let roomPendingDeletion {
                Text("\"\(roomPendingDeletion.name)\" 채팅방과 그 안의 메시지, 공지, 키워드 보관 데이터가 DB에서 완전히 삭제됩니다.")
            }
        }
    }

    private var notificationSettingsCard: some View {
        TeamMessengerSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                TeamMessengerSettingsSectionHeader(
                    title: "채팅 알림",
                    subtitle: "새 메시지가 오면 macOS 배너와 사운드로 알려줍니다. 기능 전용 설정이라 여기서 관리하는 편이 자연스럽습니다."
                )

                Toggle(isOn: $manager.isChatNotificationEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("macOS 알림")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.78))
                        Text("앱이 켜져 있을 때도 배너 알림을 표시합니다.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.46))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.10, green: 0.18, blue: 0.14)))

                Toggle(isOn: $manager.isChatSoundEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("알림 사운드")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.78))
                        Text("새 메시지 도착 시 선택한 소리를 재생합니다.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.46))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.10, green: 0.18, blue: 0.14)))

                if manager.isChatSoundEnabled {
                    HStack(spacing: 10) {
                        Picker("채팅 알림 소리", selection: $manager.chatNotificationSoundName) {
                            ForEach(SoundOption.systemOptions) { option in
                                Text(option.title).tag(option.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            manager.previewChatNotificationSound()
                        } label: {
                            TeamMessengerSettingsActionText(title: "미리 듣기", filled: false)
                        }
                        .buttonStyle(.plain)
                        .clickableCursor()
                    }
                }

                TeamMessengerSettingsHelperText(text: "기본값은 macOS Pop 사운드입니다. 나중에 필요하면 기능별로 다른 소리나 무음도 더 세분화할 수 있습니다.")
            }
        }
    }

    private var keywordManagementCard: some View {
        TeamMessengerSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                TeamMessengerSettingsSectionHeader(
                    title: "주요 키워드 관리",
                    subtitle: "프로젝트 전체에서 사용할 주요 키워드를 관리합니다."
                )

                if manager.selectedProjectKeywords.isEmpty {
                    TeamMessengerSettingsEmptyCard(
                        title: "등록된 키워드가 없습니다.",
                        detail: manager.canManageSelectedProject ? "입력 후 추가해 보세요." : "이 프로젝트의 키워드는 관리자만 설정할 수 있습니다."
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)]) {
                        ForEach(manager.selectedProjectKeywords, id: \.self) { keyword in
                            HStack(spacing: 8) {
                                Text(keyword)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.72))
                                    .lineLimit(1)

                                if manager.canManageSelectedProject {
                                    Button {
                                        Task {
                                            await manager.removeKeywordFromCurrentProject(keyword)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.red.opacity(0.72))
                                    }
                                    .buttonStyle(.plain)
                                    .clickableCursor()
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.94, green: 0.97, blue: 0.95))
                            )
                        }
                    }
                }

                if manager.canManageSelectedProject {
                    Divider()

                    HStack(spacing: 10) {
                        TextField("예: #기획서", text: $manager.projectKeywordDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(TeamMessengerSettingsFieldBackground())

                        Button {
                            Task {
                                await manager.addKeywordToCurrentProject(manager.projectKeywordDraft)
                            }
                        } label: {
                            TeamMessengerSettingsActionText(title: "추가", filled: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(manager.projectKeywordDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(manager.projectKeywordDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                        .clickableCursor(enabled: !manager.projectKeywordDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    TeamMessengerSettingsHelperText(text: "관리자만 키워드 추가/삭제가 가능합니다.")
                }
            }
        }
    }

    private var archiveManagementCard: some View {
        TeamMessengerSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                TeamMessengerSettingsSectionHeader(
                    title: "채팅방 닫기 관리",
                    subtitle: "전체 채팅방을 닫아 목록에서 숨기고, 필요 시 다시 열 수 있습니다."
                )

                let activeRooms = manager.featureActiveRooms
                let archivedRooms = manager.featureArchivedRooms

                if !activeRooms.isEmpty {
                    TeamMessengerSettingsLabelText(text: "열린 채팅방")

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(activeRooms) { room in
                            HStack {
                                roomSummary(room)
                                Spacer()

                                Button {
                                    Task {
                                        await manager.archiveRoom(room)
                                    }
                                } label: {
                                    TeamMessengerSettingsActionText(title: "닫기", filled: true)
                                }
                                .buttonStyle(.plain)
                                .disabled(!manager.canManageRoom(room))
                                .opacity(manager.canManageRoom(room) ? 1 : 0.5)
                                .clickableCursor(enabled: manager.canManageRoom(room))
                            }
                            .padding(10)
                            .background(TeamMessengerSettingsListBackground())
                        }
                    }

                    Divider()
                }

                TeamMessengerSettingsLabelText(text: "닫힌 채팅방")

                if archivedRooms.isEmpty {
                    TeamMessengerSettingsEmptyCard(
                        title: "닫힌 채팅방이 없습니다.",
                        detail: "닫은 채팅방은 여기에 나타납니다."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(archivedRooms) { room in
                            HStack {
                                roomSummary(room)
                                Spacer()

                                Button {
                                    Task {
                                        await manager.restoreArchivedRoom(room)
                                    }
                                } label: {
                                    TeamMessengerSettingsActionText(title: "다시 열기", filled: false)
                                }
                                .buttonStyle(.plain)
                                .disabled(!manager.canManageRoom(room))
                                .opacity(manager.canManageRoom(room) ? 1 : 0.5)
                                .clickableCursor(enabled: manager.canManageRoom(room))

                                Button {
                                    roomPendingDeletion = room
                                } label: {
                                    TeamMessengerSettingsActionText(title: "삭제", filled: true, tint: .red)
                                }
                                .buttonStyle(.plain)
                                .disabled(!manager.canDeleteRoom(room))
                                .opacity(manager.canDeleteRoom(room) ? 1 : 0.5)
                                .clickableCursor(enabled: manager.canDeleteRoom(room))
                            }
                            .padding(10)
                            .background(TeamMessengerSettingsListBackground())
                        }
                    }
                }

                if !manager.featureActiveRooms.isEmpty || !manager.featureArchivedRooms.isEmpty {
                    TeamMessengerSettingsHelperText(text: "닫기는 보관 상태이며, 닫힌 채팅방에서만 삭제할 수 있습니다.")
                }
            }
        }
    }

    private func roomSummary(_ room: PortalProjectChatManager.RoomSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(room.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.76))

            if !room.memberLine.isEmpty {
                Text(room.memberLine)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
        }
    }
}

struct PortalProjectChatRoomSettingsSheet: View {
    @ObservedObject var manager: PortalProjectChatManager
    @Binding var isShowing: Bool
    @Binding var roomNameDraft: String

    var body: some View {
        TeamMessengerSettingsSheetShell(
            title: "\(PortalFeatureNaming.teamMessenger) 설정",
            subtitle: manager.selectedRoom?.name ?? "채팅방을 선택해 주세요.",
            onClose: {
                isShowing = false
            }
        ) {
            if manager.selectedRoom == nil {
                Spacer()
                Text("채팅방을 선택하세요")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.42))
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        roomInfoCard
                        pinnedSummaryCard
                        keywordSummaryCard
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var roomInfoCard: some View {
        TeamMessengerSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                TeamMessengerSettingsSectionHeader(
                    title: "채팅방 이름",
                    subtitle: "선택된 채팅방 이름을 수정합니다. 열기/닫기는 상단 \(PortalFeatureNaming.teamMessenger) 설정에서 관리합니다."
                )

                TextField("채팅방 이름", text: $roomNameDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(TeamMessengerSettingsFieldBackground())

                HStack {
                    Spacer()

                    Button {
                        Task {
                            await manager.renameSelectedRoom(to: roomNameDraft)
                        }
                    } label: {
                        TeamMessengerSettingsActionText(title: "이름 저장", filled: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(!manager.canRenameSelectedRoom || roomNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(manager.canRenameSelectedRoom ? 1 : 0.5)
                    .clickableCursor(enabled: manager.canRenameSelectedRoom)
                }

                if !manager.canManageSelectedProject {
                    TeamMessengerSettingsHelperText(text: "관리자만 채팅방 이름을 수정할 수 있습니다.")
                } else if manager.selectedRoom == nil {
                    TeamMessengerSettingsHelperText(text: "채팅방을 먼저 선택해 주세요.")
                }
            }
        }
    }

    private var pinnedSummaryCard: some View {
        TeamMessengerSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                TeamMessengerSettingsSectionHeader(
                    title: "공지 모아보기",
                    subtitle: "이 채팅방에서 고정된 공지 메시지입니다."
                )

                if manager.pinnedMessages.isEmpty {
                    TeamMessengerSettingsEmptyCard(title: "등록된 공지가 없습니다.", detail: "메시지를 고정하면 이곳에 모입니다.")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(manager.pinnedMessages) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.senderName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.58))
                                    Spacer()
                                    Text(item.pinnedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.black.opacity(0.34))
                                }

                                Text(item.text)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.74))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(TeamMessengerSettingsListBackground())
                        }
                    }
                }
            }
        }
    }

    private var keywordSummaryCard: some View {
        TeamMessengerSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                TeamMessengerSettingsSectionHeader(
                    title: "키워드 보관함",
                    subtitle: "이 채팅방에서 주요 키워드로 등록된 메시지 모음입니다."
                )

                if manager.selectedRoomHighlightedMessages.isEmpty {
                    TeamMessengerSettingsEmptyCard(title: "등록된 키워드 메시지가 없습니다.", detail: "메시지 우클릭에서 키워드를 체크하면 이곳에 모입니다.")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(manager.selectedRoomHighlightedMessages) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.keyword)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                                    Spacer()
                                    Text(item.highlightedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.black.opacity(0.34))
                                }

                                Text(item.text)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.76))
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(item.senderName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.4))
                            }
                            .padding(12)
                            .background(TeamMessengerSettingsListBackground())
                        }
                    }
                }
            }
        }
    }
}

private struct TeamMessengerSettingsCard<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct TeamMessengerSettingsSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.46))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TeamMessengerSettingsLabelText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.52))
    }
}

private struct TeamMessengerSettingsHelperText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.42))
    }
}

private struct TeamMessengerSettingsActionText: View {
    let title: String
    let filled: Bool
    var tint: Color = Color(red: 0.10, green: 0.18, blue: 0.14)

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(filled ? .white : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Group {
                    if filled {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tint)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.92, green: 0.95, blue: 0.99))
                    }
                }
            )
    }
}

private struct TeamMessengerSettingsEmptyCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.72))
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.46))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(TeamMessengerSettingsListBackground())
    }
}

private struct TeamMessengerSettingsFieldBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct TeamMessengerSettingsListBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.98, green: 0.98, blue: 0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}
