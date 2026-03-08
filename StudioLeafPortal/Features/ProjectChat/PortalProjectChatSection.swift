import SwiftUI
import Foundation
import LinkPresentation
import Combine
import AppKit

struct PortalProjectChatSection: View {
    private enum RoomFocusPanel: Equatable {
        case pinned
        case keywords
    }

    @ObservedObject var manager: PortalProjectChatManager
    @ObservedObject var authManager: PortalAuthManager
    @ObservedObject var viewModel: PortalViewModel
    @ObservedObject var projectArchiveManager: PortalProjectArchiveManager
    
    @State private var editingMessageID: String?
    @State private var editText: String = ""
    @State private var isShowingRoomCreationSheet = false
    @State private var isShowingRoomSettingsSheet = false
    @State private var roomSettingsNameDraft = ""
    @State private var composerHeight: CGFloat = 18
    @StateObject private var linkPreviewCache = MessageLinkPreviewCache()
    @State private var isShowingSearch = false
    @State private var activeRoomFocusPanel: RoomFocusPanel?
    @State private var attachmentArchive: ProjectArchiveSummary?
    @State private var attachmentFileURL: URL?

    var body: some View {
        if authManager.isSignedIn {
            TeamMessengerWorkspaceView(
                leftColumn: AnyView(leftColumn),
                rightColumn: AnyView(rightColumn)
            )
            .sheet(isPresented: $isShowingRoomCreationSheet) {
                TeamMessengerProjectCreationSheetView(
                    manager: manager,
                    isShowing: $isShowingRoomCreationSheet
                )
            }
            .sheet(isPresented: $isShowingRoomSettingsSheet) {
                PortalProjectChatRoomSettingsSheet(
                    manager: manager,
                    isShowing: $isShowingRoomSettingsSheet,
                    roomNameDraft: $roomSettingsNameDraft
                )
                .frame(minWidth: 560, minHeight: 620)
            }
            .sheet(
                isPresented: Binding(
                    get: { attachmentArchive != nil && attachmentFileURL != nil },
                    set: { isPresented in
                        if !isPresented {
                            attachmentArchive = nil
                            attachmentFileURL = nil
                        }
                    }
                )
            ) {
                if let attachmentArchive, let attachmentFileURL {
                    PortalProjectChatAttachmentSheet(
                        archiveManager: projectArchiveManager,
                        chatManager: manager,
                        archive: attachmentArchive,
                        fileURL: attachmentFileURL,
                        isShowing: Binding(
                            get: { self.attachmentArchive != nil && self.attachmentFileURL != nil },
                            set: { isPresented in
                                if !isPresented {
                                    self.attachmentArchive = nil
                                    self.attachmentFileURL = nil
                                }
                            }
                        )
                    )
                }
            }
            .onChange(of: manager.selectedRoomID) { _, _ in
                activeRoomFocusPanel = nil
                isShowingSearch = false
            }
        } else {
            signedOutState
        }
    }
    private var leftColumn: some View {
        TeamMessengerLeftColumnView(
            topBar: AnyView(leftColumnTopBar),
            content: AnyView(unifiedRoomListCard)
        )
    }

    private var leftColumnTopBar: some View {
        HStack(spacing: 20) {
            ForEach(PortalProjectChatManager.ChatTopTab.allCases) { tab in
                Button {
                    manager.topTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: manager.topTab == tab ? .bold : .medium))
                            .foregroundStyle(manager.topTab == tab ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.black.opacity(0.35))

                        if manager.topTab == tab {
                            Capsule()
                                .fill(Color(red: 0.10, green: 0.18, blue: 0.14))
                                .frame(width: 14, height: 3)
                        } else {
                            Color.clear.frame(width: 14, height: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .clickableCursor()
            }

            Spacer()

            statusChip(
                title: "\(manager.filteredRooms.count)개",
                tint: Color(red: 0.95, green: 0.97, blue: 0.96)
            )

            Button {
                isShowingRoomCreationSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 19, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                    .help("새 \(PortalFeatureNaming.teamMessenger) 프로젝트")
                    .padding(2)
            }
            .buttonStyle(.plain)
            .clickableCursor()
        }
    }
    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let project = manager.selectedProject {
                TeamMessengerHeaderBarView(
                    roomName: manager.selectedRoom?.name ?? project.name,
                    canOpenProjectHub: projectArchiveManager.archive(forChatProjectID: project.id) != nil,
                    onOpenProjectHub: {
                        if let archive = projectArchiveManager.archive(forChatProjectID: project.id) {
                            viewModel.selectedSection = .projectArchive
                            projectArchiveManager.selectedArchiveID = archive.id
                        }
                    },
                    isSearchVisible: isShowingSearch,
                    onToggleSearch: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isShowingSearch.toggle()
                            if !isShowingSearch {
                                manager.messageSearchText = ""
                            }
                        }
                    },
                    showsRoomSettings: manager.selectedRoom != nil,
                    onOpenRoomSettings: {
                        roomSettingsNameDraft = manager.selectedRoom?.name ?? ""
                        isShowingRoomSettingsSheet = true
                    }
                )

                if isShowingSearch && manager.selectedRoom != nil {
                    TeamMessengerSearchBarView(text: $manager.messageSearchText)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if manager.selectedRoom != nil {
                    messageThreadCard
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                } else {
                    TeamMessengerPlaceholderView(title: "\(PortalFeatureNaming.teamMessenger)를 선택하세요")
                }

                if manager.selectedRoom != nil && activeRoomFocusPanel == nil {
                    composerCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .background(Color.white)
                }
            } else {
                TeamMessengerPlaceholderView(title: "\(PortalFeatureNaming.teamMessenger)를 선택하세요")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
    }

    private var signedOutState: some View {
        TeamMessengerSignedOutStateView(
            isSigningIn: authManager.status == .signingIn,
            onSignIn: {
                Task {
                    await authManager.signIn()
                }
            }
        )
    }

    private var unifiedRoomListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("대화 목록")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text(manager.topTab == .myJoined ? "내가 참여 중인 채팅과 최근 메시지" : "접근 가능한 모든 채팅과 최근 메시지")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            textField("프로젝트/대화 검색", text: $manager.roomSearchText)

            if manager.isLoadingProjects && manager.filteredRooms.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else if manager.projects.isEmpty {
                emptyConversationCard(
                    title: "아직 프로젝트가 없습니다.",
                    detail: "첫 대화를 만들면 이 영역이 바로 채팅 목록으로 바뀝니다."
                )
            } else if manager.allRooms.isEmpty {
                emptyConversationCard(
                    title: "아직 대화가 없습니다.",
                    detail: "현재 프로젝트들에 연결된 채팅이 없으면 여기에 빈 상태로 표시됩니다."
                )
            } else if manager.filteredRooms.isEmpty {
                emptyConversationCard(
                    title: "검색 결과가 없습니다.",
                    detail: "프로젝트명이나 최근 메시지 내용으로 다시 검색해 보세요."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(manager.filteredRooms) { room in
                        Button {
                            manager.selectRoom(room)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(manager.selectedRoomID == room.id ? 1 : 0.08))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(manager.selectedRoomID == room.id ? .white : Color(red: 0.10, green: 0.18, blue: 0.14))
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(room.name)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.84))

                                        Text(roomPreviewText(for: room))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.black.opacity(0.48))
                                            .lineLimit(2)

                                        HStack(spacing: 8) {
                                            if manager.unreadCount(for: room, projectID: room.projectID) > 0 {
                                                unreadBadge(count: manager.unreadCount(for: room, projectID: room.projectID))
                                            }

                                            Text(relativeDateText(for: room.lastMessageAt ?? room.updatedAt))
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(Color.black.opacity(0.36))
                                        }
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(manager.selectedRoomID == room.id ? Color(red: 0.95, green: 0.97, blue: 0.96) : Color(red: 0.98, green: 0.98, blue: 0.98))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(manager.selectedRoomID == room.id ? Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.18) : Color.black.opacity(0.05), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .clickableCursor()
                    }
                }
            }
        }
    }

    private var messageThreadCard: some View {
        TeamMessengerThreadContainerView(
            title: manager.selectedRoom?.name ?? "대화",
            subtitle: "",
            statusTitle: roomFocusStatusTitle,
            pinnedCount: manager.pinnedMessages.count,
            keywordCount: manager.selectedRoomHighlightedMessages.count,
            activePanel: activeRoomFocusPanel == .pinned ? "pinned" : activeRoomFocusPanel == .keywords ? "keywords" : nil,
            onTogglePinned: {
                if activeRoomFocusPanel == .pinned {
                    activeRoomFocusPanel = nil
                } else {
                    activeRoomFocusPanel = .pinned
                    isShowingSearch = false
                }
            },
            onToggleKeyword: {
                if activeRoomFocusPanel == .keywords {
                    activeRoomFocusPanel = nil
                } else {
                    activeRoomFocusPanel = .keywords
                    isShowingSearch = false
                }
            }
        ) {
            if manager.selectedRoom != nil {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if let activeRoomFocusPanel {
                                focusedRoomContent(activeRoomFocusPanel)
                            } else if manager.messages.isEmpty {
                                emptyConversationCard(
                                    title: "아직 대화가 없습니다.",
                                    detail: "첫 메시지를 보내면 이 방의 대화가 실시간으로 여기에 쌓입니다."
                                )
                            } else if manager.filteredMessages.isEmpty {
                                emptyConversationCard(
                                    title: "검색 결과가 없습니다.",
                                    detail: "메시지 내용이나 보낸 사람 이름으로 다시 검색해 보세요."
                                )
                            } else {
                                ForEach(manager.filteredMessages) { message in
                                    messageBubble(message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: manager.messages.count) { _, _ in
                        if let last = manager.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: manager.pendingMessageNavigationID) { _, pendingID in
                        guard let pendingID else { return }

                        Task {
                            for _ in 0..<12 {
                                if manager.messages.contains(where: { $0.id == pendingID }) {
                                    break
                                }
                                try? await Task.sleep(nanoseconds: 120_000_000)
                            }

                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(pendingID, anchor: .center)
                            }
                            manager.pendingMessageNavigationID = nil
                        }
                    }
                }
                .frame(minHeight: 360, maxHeight: .infinity)
            } else {
                emptyConversationCard(
                    title: "채팅방을 먼저 선택해 주세요.",
                    detail: "왼쪽에서 프로젝트와 방을 고르면 이 영역에 대화가 열립니다."
                )
            }
        }
    }

    private var composerCard: some View {
        TeamMessengerComposerContainerView {
            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    selectChatAttachment()
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .disabled(manager.selectedRoom == nil)
                .opacity(manager.selectedRoom == nil ? 0.45 : 1)
                .clickableCursor(enabled: manager.selectedRoom != nil)

                ZStack(alignment: .topLeading) {
                    ChatComposerTextView(
                        text: $manager.messageDraft,
                        measuredHeight: $composerHeight
                    ) {
                        guard !(manager.isSendingMessage || manager.messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else {
                            return
                        }

                        Task {
                            await manager.sendMessage()
                        }
                    }
                    .frame(height: composerHeight)

                    if manager.messageDraft.isEmpty {
                        Text("메시지를 입력하세요...")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.black.opacity(0.32))
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.04))
                )

                Button {
                    Task {
                        await manager.sendMessage()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(manager.messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.5) : Color(red: 0.10, green: 0.18, blue: 0.14))
                        )
                }
                .buttonStyle(.plain)
                .disabled(manager.isSendingMessage || manager.messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(manager.isSendingMessage || manager.messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.65 : 1)
                .clickableCursor(enabled: !(manager.isSendingMessage || manager.messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
    }

    private var roomFocusStatusTitle: String {
        switch activeRoomFocusPanel {
        case .pinned:
            return "고정 \(manager.pinnedMessages.count)개"
        case .keywords:
            return "키워드 \(manager.selectedRoomHighlightedMessages.count)개"
        case nil:
            return "\(manager.filteredMessages.count)개 메시지"
        }
    }

    @ViewBuilder
    private func focusedRoomContent(_ panel: RoomFocusPanel) -> some View {
        switch panel {
        case .pinned:
            if manager.pinnedMessages.isEmpty {
                emptyConversationCard(
                    title: "고정된 공지가 없습니다.",
                    detail: "메시지를 고정하면 여기에서 모아 볼 수 있습니다."
                )
            } else {
                ForEach(manager.pinnedMessages) { pinnedMessage in
                    Button {
                        activeRoomFocusPanel = nil
                        manager.pendingMessageNavigationID = pinnedMessage.id
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("공지", systemImage: "pin.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                                Spacer()
                                Text(shortDateText(for: pinnedMessage.pinnedAt))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.34))
                            }

                            Text(pinnedMessage.text)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(pinnedMessage.senderName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.42))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.99, green: 0.98, blue: 0.94))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .clickableCursor()
                }
            }

        case .keywords:
            if manager.selectedRoomHighlightedMessages.isEmpty {
                emptyConversationCard(
                    title: "등록된 주요키워드가 없습니다.",
                    detail: "메시지 우클릭에서 키워드를 체크하면 여기에서 모아 볼 수 있습니다."
                )
            } else {
                ForEach(manager.selectedRoomHighlightedMessages) { item in
                    Button {
                        activeRoomFocusPanel = nil
                        manager.pendingMessageNavigationID = item.messageID
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.keyword)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                                Spacer()
                                Text(shortDateText(for: item.highlightedAt))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.34))
                            }

                            Text(item.text)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(item.senderName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.42))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .clickableCursor()
                }
            }
        }
    }

    private func messageBubble(_ message: PortalProjectChatManager.MessageSummary) -> some View {
        let isMine = message.senderID == authManager.currentUser?.id
        let isEditing = editingMessageID == message.id
        let driveAttachment = ChatDriveAttachment.parse(from: message.text)

        return HStack(alignment: .top, spacing: 12) {
            if !isMine {
                Circle()
                    .fill(Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(message.senderName.prefix(1)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                    )
            } else {
                Spacer(minLength: 40)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    HStack(spacing: 6) {
                        Text(message.senderName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                        Text(shortDateText(for: message.createdAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.35))
                    }
                }

                if isEditing {
                    VStack(alignment: .trailing, spacing: 8) {
                        TextField("", text: $editText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .padding(10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.1), lineWidth: 1))
                        
                        HStack(spacing: 8) {
                            Button("취소") {
                                editingMessageID = nil
                            }
                            .font(.system(size: 11, weight: .bold))
                            
                            Button("저장") {
                                Task {
                                    await manager.editMessage(message, newText: editText)
                                    editingMessageID = nil
                                }
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.10, green: 0.18, blue: 0.14))
                        }
                    }
                    .padding(4)
                } else if let driveAttachment {
                    MessageDriveAttachmentPanel(
                        attachment: driveAttachment,
                        isMine: isMine
                    )
                } else {
                    Text(message.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isMine ? .white : Color.black.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: isMine ? 16 : 12)
                                .fill(isMine ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color(red: 0.96, green: 0.97, blue: 0.98))
                        )

                    if let previewURL = firstLinkURL(in: message.text) {
                        MessageLinkPreviewPanel(messageID: message.id, url: previewURL, cache: linkPreviewCache)
                    }
                }
            }
            .contextMenu {
                Button {
                    Task { await manager.togglePin(message) }
                } label: {
                    Label(manager.isPinned(message) ? "고정 해제" : "고정", systemImage: "pin")
                }

                Menu("키워드 반영") {
                    if manager.selectedProjectKeywords.isEmpty {
                        Text("등록된 키워드 없음")
                    } else {
                        ForEach(manager.selectedProjectKeywords, id: \.self) { keyword in
                            Toggle(
                                keyword,
                                isOn: Binding(
                                    get: {
                                        manager.isKeywordApplied(keyword, to: message)
                                    },
                                    set: { _ in
                                        Task {
                                            await manager.toggleKeyword(keyword, for: message)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }

                if isMine {
                    Button {
                        editingMessageID = message.id
                        editText = message.text
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        Task { await manager.deleteMessage(message) }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
    }

    private func roomPreviewText(for room: PortalProjectChatManager.RoomSummary) -> String {
        if let attachment = ChatDriveAttachment.parse(from: room.lastMessageText) {
            return attachment.summaryText
        }
        return room.lastMessageText.isEmpty ? "최근 대화가 아직 없습니다." : room.lastMessageText
    }

    private func firstLinkURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }

        let candidate = String(text[matchRange])
        if let url = URL(string: candidate) {
            return url
        }

        if candidate.hasPrefix("www."),
           let url = URL(string: "https://\(candidate)") {
            return url
        }

        return nil
    }

    private struct MessageLinkPreviewPanel: View {
        let messageID: String
        let url: URL
        @ObservedObject var cache: MessageLinkPreviewCache

        @State private var loaded = false

        init(messageID: String, url: URL, cache: MessageLinkPreviewCache) {
            self.messageID = messageID
            self.url = url
            self.cache = cache
        }

        var body: some View {
            let cacheKey = MessageLinkPreviewCache.makeKey(messageID: messageID, url: url)

            Link(destination: url) {
                VStack(alignment: .leading, spacing: 6) {
                    if let preview = cache.previews[cacheKey] {
                        Text(preview.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .lineLimit(1)
                    } else if let error = cache.failures[cacheKey], error == true {
                        Text("링크 미리보기 없음")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.58))
                    } else if cache.isLoading.contains(cacheKey) {
                        Text("미리보기 불러오는 중...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.46))
                    } else {
                        Text("링크 미리보기 준비")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.46))
                    }

                    Text(previewSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.46))
                        .lineLimit(2)
                }
                .frame(maxWidth: 300, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("미리보기 다시 불러오기") {
                    Task {
                        await cache.reloadPreview(for: messageID, url: url)
                    }
                }
            }
            .task(id: cacheKey) {
                if loaded { return }
                loaded = true
                await cache.loadPreview(for: messageID, url: url)
            }
        }

        private var previewSubtitle: String {
            let base = url.host ?? url.absoluteString
            if let preview = cache.previews[MessageLinkPreviewCache.makeKey(messageID: messageID, url: url)] {
                return preview.detail
            }
            return base
        }
    }

    private struct MessageDriveAttachmentPanel: View {
        let attachment: ChatDriveAttachment
        let isMine: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                if let thumbnailDataImage {
                    thumbnailPanel(image: thumbnailDataImage)
                } else if let remoteThumbnailURL {
                    remoteThumbnailPanel(url: remoteThumbnailURL)
                }

                HStack(alignment: .top, spacing: 12) {
                    if thumbnailDataImage == nil && remoteThumbnailURL == nil {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(iconBackgroundColor)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: attachment.symbolName)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(iconForegroundColor)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(attachment.fileName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(primaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(attachment.folderTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    attachmentMetaChip(title: attachment.providerTitle)
                    attachmentMetaChip(title: attachment.typeLabel)

                    Spacer(minLength: 0)

                    Link(destination: attachment.webViewURL) {
                        Text(attachment.openActionTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isMine ? Color.white : Color(red: 0.10, green: 0.18, blue: 0.14))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isMine ? Color.white.opacity(0.16) : Color(red: 0.92, green: 0.96, blue: 0.93))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 360, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: isMine ? 16 : 12)
                    .fill(isMine ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color(red: 0.96, green: 0.97, blue: 0.98))
            )
        }

        private var primaryTextColor: Color {
            isMine ? .white : Color.black.opacity(0.85)
        }

        private var secondaryTextColor: Color {
            isMine ? Color.white.opacity(0.72) : Color.black.opacity(0.48)
        }

        private var iconBackgroundColor: Color {
            isMine ? Color.white.opacity(0.14) : Color.white
        }

        private var iconForegroundColor: Color {
            isMine ? .white : Color(red: 0.10, green: 0.18, blue: 0.14)
        }

        private var thumbnailDataImage: NSImage? {
            guard let thumbnailDataURL = attachment.thumbnailDataURL,
                  thumbnailDataURL.hasPrefix("data:") else {
                return nil
            }
            let encodedData = thumbnailDataURL.components(separatedBy: ",").dropFirst().joined(separator: ",")
            guard !encodedData.isEmpty,
                  let imageData = Data(base64Encoded: encodedData),
                  let image = NSImage(data: imageData) else {
                return nil
            }
            return image
        }

        private var remoteThumbnailURL: URL? {
            guard let thumbnailDataURL = attachment.thumbnailDataURL,
                  !thumbnailDataURL.hasPrefix("data:") else {
                return nil
            }
            return URL(string: thumbnailDataURL)
        }

        @ViewBuilder
        private func thumbnailPanel(image: NSImage) -> some View {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 332, height: 188)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isMine ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
                )
        }

        @ViewBuilder
        private func remoteThumbnailPanel(url: URL) -> some View {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    thumbnailPlaceholder
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isMine ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                        ProgressView()
                            .controlSize(.small)
                    }
                @unknown default:
                    thumbnailPlaceholder
                }
            }
            .frame(width: 332, height: 188)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isMine ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
            )
        }

        private var thumbnailPlaceholder: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isMine ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                Image(systemName: attachment.symbolName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(isMine ? Color.white.opacity(0.72) : Color.black.opacity(0.42))
            }
        }

        private func attachmentMetaChip(title: String) -> some View {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isMine ? Color.white.opacity(0.82) : Color.black.opacity(0.62))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isMine ? Color.white.opacity(0.12) : Color.black.opacity(0.05))
                )
        }
    }

    private func messageActionChip(
        title: String,
        systemName: String,
        active: Bool,
        isDark: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(
                isDark
                    ? (active ? Color.white : Color.white.opacity(0.82))
                    : (active ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.black.opacity(0.64))
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        isDark
                            ? (active ? Color.white.opacity(0.16) : Color.white.opacity(0.10))
                            : (active ? Color(red: 0.91, green: 0.95, blue: 0.99) : Color.black.opacity(0.04))
                    )
            )
        }
        .buttonStyle(.plain)
        .clickableCursor()
    }

    private func noticeCard(title: String, body: String, tint: Color) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.7))
                Text(body)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(tint)
            )
        }
    }

    private func selectChatAttachment() {
        guard let project = manager.selectedProject,
              manager.selectedRoom != nil else {
            manager.errorMessage = "먼저 채팅방을 선택해 주세요."
            return
        }

        guard let archive = projectArchiveManager.archive(forChatProjectID: project.id) else {
            manager.errorMessage = "이 채팅은 아직 Project Hub와 연결되지 않았습니다."
            return
        }

        guard archive.googleDriveRootFolderID != nil || archive.dropboxRootPath != nil else {
            manager.errorMessage = "연결된 Project Hub의 Google Drive/Dropbox 폴더가 아직 준비되지 않았습니다."
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let fileURL = panel.url else {
            return
        }

        attachmentArchive = archive
        attachmentFileURL = fileURL
    }

    private func cardHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.38))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.98, green: 0.98, blue: 0.98))
        )
    }

    private func statusChip(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.7))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint)
            )
    }

    private func unreadBadge(count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(minWidth: 18)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(red: 0.17, green: 0.69, blue: 0.41))
            )
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.10, green: 0.18, blue: 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func secondaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.76))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }

    private func emptyConversationCard(title: String, detail: String) -> some View {
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
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.98, green: 0.98, blue: 0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func textField(_ prompt: String, text: Binding<String>, vertical: Bool = false) -> some View {
        Group {
            if vertical {
                TextField(prompt, text: text, axis: .vertical)
                    .lineLimit(2...5)
            } else {
                TextField(prompt, text: text)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        )
    }

    private func shortDateText(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func relativeDateText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
    
    private var memberGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)]
    }
}
