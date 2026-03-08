import AppKit
import Combine
import FirebaseFirestore
import Foundation
import UserNotifications

@MainActor
final class PortalProjectChatManager: ObservableObject {
    static let defaultProjectKeywords: [String] = ["#기획서", "#PPM", "#촬영일정", "#스탭구성", "#해결이슈"]

    enum ChatTopTab: String, CaseIterable, Identifiable {
        case myJoined = "내 참여"
        case all = "전체"

        var id: String { rawValue }
    }

    enum ChatBottomTab: String, CaseIterable, Identifiable {
        case pinned = "고정"
        case highlighted = "주요키워드"

        var id: String { rawValue }
    }

    struct MemberSummary: Identifiable, Equatable, Hashable {
        let id: String
        let displayName: String
        let email: String
        let photoURLString: String

        var firestoreData: [String: Any] {
            [
                "uid": id,
                "displayName": displayName,
                "email": email,
                "photoURL": photoURLString
            ]
        }

        init(id: String, displayName: String, email: String, photoURLString: String = "") {
            self.id = id
            self.displayName = displayName
            self.email = email
            self.photoURLString = photoURLString
        }

        init?(dictionary: [String: Any]) {
            guard let id = dictionary["uid"] as? String else { return nil }

            self.id = id
            self.displayName = dictionary["displayName"] as? String ?? "studioLEAF 사용자"
            self.email = dictionary["email"] as? String ?? ""
            self.photoURLString = dictionary["photoURL"] as? String ?? ""
        }
    }

    struct ProjectSummary: Identifiable, Equatable {
        let id: String
        let name: String
        let summary: String
        let ownerID: String
        let memberIDs: [String]
        let members: [MemberSummary]
        let createdAt: Date
        let updatedAt: Date
        var keywordTags: [String]

        init?(document: QueryDocumentSnapshot) {
            let data = document.data()
            self.init(id: document.documentID, dictionary: data)
        }

        init?(id: String, dictionary: [String: Any]) {
            guard let name = dictionary["name"] as? String else { return nil }

            self.id = id
            self.name = name
            summary = dictionary["summary"] as? String ?? ""
            ownerID = dictionary["ownerId"] as? String ?? ""
            memberIDs = dictionary["memberIds"] as? [String] ?? []
            members = (dictionary["memberSummaries"] as? [[String: Any]] ?? []).compactMap(MemberSummary.init(dictionary:))
            createdAt = Self.dateValue(from: dictionary["createdAt"])
            updatedAt = Self.dateValue(from: dictionary["updatedAt"])
            keywordTags = PortalProjectChatManager.sanitizeKeywordList(dictionary["keywordList"] as? [String] ?? PortalProjectChatManager.defaultProjectKeywords)
        }

        var memberLine: String {
            let names = members.map(\.displayName)
            if names.isEmpty {
                return "참여자 정보 없음"
            }
            return names.joined(separator: ", ")
        }

        private static func dateValue(from value: Any?) -> Date {
            if let timestamp = value as? Timestamp {
                return timestamp.dateValue()
            }
            if let date = value as? Date {
                return date
            }
            return .distantPast
        }
    }

    struct RoomSummary: Identifiable, Equatable {
        let id: String
        let projectID: String
        let name: String
        let createdBy: String
        let memberIDs: [String]
        let members: [MemberSummary]
        let createdAt: Date
        let updatedAt: Date
        let lastMessageText: String
        let lastMessageSenderID: String
        let lastMessageAt: Date?
        let isArchived: Bool
        let isPrimaryProjectRoom: Bool

        init?(document: QueryDocumentSnapshot) {
            let data = document.data()
            guard let projectID = document.reference.parent.parent?.documentID else { return nil }
            self.init(id: document.documentID, projectID: projectID, dictionary: data)
        }

        init?(id: String, projectID: String, dictionary: [String: Any]) {
            guard let name = dictionary["name"] as? String else { return nil }

            self.id = id
            self.projectID = projectID
            self.name = name
            createdBy = dictionary["createdBy"] as? String ?? ""
            memberIDs = dictionary["memberIds"] as? [String] ?? []
            members = (dictionary["memberSummaries"] as? [[String: Any]] ?? []).compactMap(MemberSummary.init(dictionary:))
            createdAt = Self.dateValue(from: dictionary["createdAt"])
            updatedAt = Self.dateValue(from: dictionary["updatedAt"])
            lastMessageText = dictionary["lastMessageText"] as? String ?? ""
            lastMessageSenderID = dictionary["lastMessageSenderId"] as? String ?? ""
            if let timestamp = dictionary["lastMessageAt"] as? Timestamp {
                lastMessageAt = timestamp.dateValue()
            } else if let date = dictionary["lastMessageAt"] as? Date {
                lastMessageAt = date
            } else {
                lastMessageAt = nil
            }

            isArchived = dictionary["isArchived"] as? Bool ?? false
            isPrimaryProjectRoom = dictionary["isPrimaryProjectRoom"] as? Bool ?? false
        }

        var memberLine: String {
            let names = members.map(\.displayName)
            if names.isEmpty {
                return "참여자 정보 없음"
            }
            return names.joined(separator: ", ")
        }

        private static func dateValue(from value: Any?) -> Date {
            if let timestamp = value as? Timestamp {
                return timestamp.dateValue()
            }
            if let date = value as? Date {
                return date
            }
            return .distantPast
        }
    }

    struct MessageSummary: Identifiable, Equatable {
        let id: String
        let senderID: String
        let senderName: String
        let text: String
        let createdAt: Date

        init?(document: QueryDocumentSnapshot) {
            let data = document.data()
            guard let senderID = data["senderId"] as? String,
                  let text = data["text"] as? String else {
                return nil
            }

            id = document.documentID
            self.senderID = senderID
            senderName = data["senderName"] as? String ?? "studioLEAF 사용자"
            self.text = text
            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            } else if let date = data["createdAt"] as? Date {
                createdAt = date
            } else {
                createdAt = .now
            }
        }
    }

    struct PinnedMessageSummary: Identifiable, Equatable {
        let id: String
        let senderID: String
        let senderName: String
        let text: String
        let createdAt: Date
        let pinnedAt: Date
        let pinnedByID: String
        let pinnedByName: String

        init?(document: QueryDocumentSnapshot) {
            let data = document.data()
            guard let senderID = data["senderId"] as? String,
                  let text = data["text"] as? String else {
                return nil
            }

            id = document.documentID
            self.senderID = senderID
            senderName = data["senderName"] as? String ?? "studioLEAF 사용자"
            self.text = text
            pinnedByID = data["pinnedById"] as? String ?? ""
            pinnedByName = data["pinnedByName"] as? String ?? "알 수 없음"

            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            } else if let date = data["createdAt"] as? Date {
                createdAt = date
            } else {
                createdAt = .now
            }

            if let timestamp = data["pinnedAt"] as? Timestamp {
                pinnedAt = timestamp.dateValue()
            } else if let date = data["pinnedAt"] as? Date {
                pinnedAt = date
            } else {
                pinnedAt = .now
            }
        }
    }

    struct HighlightedMessageSummary: Identifiable, Equatable {
        let id: String
        let projectID: String
        let projectName: String
        let roomID: String
        let keyword: String
        let roomName: String
        let messageID: String
        let senderID: String
        let senderName: String
        let text: String
        let createdAt: Date
        let highlightedAt: Date

        init(
            id: String,
            projectID: String,
            projectName: String,
            roomID: String,
            keyword: String,
            roomName: String,
            messageID: String,
            senderID: String,
            senderName: String,
            text: String,
            createdAt: Date,
            highlightedAt: Date
        ) {
            self.id = id
            self.projectID = projectID
            self.projectName = projectName
            self.roomID = roomID
            self.keyword = keyword
            self.roomName = roomName
            self.messageID = messageID
            self.senderID = senderID
            self.senderName = senderName
            self.text = text
            self.createdAt = createdAt
            self.highlightedAt = highlightedAt
        }

        init?(document: QueryDocumentSnapshot) {
            let data = document.data()
            guard let projectID = data["projectId"] as? String,
                  let roomID = data["roomId"] as? String,
                  let messageID = data["messageId"] as? String,
                  let senderID = data["senderId"] as? String,
                  let keyword = data["keyword"] as? String,
                  let text = data["text"] as? String else {
                return nil
            }

            id = document.documentID
            self.projectID = projectID
            projectName = data["projectName"] as? String ?? "프로젝트"
            self.roomID = roomID
            self.keyword = keyword
            roomName = data["roomName"] as? String ?? "채팅방"
            self.messageID = messageID
            self.senderID = senderID
            senderName = data["senderName"] as? String ?? "studioLEAF 사용자"
            self.text = text

            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            } else if let date = data["createdAt"] as? Date {
                createdAt = date
            } else {
                createdAt = .now
            }

            if let timestamp = data["highlightedAt"] as? Timestamp {
                highlightedAt = timestamp.dateValue()
            } else if let date = data["highlightedAt"] as? Date {
                highlightedAt = date
            } else if let timestamp = data["matchedAt"] as? Timestamp {
                highlightedAt = timestamp.dateValue()
            } else if let date = data["matchedAt"] as? Date {
                highlightedAt = date
            } else {
                highlightedAt = .now
            }
        }
    }

    @Published private(set) var projects: [ProjectSummary] = []
    @Published private(set) var allRooms: [RoomSummary] = []
    @Published private(set) var rooms: [RoomSummary] = []
    @Published private(set) var messages: [MessageSummary] = []
    @Published private(set) var pinnedMessages: [PinnedMessageSummary] = []
    @Published private(set) var highlightedMessages: [HighlightedMessageSummary] = []
    @Published var projectKeywordDraft = ""
    @Published var projectSearchText = ""
    @Published var roomSearchText = ""
    @Published var messageSearchText = ""
    @Published var selectedProjectID: String?
    @Published var selectedRoomID: String?
    @Published var projectNameDraft = ""
    @Published var projectSummaryDraft = ""
    @Published var inviteEmailsDraft = ""
    @Published var roomNameDraft = ""
    @Published var roomMemberSelection = Set<String>()
    @Published var messageDraft = ""
    @Published var topTab: ChatTopTab = .myJoined
    @Published var bottomTab: ChatBottomTab = .highlighted
    private var isBootstrappingNotificationSettings = true
    @Published var isChatNotificationEnabled = true {
        didSet {
            guard !isBootstrappingNotificationSettings else { return }
            defaults.set(isChatNotificationEnabled, forKey: NotificationKeys.isChatNotificationEnabled)
            if isChatNotificationEnabled {
                requestNotificationPermissionIfNeeded()
            }
        }
    }
    @Published var isChatSoundEnabled = true {
        didSet {
            guard !isBootstrappingNotificationSettings else { return }
            defaults.set(isChatSoundEnabled, forKey: NotificationKeys.isChatSoundEnabled)
        }
    }
    @Published var chatNotificationSoundName = "system:Pop" {
        didSet {
            guard !isBootstrappingNotificationSettings else { return }
            defaults.set(chatNotificationSoundName, forKey: NotificationKeys.chatNotificationSoundName)
        }
    }
    @Published private(set) var statusLine = "로그인이 필요합니다."
    @Published var bannerMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var isLoadingProjects = false
    @Published private(set) var isCreatingProject = false
    @Published private(set) var isCreatingRoom = false
    @Published private(set) var isSendingMessage = false
    @Published private(set) var roomReadAtByKey: [String: Date] = [:]
    @Published var pendingMessageNavigationID: String?
    @Published private(set) var isKeywordLoading = false
    @Published private(set) var keywordStatusMessage: String?
    @Published private(set) var messageKeywordFlags: [String: Set<String>] = [:]

    private let authManager: PortalAuthManager
    private let database = Firestore.firestore()
    private let defaults = UserDefaults.standard
    private let initialMessagePageSize = 60
    private let oneTimeCleanupVersion = "chat_metadata_orphan_cleanup_v3"
    private var cancellables = Set<AnyCancellable>()
    private var projectsListener: ListenerRegistration?
    private var roomListenersByProjectID: [String: ListenerRegistration] = [:]
    private var allRoomsByProjectID: [String: [RoomSummary]] = [:]
    private var messagesListener: ListenerRegistration?
    private var pinnedMessagesListener: ListenerRegistration?
    private var readStateListener: ListenerRegistration?
    private var readStateFlushTask: Task<Void, Never>?
    private var currentUserID: String?
    private var pendingRoomSelectionID: String?
    private var pendingReadStateWrites: [String: (projectID: String, roomID: String, lastReadAt: Date)] = [:]
    private var keywordMatchesTask: Task<Void, Never>?
    private var hasTriggeredOneTimeCleanup = false
    private var initializedRoomSnapshotProjects = Set<String>()
    private var deliveredRoomNotificationKeys = Set<String>()
    private var isWaitingForNotificationPermissionAfterLaunch = false

    private enum NotificationKeys {
        static let isChatNotificationEnabled = "StudioLeafPortal.ProjectChat.notificationEnabled"
        static let isChatSoundEnabled = "StudioLeafPortal.ProjectChat.soundEnabled"
        static let chatNotificationSoundName = "StudioLeafPortal.ProjectChat.soundName"
    }

    init(authManager: PortalAuthManager) {
        self.authManager = authManager
        currentUserID = authManager.collaborationUserID
        isChatNotificationEnabled = defaults.object(forKey: NotificationKeys.isChatNotificationEnabled) as? Bool ?? true
        isChatSoundEnabled = defaults.object(forKey: NotificationKeys.isChatSoundEnabled) as? Bool ?? true
        chatNotificationSoundName = normalizedChatSoundIdentifier(defaults.string(forKey: NotificationKeys.chatNotificationSoundName))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidFinishLaunchingNotification),
            name: .studioLeafPortalDidFinishLaunching,
            object: nil
        )

        isBootstrappingNotificationSettings = false

        authManager.$collaborationUserID
            .removeDuplicates()
            .sink { [weak self] userID in
                Task { @MainActor [weak self] in
                    self?.handleAuthenticationChange(userID: userID)
                }
            }
            .store(in: &cancellables)

        $selectedProjectID
            .removeDuplicates()
            .sink { [weak self] projectID in
                Task { @MainActor [weak self] in
                    self?.handleSelectedProjectChanged(projectID: projectID)
                }
            }
            .store(in: &cancellables)

        $topTab
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshKeywordMatches(for: self?.selectedProjectID)
                    self?.syncRoomSubscriptions()
                }
            }
            .store(in: &cancellables)

        $selectedRoomID
            .removeDuplicates()
            .sink { [weak self] roomID in
                Task { @MainActor [weak self] in
                    self?.handleSelectedRoomChanged(roomID: roomID)
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        projectsListener?.remove()
        roomListenersByProjectID.values.forEach { $0.remove() }
        messagesListener?.remove()
        pinnedMessagesListener?.remove()
        keywordMatchesTask?.cancel()
        readStateFlushTask?.cancel()
        readStateListener?.remove()
        NotificationCenter.default.removeObserver(self)
    }

    var selectedProject: ProjectSummary? {
        guard let selectedProjectID else { return nil }
        return projects.first(where: { $0.id == selectedProjectID })
    }

    var selectedRoom: RoomSummary? {
        guard let selectedRoomID else { return nil }
        return rooms.first(where: { $0.id == selectedRoomID })
    }

    var selectedProjectMembers: [MemberSummary] {
        selectedProject?.members ?? []
    }

    private var currentOrCachedUserID: String? {
        currentUserID ?? authManager.collaborationUserID
    }

    var filteredProjects: [ProjectSummary] {
        let query = projectSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return projects }

        return projects.filter { project in
            [project.name, project.summary, project.memberLine]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
        }
    }

    var filteredRooms: [RoomSummary] {
        let query = roomSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveUserID = currentOrCachedUserID
        let visibleRooms = allRooms.filter { room in
            guard !room.isArchived else { return false }

            guard let effectiveUserID else {
                return topTab == .all
            }

            switch topTab {
            case .myJoined:
                return isCurrentUserParticipating(in: room, userID: effectiveUserID)
            case .all:
                return true
            }
        }

        guard !query.isEmpty else { return visibleRooms }

        return visibleRooms.filter { room in
            [room.name, room.lastMessageText, room.memberLine, projectName(for: room.projectID)]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
        }
    }

    var selectedProjectRooms: [RoomSummary] {
        guard let selectedProjectID else { return [] }
        return rooms.filter { $0.projectID == selectedProjectID }
    }

    var selectedProjectAllRooms: [RoomSummary] {
        guard let selectedProjectID else { return [] }

        return allRooms
            .filter { $0.projectID == selectedProjectID }
            .sorted { lhs, rhs in
                let leftDate = lhs.lastMessageAt ?? lhs.updatedAt
                let rightDate = rhs.lastMessageAt ?? rhs.updatedAt
                return leftDate > rightDate
            }
    }

    var selectedProjectActiveRooms: [RoomSummary] {
        selectedProjectAllRooms.filter { !$0.isArchived }
    }

    var selectedProjectArchivedRooms: [RoomSummary] {
        selectedProjectAllRooms.filter { $0.isArchived }
    }

    var featureActiveRooms: [RoomSummary] {
        allRooms.filter { !$0.isArchived }
    }

    var featureArchivedRooms: [RoomSummary] {
        allRooms.filter { $0.isArchived }
    }

    var canManageSelectedProject: Bool {
        guard selectedProject != nil else { return false }
        let effectiveUserID = currentOrCachedUserID
        return selectedProject?.ownerID == effectiveUserID
    }

    var canDeleteSelectedRoom: Bool {
        guard let selectedRoom else { return false }
        return canDeleteRoom(selectedRoom)
    }

    var canRenameSelectedRoom: Bool {
        canManageSelectedProject && selectedRoom != nil
    }

    func canManageRoom(_ room: RoomSummary) -> Bool {
        guard let effectiveUserID = currentOrCachedUserID else { return false }
        return projects.first(where: { $0.id == room.projectID })?.ownerID == effectiveUserID
    }

    func canDeleteRoom(_ room: RoomSummary) -> Bool {
        canManageRoom(room) && room.isArchived
    }

    func previewChatNotificationSound() {
        guard isChatSoundEnabled else { return }
        playChatSound(named: chatNotificationSoundName)
    }

    var keywordMatchesByKeyword: [String: [HighlightedMessageSummary]] {
        Dictionary(grouping: visibleHighlightedMessages, by: \.keyword)
    }

    var filteredMessages: [MessageSummary] {
        let query = messageSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return messages }

        return messages.filter { message in
            [message.senderName, message.text]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
        }
    }

    var visibleHighlightedMessages: [HighlightedMessageSummary] {
        let effectiveUserID = currentOrCachedUserID
        let activeRoomIDs = Set(rooms.filter { room in
            guard !room.isArchived else { return false }

            if topTab == .all { return true }

            guard let effectiveUserID else { return false }
            return isCurrentUserParticipating(in: room, userID: effectiveUserID)
        }.map(\.id))

        return highlightedMessages
            .filter { match in
                if let selectedProjectID, match.projectID != selectedProjectID {
                    return false
                }
                guard activeRoomIDs.contains(match.roomID) else { return false }
                return true
            }
            .sorted { $0.highlightedAt > $1.highlightedAt }
    }

    var selectedProjectKeywords: [String] {
        selectedProject?.keywordTags ?? Self.defaultProjectKeywords
    }

    var selectedRoomHighlightedMessages: [HighlightedMessageSummary] {
        guard let selectedProjectID,
              let selectedRoomID else {
            return []
        }

        return highlightedMessages
            .filter { $0.projectID == selectedProjectID && $0.roomID == selectedRoomID }
            .sorted { $0.highlightedAt > $1.highlightedAt }
    }

    func isPinned(_ message: MessageSummary) -> Bool {
        pinnedMessages.contains(where: { $0.id == message.id })
    }

    func isHighlighted(_ message: MessageSummary) -> Bool {
        highlightedMessages.contains(where: { $0.messageID == message.id && $0.roomID == selectedRoomID && $0.projectID == selectedProjectID })
    }

    func appliedKeywords(for message: MessageSummary) -> [String] {
        guard let projectID = selectedProjectID,
              let roomID = selectedRoomID else {
            return []
        }

        let key = messageKeywordKey(projectID: projectID, roomID: roomID, messageID: message.id)
        let applied = messageKeywordFlags[key] ?? []

        return selectedProjectKeywords.filter { applied.contains(Self.normalizeKeyword($0)) }
    }

    func isKeywordApplied(_ keyword: String, to message: MessageSummary) -> Bool {
        appliedKeywords(for: message)
            .contains { Self.normalizeKeyword($0) == Self.normalizeKeyword(keyword) }
    }

    func toggleKeyword(_ keyword: String, for message: MessageSummary) async {
        guard let projectID = selectedProjectID,
              let room = selectedRoom,
              let currentUser = authManager.currentUser else {
            errorMessage = "키워드를 반영하려면 프로젝트와 채팅방을 먼저 선택해 주세요."
            return
        }

        let normalizedKeyword = Self.normalizeKeyword(keyword)
        guard !normalizedKeyword.isEmpty else { return }

        let projectName = projectName(for: projectID)
        let reference = keywordMatchesCollection(projectID: projectID, roomID: room.id)
            .document(Self.keywordMatchDocumentID(messageID: message.id, keyword: normalizedKeyword))
        let isApplied = await isKeywordApplied(
            normalizedKeyword,
            for: message,
            projectID: projectID,
            roomID: room.id
        )

        do {
            if isApplied {
                try await reference.delete()
                syncLocalKeywordMatch(
                    projectID: projectID,
                    projectName: projectName,
                    room: room,
                    message: message,
                    keyword: normalizedKeyword,
                    isApplied: false
                )
                bannerMessage = "\(normalizedKeyword) 키워드 반영을 해제했습니다."
            } else {
                try await reference.setData([
                    "projectId": projectID,
                    "projectName": projectName,
                    "roomId": room.id,
                    "roomName": room.name,
                    "messageId": message.id,
                    "senderId": message.senderID,
                    "senderName": message.senderName,
                    "text": message.text,
                    "keyword": normalizedKeyword,
                    "matchedAt": FieldValue.serverTimestamp(),
                    "highlightedAt": FieldValue.serverTimestamp(),
                    "createdAt": Timestamp(date: message.createdAt),
                    "taggedById": currentUser.id,
                    "taggedByName": currentUser.displayName
                ], merge: true)
                syncLocalKeywordMatch(
                    projectID: projectID,
                    projectName: projectName,
                    room: room,
                    message: message,
                    keyword: normalizedKeyword,
                    isApplied: true
                )
                bannerMessage = "\(normalizedKeyword) 키워드를 반영했습니다."
            }

            if selectedProjectID == projectID {
                await loadKeywordMatches(for: projectID)
            }
        } catch {
            keywordStatusMessage = "키워드 반영에 실패했습니다. \(error.localizedDescription)"
        }
    }

    func toggleRoomMemberSelection(_ memberID: String) {
        guard memberID != currentOrCachedUserID else { return }

        if roomMemberSelection.contains(memberID) {
            roomMemberSelection.remove(memberID)
        } else {
            roomMemberSelection.insert(memberID)
        }
    }

    func unreadCount(for project: ProjectSummary) -> Int {
        rooms.filter { !$0.isArchived && unreadCount(for: $0, projectID: project.id) > 0 }.count
    }

    func unreadCount(for room: RoomSummary, projectID: String? = nil) -> Int {
        guard let lastMessageAt = room.lastMessageAt else { return 0 }
        guard !room.lastMessageSenderID.isEmpty else { return 0 }
        guard !room.lastMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 0 }
        let projectID = projectID ?? selectedProjectID
        guard let projectID else { return 0 }
        let effectiveUserID = currentOrCachedUserID
        guard let effectiveUserID, room.lastMessageSenderID != effectiveUserID else { return 0 }

        let roomKey = roomReadKey(projectID: projectID, roomID: room.id)
        if let lastReadAt = roomReadAtByKey[roomKey], lastReadAt >= lastMessageAt {
            return 0
        }

        return 1
    }

    func markSelectedRoomAsRead() async {
        guard let projectID = selectedProjectID,
              let room = selectedRoom,
              let latestMessageDate = room.lastMessageAt else {
            return
        }

        await updateReadStateIfNeeded(
            projectID: projectID,
            roomID: room.id,
            latestMessageDate: latestMessageDate
        )
    }

    func markAllRoomsInSelectedProjectAsRead() async {
        guard let projectID = selectedProjectID else { return }

        for room in rooms {
            guard let latestMessageDate = room.lastMessageAt else { continue }
            await updateReadStateIfNeeded(
                projectID: projectID,
                roomID: room.id,
                latestMessageDate: latestMessageDate
            )
        }
    }

    func togglePin(_ message: MessageSummary) async {
        guard let project = selectedProject,
              let room = selectedRoom,
              let currentUser = authManager.currentUser else {
            errorMessage = "메시지를 고정하려면 프로젝트와 채팅방을 먼저 선택해 주세요."
            return
        }

        errorMessage = nil
        let reference = pinnedMessagesCollection(projectID: project.id, roomID: room.id).document(message.id)

        do {
            if isPinned(message) {
                try await reference.delete()
                bannerMessage = "메시지 고정을 해제했습니다."
            } else {
                try await reference.setData([
                    "messageId": message.id,
                    "senderId": message.senderID,
                    "senderName": message.senderName,
                    "text": message.text,
                    "createdAt": Timestamp(date: message.createdAt),
                    "pinnedAt": FieldValue.serverTimestamp(),
                    "pinnedById": currentUser.id,
                    "pinnedByName": currentUser.displayName,
                    "projectId": project.id,
                    "roomId": room.id
                ], merge: true)
                bannerMessage = "메시지를 채팅방 상단에 고정했습니다."
            }
        } catch {
            errorMessage = "메시지 고정 처리에 실패했습니다. \(error.localizedDescription)"
        }
    }

    func openKeywordMatch(_ message: HighlightedMessageSummary) {
        pendingRoomSelectionID = message.roomID
        selectedProjectID = message.projectID
        pendingMessageNavigationID = message.messageID
        messageSearchText = ""

        if selectedProjectID == message.projectID {
            selectedRoomID = message.roomID
        }
    }

    func addKeywordToCurrentProject(_ rawKeyword: String) async {
        guard let project = selectedProject else {
            errorMessage = "프로젝트를 먼저 선택해 주세요."
            return
        }

        let normalizedKeyword = Self.normalizeKeyword(rawKeyword)
        guard !normalizedKeyword.isEmpty else {
            errorMessage = "키워드를 입력해 주세요."
            return
        }

        var nextKeywords = selectedProjectKeywords
        guard !nextKeywords.contains(where: { $0.caseInsensitiveCompare(normalizedKeyword) == .orderedSame }) else {
            bannerMessage = "이미 등록된 키워드입니다."
            return
        }

        nextKeywords.append(normalizedKeyword)
        await persistProjectKeywords(for: project, keywords: nextKeywords)
        projectKeywordDraft = ""
    }

    func removeKeywordFromCurrentProject(_ keyword: String) async {
        guard let project = selectedProject else {
            errorMessage = "프로젝트를 먼저 선택해 주세요."
            return
        }

        let normalizedKeyword = Self.normalizeKeyword(keyword)
        guard !normalizedKeyword.isEmpty else {
            errorMessage = "삭제할 키워드를 입력해 주세요."
            return
        }

        let currentKeywords = selectedProjectKeywords.map { Self.normalizeKeyword($0) }
        guard currentKeywords.contains(normalizedKeyword) else {
            bannerMessage = "이미 삭제되었거나 존재하지 않는 키워드입니다."
            return
        }

        let nextKeywords = selectedProjectKeywords.filter { Self.normalizeKeyword($0) != normalizedKeyword }
        let removedKeywords = [normalizedKeyword]

        await persistProjectKeywords(for: project, keywords: nextKeywords)
        await removeKeywordMatches(for: project.id, keywords: removedKeywords)
    }

    func toggleRoomArchive(_ room: RoomSummary) async {
        await setRoomArchive(room, archived: !room.isArchived)
    }

    func archiveRoom(_ room: RoomSummary) async {
        guard !room.isArchived else { return }
        await setRoomArchive(room, archived: true)
    }

    func restoreArchivedRoom(_ room: RoomSummary) async {
        guard room.isArchived else { return }
        await setRoomArchive(room, archived: false)
    }

    func closeRoom(_ room: RoomSummary) async {
        await archiveRoom(room)
    }

    func reopenClosedRoom(_ room: RoomSummary) async {
        await restoreArchivedRoom(room)
    }

    func deleteSelectedRoom() async {
        guard let room = selectedRoom else {
            errorMessage = "채팅방을 먼저 선택해 주세요."
            return
        }

        await deleteRoom(room)
    }

    func deleteRoom(_ room: RoomSummary) async {
        guard canManageRoom(room) else {
            errorMessage = "관리자만 채팅방을 삭제할 수 있습니다."
            return
        }

        guard room.isArchived else {
            errorMessage = "채팅방은 먼저 닫은 뒤 삭제할 수 있습니다."
            return
        }

        let roomReference = database
            .collection("projects")
            .document(room.projectID)
            .collection("chatRooms")
            .document(room.id)

        do {
            try await deleteDocuments(in: roomReference.collection("messages"))
            try await deleteDocuments(in: roomReference.collection("pinnedMessages"))
            try await deleteDocuments(in: roomReference.collection("keywordMatches"))
            try await roomReference.delete()

            highlightedMessages.removeAll { $0.projectID == room.projectID && $0.roomID == room.id }
            pinnedMessages.removeAll()
            messageKeywordFlags = messageKeywordFlags.filter { key, _ in
                !key.hasPrefix("\(room.projectID)|\(room.id)|")
            }

            if selectedRoomID == room.id {
                selectedRoomID = nil
            }

            bannerMessage = "채팅방을 삭제했습니다."
        } catch {
            errorMessage = "채팅방 삭제에 실패했습니다. \(error.localizedDescription)"
        }
    }

    func deleteProject(_ project: ProjectSummary) async -> Bool {
        guard let effectiveUserID = currentOrCachedUserID else {
            errorMessage = "프로젝트를 삭제하려면 먼저 로그인해 주세요."
            return false
        }

        guard project.ownerID == effectiveUserID else {
            errorMessage = "프로젝트 소유자만 채팅 프로젝트를 삭제할 수 있습니다."
            return false
        }

        let projectReference = database.collection("projects").document(project.id)

        do {
            let roomSnapshot = try await projectReference.collection("chatRooms").getDocuments()
            for roomDocument in roomSnapshot.documents {
                try await deleteDocuments(in: roomDocument.reference.collection("messages"))
                try await deleteDocuments(in: roomDocument.reference.collection("pinnedMessages"))
                try await deleteDocuments(in: roomDocument.reference.collection("keywordMatches"))
                try await roomDocument.reference.delete()
            }

            try await projectReference.delete()

            if selectedProjectID == project.id {
                selectedProjectID = nil
                selectedRoomID = nil
            }

            bannerMessage = "연결된 채팅 프로젝트를 삭제했습니다."
            return true
        } catch {
            errorMessage = "연결된 채팅 프로젝트 삭제에 실패했습니다. \(error.localizedDescription)"
            return false
        }
    }

    func renameSelectedRoom(to rawName: String) async {
        guard let room = selectedRoom else {
            errorMessage = "채팅방을 먼저 선택해 주세요."
            return
        }

        let nextName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nextName.isEmpty else {
            errorMessage = "채팅방 이름을 입력해 주세요."
            return
        }

        guard nextName != room.name else {
            bannerMessage = "채팅방 이름이 변경되지 않았습니다."
            return
        }

        let roomReference = database
            .collection("projects")
            .document(room.projectID)
            .collection("chatRooms")
            .document(room.id)

        do {
            try await roomReference.setData([
                "name": nextName,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            bannerMessage = "채팅방 이름을 변경했습니다."
        } catch {
            errorMessage = "채팅방 이름 변경에 실패했습니다. \(error.localizedDescription)"
        }
    }

    func selectRoom(_ room: RoomSummary) {
        pendingRoomSelectionID = room.id
        selectedProjectID = room.projectID

        if selectedProjectID == room.projectID {
            selectedRoomID = room.id
        }
    }

    func projectName(for projectID: String) -> String {
        projects.first(where: { $0.id == projectID })?.name ?? "프로젝트"
    }

    func createProject() async {
        let result = await createProject(
            name: projectNameDraft,
            summary: projectSummaryDraft,
            inviteEmailsRaw: inviteEmailsDraft,
            shouldCreateDefaultRoom: true,
            autoSelectAfterCreate: true,
            trackProgress: true
        )

        if result == nil {
            return
        }
    }

    func createProject(
        name: String,
        summary: String,
        inviteEmailsRaw: String,
        shouldCreateDefaultRoom: Bool = true,
        autoSelectAfterCreate: Bool = true,
        trackProgress: Bool = true
    ) async -> String? {
        guard let currentUser = authManager.currentUser else {
            errorMessage = "프로젝트를 만들려면 먼저 로그인해야 합니다."
            return nil
        }

        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "프로젝트 이름을 입력해 주세요."
            return nil
        }

        let shouldDisplayProgress = trackProgress
        if shouldDisplayProgress {
            isCreatingProject = true
            roomNameDraft = ""
        }

        errorMessage = nil
        bannerMessage = nil

        defer {
            if shouldDisplayProgress {
                isCreatingProject = false
            }
        }

        do {
            let inviteEmails = normalizedEmails(from: inviteEmailsRaw)
            let resolvedMembers = try await resolveDirectoryMembers(for: inviteEmails)

            let ownerMember = MemberSummary(
                id: currentUser.id,
                displayName: currentUser.displayName,
                email: currentUser.email,
                photoURLString: currentUser.photoURL?.absoluteString ?? ""
            )

            var uniqueMembers = [ownerMember]
            for member in resolvedMembers.members where !uniqueMembers.contains(where: { $0.id == member.id }) {
                uniqueMembers.append(member)
            }

            let projectReference = database.collection("projects").document()
            let roomReference = projectReference.collection("chatRooms").document()
            let memberIDs = uniqueMembers.map(\.id)
            let memberData = uniqueMembers.map(\.firestoreData)

            try await projectReference.setData([
                "name": name,
                "summary": summary,
                "ownerId": currentUser.id,
                "memberIds": memberIDs,
                "memberSummaries": memberData,
                "keywordList": Self.defaultProjectKeywords,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])

            if shouldCreateDefaultRoom {
                try await roomReference.setData([
                    "name": name,
                    "createdBy": currentUser.id,
                    "projectId": projectReference.documentID,
                    "memberIds": memberIDs,
                "memberSummaries": memberData,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "isArchived": false,
                "isPrimaryProjectRoom": true,
                "lastMessageText": "",
                "lastMessageSenderId": ""
            ])
            }

            let now = Date()
            let projectData: [String: Any] = [
                "name": name,
                "summary": summary,
                "ownerId": currentUser.id,
                "memberIds": memberIDs,
                "memberSummaries": memberData,
                "keywordList": Self.defaultProjectKeywords,
                "createdAt": now,
                "updatedAt": now
            ]
            if let optimisticProject = ProjectSummary(id: projectReference.documentID, dictionary: projectData) {
                upsertProjectLocally(optimisticProject)
            }

            if shouldCreateDefaultRoom {
                let roomData: [String: Any] = [
                    "name": name,
                    "createdBy": currentUser.id,
                    "projectId": projectReference.documentID,
                    "memberIds": memberIDs,
                    "memberSummaries": memberData,
                    "createdAt": now,
                    "updatedAt": now,
                    "isArchived": false,
                    "isPrimaryProjectRoom": true,
                    "lastMessageText": "",
                    "lastMessageSenderId": ""
                ]
                if let optimisticRoom = RoomSummary(
                    id: roomReference.documentID,
                    projectID: projectReference.documentID,
                    dictionary: roomData
                ) {
                    upsertRoomLocally(optimisticRoom)
                }
            }

            // Start listening to the new project's rooms immediately so
            // auto-created chats appear in Team Messenger without waiting for
            // the next project snapshot cycle.
            if roomListenersByProjectID[projectReference.documentID] == nil {
                subscribeRooms(for: projectReference.documentID)
            }
            rebuildRoomCollections()

            if shouldDisplayProgress {
                if autoSelectAfterCreate {
                    selectedProjectID = projectReference.documentID
                    if shouldCreateDefaultRoom {
                        selectedRoomID = roomReference.documentID
                    }
                }

                projectNameDraft = ""
                projectSummaryDraft = ""
                inviteEmailsDraft = ""
            }

            if resolvedMembers.unresolvedEmails.isEmpty {
                bannerMessage = "프로젝트가 생성되었습니다."
            } else {
                bannerMessage = "프로젝트는 생성되었지만 초대 대상을 찾지 못한 이메일이 있습니다: \(resolvedMembers.unresolvedEmails.joined(separator: ", "))"
            }

            return projectReference.documentID
        } catch {
            errorMessage = "프로젝트 생성에 실패했습니다. \(error.localizedDescription)"
            return nil
        }
    }

    func createRoom() async {
        guard let project = selectedProject else {
            errorMessage = "먼저 프로젝트를 선택해 주세요."
            return
        }
        guard let currentUser = authManager.currentUser else {
            errorMessage = "채팅방을 만들려면 로그인 상태가 필요합니다."
            return
        }

        let roomName = roomNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roomName.isEmpty else {
            errorMessage = "채팅방 이름을 입력해 주세요."
            return
        }

        isCreatingRoom = true
        errorMessage = nil

        var selectedMemberIDs = roomMemberSelection
        selectedMemberIDs.insert(currentUser.id)

        let members = project.members.filter { selectedMemberIDs.contains($0.id) }
        let roomReference = database
            .collection("projects")
            .document(project.id)
            .collection("chatRooms")
            .document()

        do {
            try await roomReference.setData([
                "name": roomName,
                "createdBy": currentUser.id,
                "projectId": project.id,
                "memberIds": members.map(\.id),
                "memberSummaries": members.map(\.firestoreData),
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "isArchived": false,
                "isPrimaryProjectRoom": false,
                "lastMessageText": "",
                "lastMessageSenderId": ""
            ])

            selectedRoomID = roomReference.documentID
            roomNameDraft = ""
            roomMemberSelection = Set(project.memberIDs)
            bannerMessage = "새 채팅방이 추가되었습니다."
        } catch {
            errorMessage = "채팅방 생성에 실패했습니다. \(error.localizedDescription)"
        }

        isCreatingRoom = false
    }

    func sendMessage() async {
        let text = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        await sendMessage(text: text, shouldClearDraft: true)
    }

    func sendMessage(text explicitText: String, shouldClearDraft: Bool = false) async {
        guard let project = selectedProject else {
            errorMessage = "프로젝트를 먼저 선택해 주세요."
            return
        }
        guard let room = selectedRoom else {
            errorMessage = "채팅방을 먼저 선택해 주세요."
            return
        }
        guard let currentUser = authManager.currentUser else {
            errorMessage = "메시지를 보내려면 로그인 상태가 필요합니다."
            return
        }

        let text = explicitText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSendingMessage = true
        errorMessage = nil

        let messageReference = database
            .collection("projects")
            .document(project.id)
            .collection("chatRooms")
            .document(room.id)
            .collection("messages")
            .document()

        do {
            let roomReference = database
                .collection("projects")
                .document(project.id)
                .collection("chatRooms")
                .document(room.id)
            let projectReference = database
                .collection("projects")
                .document(project.id)

            let payloads = messageKeywordPayloads(
                projectID: project.id,
                projectName: project.name,
                room: room,
                messageID: messageReference.documentID,
                senderID: currentUser.id,
                senderName: currentUser.displayName,
                text: text
            )

            let batch = database.batch()
            batch.setData([
                "senderId": currentUser.id,
                "senderName": currentUser.displayName,
                "text": text,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: messageReference)
            batch.setData([
                "updatedAt": FieldValue.serverTimestamp(),
                "lastMessageText": text,
                "lastMessageSenderId": currentUser.id,
                "lastMessageAt": FieldValue.serverTimestamp()
            ], forDocument: roomReference, merge: true)
            batch.setData([
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: projectReference, merge: true)

            for payload in payloads {
                batch.setData(payload.data, forDocument: payload.documentReference, merge: true)
            }

            try await batch.commit()

            if !payloads.isEmpty && selectedProjectID == project.id {
                await loadKeywordMatches(for: project.id)
            }

            if shouldClearDraft {
                messageDraft = ""
            }
        } catch {
            errorMessage = "메시지 전송에 실패했습니다. \(error.localizedDescription)"
        }

        isSendingMessage = false
    }

    func deleteMessage(_ message: MessageSummary) async {
        guard let project = selectedProject, let room = selectedRoom else { return }
        
        let messageReference = database
            .collection("projects")
            .document(project.id)
            .collection("chatRooms")
            .document(room.id)
            .collection("messages")
            .document(message.id)

        do {
            try await messageReference.delete()
            await removePinnedMessage(projectID: project.id, roomID: room.id, messageID: message.id)
            await removeKeywordMatches(
                projectID: project.id,
                roomID: room.id,
                messageID: message.id
            )
            bannerMessage = "메시지를 삭제했습니다."
        } catch {
            errorMessage = "메시지 삭제에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func editMessage(_ message: MessageSummary, newText: String) async {
        guard let project = selectedProject,
              let room = selectedRoom,
              let currentUser = authManager.currentUser else { return }
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let messageReference = database
            .collection("projects")
            .document(project.id)
            .collection("chatRooms")
            .document(room.id)
            .collection("messages")
            .document(message.id)

        do {
            try await messageReference.updateData([
                "text": text,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            await removeKeywordMatches(
                projectID: project.id,
                roomID: room.id,
                messageID: message.id
            )
            await indexMessageKeywords(
                projectID: project.id,
                projectName: project.name,
                room: room,
                messageID: message.id,
                senderID: currentUser.id,
                senderName: currentUser.displayName,
                text: text
            )
            bannerMessage = "메시지를 수정했습니다."
        } catch {
            errorMessage = "메시지 수정에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func handleAuthenticationChange(userID: String?) {
        projectsListener?.remove()
        roomListenersByProjectID.values.forEach { $0.remove() }
        roomListenersByProjectID = [:]
        allRoomsByProjectID = [:]
        messagesListener?.remove()
        pinnedMessagesListener?.remove()
        highlightedMessages = []
        keywordStatusMessage = nil
        messageKeywordFlags = [:]
        keywordMatchesTask?.cancel()
        readStateListener?.remove()
        readStateFlushTask?.cancel()
        pendingReadStateWrites = [:]
        pendingMessageNavigationID = nil
        hasTriggeredOneTimeCleanup = false
        initializedRoomSnapshotProjects = []
        deliveredRoomNotificationKeys = []
        currentUserID = userID
        projects = []
        allRooms = []
        rooms = []
        messages = []
        pinnedMessages = []
        highlightedMessages = []
        keywordStatusMessage = nil
        roomReadAtByKey = [:]
        selectedProjectID = nil
        selectedRoomID = nil
        pendingRoomSelectionID = nil
        roomMemberSelection = []
        roomNameDraft = ""
        bannerMessage = nil
        errorMessage = nil

        guard let userID else {
            statusLine = authManager.collaborationStatusLine
            return
        }

        if isChatNotificationEnabled {
            requestNotificationPermissionIfNeeded()
        }
        subscribeReadStates(for: userID)
        subscribeProjects(for: userID)
    }

    private func handleSelectedProjectChanged(projectID: String?) {
        selectedRoomID = nil
        pinnedMessages = []
        highlightedMessages = []
        messageKeywordFlags = [:]
        keywordMatchesTask?.cancel()
        keywordStatusMessage = nil
        roomMemberSelection = []
        roomNameDraft = ""
        projectKeywordDraft = ""

        syncRoomSubscriptions()
        refreshSelectedProjectRooms(projectID: projectID)
        reconcileSelectedRoom()
        prepareRoomMemberSelection()
        Task { @MainActor [weak self] in
            self?.refreshKeywordMatches(for: projectID)
        }
    }

    private func handleSelectedRoomChanged(roomID: String?) {
        messagesListener?.remove()
        messages = []
        pinnedMessagesListener?.remove()
        pinnedMessages = []
        messageKeywordFlags = [:]

        guard let roomID, let projectID = selectedProjectID else { return }
        refreshKeywordMatches(for: projectID)
        subscribePinnedMessages(for: projectID, roomID: roomID)
        subscribeMessages(for: projectID, roomID: roomID)
    }

    private func subscribeReadStates(for userID: String) {
        readStateListener = userReadStateCollection(for: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = "읽음 상태를 불러오지 못했습니다. \(error.localizedDescription)"
                        return
                    }

                    var nextState: [String: Date] = [:]
                    for document in snapshot?.documents ?? [] {
                        let data = document.data()
                        let projectID = data["projectId"] as? String ?? ""
                        let roomID = data["roomId"] as? String ?? ""
                        guard !projectID.isEmpty, !roomID.isEmpty else { continue }

                        let roomKey = self.roomReadKey(projectID: projectID, roomID: roomID)
                        if let timestamp = data["lastReadAt"] as? Timestamp {
                            nextState[roomKey] = timestamp.dateValue()
                        } else if let date = data["lastReadAt"] as? Date {
                            nextState[roomKey] = date
                        }
                    }

                    self.roomReadAtByKey = nextState
                }
            }
    }

    private func refreshKeywordMatches(for projectID: String?) {
        keywordMatchesTask?.cancel()
        highlightedMessages = []
        messageKeywordFlags = [:]
        keywordStatusMessage = nil

        guard let projectID else {
            isKeywordLoading = false
            return
        }

        isKeywordLoading = true
        keywordMatchesTask = Task { [weak self] in
            guard let self else { return }
            await self.loadKeywordMatches(for: projectID)
            await MainActor.run { self.isKeywordLoading = false }
        }
    }

    private func loadKeywordMatches(for projectID: String) async {
        let eligibleRoomIDs: Set<String>
        let effectiveUserID = currentOrCachedUserID

        if topTab == .myJoined, let effectiveUserID {
            eligibleRoomIDs = Set(rooms.filter { room in
                room.projectID == projectID
                    && !room.isArchived
                    && isCurrentUserParticipating(in: room, userID: effectiveUserID)
            }.map(\.id))
        } else {
            eligibleRoomIDs = Set(
                rooms.filter { room in
                    room.projectID == projectID && !room.isArchived
                }.map(\.id)
            )
        }

        guard !eligibleRoomIDs.isEmpty else {
            highlightedMessages = []
            keywordStatusMessage = nil
            messageKeywordFlags = [:]
            return
        }

        do {
            let baseQuery = database
                .collectionGroup("keywordMatches")
                .whereField("projectId", isEqualTo: projectID)

            let roomScopedQuery: Query
            let sortedEligibleRoomIDs = eligibleRoomIDs.sorted()

            if sortedEligibleRoomIDs.count == 1, let roomID = sortedEligibleRoomIDs.first {
                roomScopedQuery = baseQuery.whereField("roomId", isEqualTo: roomID)
            } else if sortedEligibleRoomIDs.count <= 10 {
                roomScopedQuery = baseQuery.whereField("roomId", in: sortedEligibleRoomIDs)
            } else {
                roomScopedQuery = baseQuery
            }

            let snapshot = try await roomScopedQuery
                .order(by: "matchedAt", descending: true)
                .limit(to: 180)
                .getDocuments()

            let filtered = snapshot.documents
                .compactMap(HighlightedMessageSummary.init(document:))
                .filter { match in
                    eligibleRoomIDs.contains(match.roomID)
                }
                .sorted { $0.highlightedAt > $1.highlightedAt }
                .prefix(120)

            keywordStatusMessage = nil
            highlightedMessages = Array(filtered)
            syncKeywordMatchesFromSnapshot(highlightedMessages)
        } catch {
            keywordStatusMessage = keywordStatusMessage(for: error)
        }
    }

    private func subscribeProjects(for userID: String) {
        isLoadingProjects = true
        statusLine = "프로젝트를 불러오는 중입니다."

        projectsListener = database.collection("projects")
            .whereField("memberIds", arrayContains: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = "프로젝트 목록을 불러오지 못했습니다. \(error.localizedDescription)"
                        self.statusLine = "프로젝트 목록을 불러오지 못했습니다."
                        self.isLoadingProjects = false
                        return
                    }

                    let parsedProjects = snapshot?.documents.compactMap(ProjectSummary.init(document:)) ?? []
                    self.projects = parsedProjects.sorted {
                        $0.updatedAt > $1.updatedAt
                    }
                    self.isLoadingProjects = false
                    self.statusLine = self.projects.isEmpty ? "프로젝트가 아직 없습니다." : "프로젝트와 채팅방이 연결되었습니다."
                    self.reconcileSelectedProject()
                    self.syncRoomSubscriptions()
                    self.refreshSelectedProjectRooms(projectID: self.selectedProjectID)
                    self.refreshKeywordMatches(for: self.selectedProjectID)

                    if !self.projects.isEmpty {
                        Task { @MainActor [weak self] in
                            await self?.runOneTimeChatMetadataCleanupIfNeeded(userID: userID)
                        }
                    }
                }
        }
    }

    private func subscribeRooms(for projectID: String) {
        roomListenersByProjectID[projectID]?.remove()
        roomListenersByProjectID[projectID] = database
            .collection("projects")
            .document(projectID)
            .collection("chatRooms")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if error != nil {
                        self.allRoomsByProjectID[projectID] = []
                        self.rebuildRoomCollections()
                        return
                    }

                    let previousRooms = self.allRoomsByProjectID[projectID] ?? []
                    let parsedRooms = snapshot?.documents.compactMap(RoomSummary.init(document:)) ?? []

                    if self.initializedRoomSnapshotProjects.contains(projectID) {
                        self.notifyForIncomingMessages(oldRooms: previousRooms, newRooms: parsedRooms)
                    } else {
                        self.initializedRoomSnapshotProjects.insert(projectID)
                    }

                    self.allRoomsByProjectID[projectID] = parsedRooms.sorted { lhs, rhs in
                        let leftDate = lhs.lastMessageAt ?? lhs.updatedAt
                        let rightDate = rhs.lastMessageAt ?? rhs.updatedAt
                        return leftDate > rightDate
                    }
                    self.rebuildRoomCollections()
                }
            }
    }

    private func subscribePinnedMessages(for projectID: String, roomID: String) {
        pinnedMessagesListener = pinnedMessagesCollection(projectID: projectID, roomID: roomID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if error != nil {
                        self.pinnedMessages = []
                        return
                    }

                    self.pinnedMessages = (snapshot?.documents.compactMap(PinnedMessageSummary.init(document:)) ?? [])
                        .sorted { $0.pinnedAt > $1.pinnedAt }
                }
            }
    }

    private func subscribeMessages(for projectID: String, roomID: String) {
        messagesListener = database
            .collection("projects")
            .document(projectID)
            .collection("chatRooms")
            .document(roomID)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: initialMessagePageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = "메시지를 불러오지 못했습니다. \(error.localizedDescription)"
                        return
                    }

                    let documents = snapshot?.documents ?? []
                    let parsedMessages = documents.compactMap(MessageSummary.init(document:))
                    self.messages = parsedMessages.reversed()
                    await self.markSelectedRoomAsRead()
                }
            }
    }

    private func reconcileSelectedProject() {
        guard !projects.isEmpty else {
            selectedProjectID = nil
            return
        }

        if let selectedProjectID, projects.contains(where: { $0.id == selectedProjectID }) {
            return
        }

        selectedProjectID = allRooms.first?.projectID ?? projects.first?.id
    }

    private func reconcileSelectedRoom() {
        guard !rooms.isEmpty else {
            selectedRoomID = nil
            return
        }

        if let pendingRoomSelectionID,
           rooms.contains(where: { $0.id == pendingRoomSelectionID }) {
            selectedRoomID = pendingRoomSelectionID
            self.pendingRoomSelectionID = nil
            return
        }

        if let selectedRoomID, rooms.contains(where: { $0.id == selectedRoomID && !$0.isArchived }) {
            return
        }

        selectedRoomID = nil
    }

    private func prepareRoomMemberSelection() {
        guard let project = selectedProject else {
            roomMemberSelection = []
            return
        }

        if roomMemberSelection.isEmpty {
            roomMemberSelection = Set(project.memberIDs)
        } else {
            roomMemberSelection = roomMemberSelection.intersection(Set(project.memberIDs))
            if let currentUserID {
                roomMemberSelection.insert(currentUserID)
            }
        }
    }

    private func updateReadStateIfNeeded(projectID: String, roomID: String, latestMessageDate: Date) async {
        guard currentOrCachedUserID != nil else { return }

        let roomKey = roomReadKey(projectID: projectID, roomID: roomID)
        if let existingDate = roomReadAtByKey[roomKey], existingDate >= latestMessageDate {
            return
        }
        if let pendingDate = pendingReadStateWrites[roomKey]?.lastReadAt, pendingDate >= latestMessageDate {
            return
        }

        pendingReadStateWrites[roomKey] = (projectID: projectID, roomID: roomID, lastReadAt: latestMessageDate)
        roomReadAtByKey[roomKey] = latestMessageDate
        scheduleReadStateFlush()
    }

    private func scheduleReadStateFlush() {
        readStateFlushTask?.cancel()
        readStateFlushTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }

            await self?.flushPendingReadStates()
        }
    }

    private func flushPendingReadStates() async {
        guard let currentUserID else { return }

        let pendingWrites = pendingReadStateWrites
        guard !pendingWrites.isEmpty else { return }
        pendingReadStateWrites = [:]

        do {
            let batch = database.batch()
            let userReadStateCollection = userReadStateCollection(for: currentUserID)

            for (roomKey, pendingWrite) in pendingWrites {
                let document = userReadStateCollection.document(roomKey)
                batch.setData([
                    "projectId": pendingWrite.projectID,
                    "roomId": pendingWrite.roomID,
                    "lastReadAt": Timestamp(date: pendingWrite.lastReadAt),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: document, merge: true)
            }

            try await batch.commit()
        } catch {
            for (roomKey, pendingWrite) in pendingWrites {
                pendingReadStateWrites[roomKey] = pendingWrite
            }
            errorMessage = "읽음 상태 저장에 실패했습니다. \(error.localizedDescription)"
        }
    }

    private func roomReadKey(projectID: String, roomID: String) -> String {
        "\(projectID)__\(roomID)"
    }

    private func isCurrentUserParticipating(in room: RoomSummary, userID: String) -> Bool {
        if room.memberIDs.contains(userID) {
            return true
        }

        guard room.memberIDs.isEmpty else {
            return false
        }

        if let projectMemberIDs = projects.first(where: { $0.id == room.projectID })?.memberIDs,
           projectMemberIDs.contains(userID) {
            return true
        }

        return false
    }

    private func messageKeywordKey(projectID: String, roomID: String, messageID: String) -> String {
        "\(projectID)|\(roomID)|\(messageID)"
    }

    private func hasMessageKeywordMapEntry(for keyword: String, projectID: String, roomID: String, messageID: String) -> Bool {
        let key = messageKeywordKey(projectID: projectID, roomID: roomID, messageID: messageID)
        return messageKeywordFlags[key]?.contains(Self.normalizeKeyword(keyword)) ?? false
    }

    private func syncLocalKeywordMap(
        for roomID: String,
        messageID: String,
        keyword: String,
        projectID: String,
        isApplied: Bool
    ) {
        let key = messageKeywordKey(projectID: projectID, roomID: roomID, messageID: messageID)
        let normalizedKeyword = Self.normalizeKeyword(keyword)
        guard !normalizedKeyword.isEmpty else { return }

        if isApplied {
            var updated = messageKeywordFlags[key] ?? []
            updated.insert(normalizedKeyword)
            messageKeywordFlags[key] = updated
        } else {
            guard var updated = messageKeywordFlags[key] else { return }
            updated.remove(normalizedKeyword)
            if updated.isEmpty {
                messageKeywordFlags.removeValue(forKey: key)
            } else {
                messageKeywordFlags[key] = updated
            }
        }
    }

    private func syncKeywordMatchesFromSnapshot(_ matches: [HighlightedMessageSummary]) {
        var nextFlags: [String: Set<String>] = [:]

        for match in matches {
            let normalizedKeyword = Self.normalizeKeyword(match.keyword)
            guard !normalizedKeyword.isEmpty else { continue }

            let key = messageKeywordKey(
                projectID: match.projectID,
                roomID: match.roomID,
                messageID: match.messageID
            )
            nextFlags[key, default: []].insert(normalizedKeyword)
        }

        messageKeywordFlags = nextFlags
    }

    private func isKeywordApplied(
        _ keyword: String,
        for message: MessageSummary,
        projectID: String,
        roomID: String
    ) async -> Bool {
        let normalizedKeyword = Self.normalizeKeyword(keyword)
        guard !normalizedKeyword.isEmpty else { return false }

        if hasMessageKeywordMapEntry(for: normalizedKeyword, projectID: projectID, roomID: roomID, messageID: message.id) {
            return true
        }

        do {
            let snapshot = try await keywordMatchesCollection(projectID: projectID, roomID: roomID)
                .document(Self.keywordMatchDocumentID(messageID: message.id, keyword: normalizedKeyword))
                .getDocument()
            return snapshot.exists
        } catch {
            return false
        }
    }

    private func syncLocalKeywordMatch(
        projectID: String,
        projectName: String,
        room: RoomSummary,
        message: MessageSummary,
        keyword: String,
        isApplied: Bool
    ) {
        let normalizedKeyword = Self.normalizeKeyword(keyword)
        guard !normalizedKeyword.isEmpty else { return }
        syncLocalKeywordMap(
            for: room.id,
            messageID: message.id,
            keyword: normalizedKeyword,
            projectID: projectID,
            isApplied: isApplied
        )

        let matchID = Self.keywordMatchDocumentID(messageID: message.id, keyword: normalizedKeyword)
        let matchPredicate: (HighlightedMessageSummary) -> Bool = { summary in
            (summary.messageID == message.id
                && summary.roomID == room.id
                && Self.normalizeKeyword(summary.keyword) == normalizedKeyword)
            || summary.id == matchID
        }

        if !isApplied {
            highlightedMessages.removeAll(where: matchPredicate)
            return
        }

        highlightedMessages.removeAll(where: matchPredicate)

        let nowMatch = HighlightedMessageSummary(
            id: matchID,
            projectID: projectID,
            projectName: projectName,
            roomID: room.id,
            keyword: normalizedKeyword,
            roomName: room.name,
            messageID: message.id,
            senderID: message.senderID,
            senderName: message.senderName,
            text: message.text,
            createdAt: message.createdAt,
            highlightedAt: .now
        )

        highlightedMessages.append(nowMatch)
        highlightedMessages.sort { $0.highlightedAt > $1.highlightedAt }
        if highlightedMessages.count > 200 {
            highlightedMessages = Array(highlightedMessages.prefix(200))
        }
    }

    private func matchingKeywords(in text: String, for projectKeywords: [String]) -> [String] {
        let normalizedText = text.lowercased()
        return projectKeywords.compactMap { keyword in
            let normalizedKeyword = Self.normalizeKeyword(keyword).lowercased()
            guard !normalizedKeyword.isEmpty else { return nil }

            if normalizedText.contains(normalizedKeyword.lowercased()) {
                return Self.normalizeKeyword(keyword)
            }
            return nil
        }
    }

    private struct MessageKeywordPayload {
        let documentReference: DocumentReference
        let data: [String: Any]
    }

    private func messageKeywordPayloads(
        projectID: String,
        projectName: String,
        room: RoomSummary,
        messageID: String,
        senderID: String,
        senderName: String,
        text: String
    ) -> [MessageKeywordPayload] {
        guard let roomKeywords = projects.first(where: { $0.id == projectID })?.keywordTags else { return [] }

        let matchedKeywords = matchingKeywords(in: text, for: roomKeywords)
        guard !matchedKeywords.isEmpty else { return [] }

        return matchedKeywords.map { keyword in
            MessageKeywordPayload(
                documentReference: keywordMatchesCollection(projectID: projectID, roomID: room.id)
                    .document(Self.keywordMatchDocumentID(messageID: messageID, keyword: keyword)),
                data: [
                    "projectId": projectID,
                    "projectName": projectName,
                    "roomId": room.id,
                    "roomName": room.name,
                    "messageId": messageID,
                    "senderId": senderID,
                    "senderName": senderName,
                    "text": text,
                    "keyword": keyword,
                    "matchedAt": FieldValue.serverTimestamp(),
                    "highlightedAt": FieldValue.serverTimestamp(),
                    "createdAt": FieldValue.serverTimestamp()
                ]
            )
        }
    }

    private func indexMessageKeywords(
        projectID: String,
        projectName: String,
        room: RoomSummary,
        messageID: String,
        senderID: String,
        senderName: String,
        text: String
    ) async {
        let payloads = messageKeywordPayloads(
            projectID: projectID,
            projectName: projectName,
            room: room,
            messageID: messageID,
            senderID: senderID,
            senderName: senderName,
            text: text
        )
        guard !payloads.isEmpty else { return }

        do {
            let batch = database.batch()

            for payload in payloads {
                batch.setData(payload.data, forDocument: payload.documentReference, merge: true)
            }

            try await batch.commit()

            if selectedProjectID == projectID {
                await loadKeywordMatches(for: projectID)
            }
        } catch {
            errorMessage = "키워드 인덱싱에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func removeKeywordMatches(projectID: String, roomID: String, messageID: String) async {
        do {
            let snapshot = try await keywordMatchesCollection(projectID: projectID, roomID: roomID)
                .whereField("messageId", isEqualTo: messageID)
                .getDocuments()

            for document in snapshot.documents {
                try await document.reference.delete()
            }

            let matchKey = messageKeywordKey(projectID: projectID, roomID: roomID, messageID: messageID)
            messageKeywordFlags[matchKey] = nil
            highlightedMessages.removeAll {
                $0.projectID == projectID
                    && $0.roomID == roomID
                    && $0.messageID == messageID
            }
        } catch {
            errorMessage = "키워드 인덱스 정리에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func removePinnedMessage(projectID: String, roomID: String, messageID: String) async {
        do {
            try await pinnedMessagesCollection(projectID: projectID, roomID: roomID)
                .document(messageID)
                .delete()
            pinnedMessages.removeAll { $0.id == messageID }
        } catch {
            errorMessage = "고정 메시지 정리에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func cleanupPreferenceKey(for userID: String) -> String {
        "StudioLeafPortal.\(oneTimeCleanupVersion).\(userID)"
    }

    private func runOneTimeChatMetadataCleanupIfNeeded(userID: String) async {
        guard !hasTriggeredOneTimeCleanup else { return }

        let defaultsKey = cleanupPreferenceKey(for: userID)
        if UserDefaults.standard.bool(forKey: defaultsKey) {
            hasTriggeredOneTimeCleanup = true
            return
        }

        hasTriggeredOneTimeCleanup = true

        do {
            var deletedPinnedCount = 0
            var deletedKeywordCount = 0

            for project in projects {
                let roomsSnapshot = try await database
                    .collection("projects")
                    .document(project.id)
                    .collection("chatRooms")
                    .getDocuments()

                let primaryRoomID = primaryRoomIDForMigration(
                    projectName: project.name,
                    roomDocuments: roomsSnapshot.documents
                )

                for roomDocument in roomsSnapshot.documents {
                    let deletedCounts = try await cleanupMetadataDocuments(
                        projectID: project.id,
                        projectName: project.name,
                        roomDocument: roomDocument,
                        primaryRoomID: primaryRoomID
                    )
                    deletedPinnedCount += deletedCounts.pinned
                    deletedKeywordCount += deletedCounts.keyword
                }
            }

            UserDefaults.standard.set(true, forKey: defaultsKey)

            if deletedPinnedCount > 0 || deletedKeywordCount > 0 {
                bannerMessage = "이전 찌꺼기 데이터를 정리했습니다. 공지 \(deletedPinnedCount)건, 키워드 \(deletedKeywordCount)건"
                if let selectedProjectID {
                    await loadKeywordMatches(for: selectedProjectID)
                }
            }
        } catch {
            hasTriggeredOneTimeCleanup = false
            errorMessage = "이전 채팅 메타데이터 정리에 실패했습니다. \(error.localizedDescription)"
        }
    }

    private func cleanupMetadataDocuments(
        projectID: String,
        projectName: String,
        roomDocument: QueryDocumentSnapshot,
        primaryRoomID: String?
    ) async throws -> (pinned: Int, keyword: Int) {
        let roomID = roomDocument.documentID
        let messagesCollection = database
            .collection("projects")
            .document(projectID)
            .collection("chatRooms")
            .document(roomID)
            .collection("messages")

        let roomData = roomDocument.data()
        let shouldRenameLegacyDefaultRoom = (roomData["name"] as? String) == "전체 대화"
        let shouldMarkPrimaryRoom = primaryRoomID == roomID

        if shouldRenameLegacyDefaultRoom || roomData["isPrimaryProjectRoom"] == nil {
            var roomUpdate: [String: Any] = [
                "updatedAt": FieldValue.serverTimestamp(),
                "isPrimaryProjectRoom": shouldMarkPrimaryRoom
            ]

            if shouldRenameLegacyDefaultRoom {
                roomUpdate["name"] = projectName
            }

            try await roomDocument.reference.setData(roomUpdate, merge: true)

            let keywordSnapshot = try await keywordMatchesCollection(projectID: projectID, roomID: roomID).getDocuments()
            if !keywordSnapshot.documents.isEmpty {
                let batch = database.batch()
                for document in keywordSnapshot.documents {
                    batch.setData([
                        "roomName": projectName
                    ], forDocument: document.reference, merge: true)
                }
                try await batch.commit()
            }
        }

        var deletedPinnedCount = 0
        var deletedKeywordCount = 0

        let pinnedSnapshot = try await pinnedMessagesCollection(projectID: projectID, roomID: roomID)
            .getDocuments()
        for document in pinnedSnapshot.documents {
            let messageID = (document.data()["messageId"] as? String) ?? document.documentID
            let messageSnapshot = try await messagesCollection.document(messageID).getDocument()
            let messageExists = messageSnapshot.exists
            if !messageExists {
                try await document.reference.delete()
                deletedPinnedCount += 1
            }
        }

        let keywordSnapshot = try await keywordMatchesCollection(projectID: projectID, roomID: roomID)
            .getDocuments()
        for document in keywordSnapshot.documents {
            guard let messageID = document.data()["messageId"] as? String, !messageID.isEmpty else {
                try await document.reference.delete()
                deletedKeywordCount += 1
                continue
            }

            let messageSnapshot = try await messagesCollection.document(messageID).getDocument()
            let messageExists = messageSnapshot.exists
            if !messageExists {
                try await document.reference.delete()
                deletedKeywordCount += 1
            }
        }

        return (deletedPinnedCount, deletedKeywordCount)
    }

    private func primaryRoomIDForMigration(
        projectName: String,
        roomDocuments: [QueryDocumentSnapshot]
    ) -> String? {
        if let existingPrimaryRoom = roomDocuments.first(where: {
            ($0.data()["isPrimaryProjectRoom"] as? Bool) == true
        }) {
            return existingPrimaryRoom.documentID
        }

        if let legacyDefaultRoom = roomDocuments.first(where: {
            ($0.data()["name"] as? String) == "전체 대화"
        }) {
            return legacyDefaultRoom.documentID
        }

        if let projectNamedRoom = roomDocuments.first(where: {
            ($0.data()["name"] as? String) == projectName
        }) {
            return projectNamedRoom.documentID
        }

        if roomDocuments.count == 1 {
            return roomDocuments.first?.documentID
        }

        return roomDocuments.min { lhs, rhs in
            migrationDateValue(from: lhs.data()["createdAt"]) < migrationDateValue(from: rhs.data()["createdAt"])
        }?.documentID
    }

    private func migrationDateValue(from value: Any?) -> Date {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = value as? Date {
            return date
        }
        return .distantFuture
    }

    private func deleteDocuments(in collection: CollectionReference, batchSize: Int = 200) async throws {
        while true {
            let snapshot = try await collection.limit(to: batchSize).getDocuments()
            if snapshot.documents.isEmpty {
                return
            }

            let batch = database.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }

    private func removeKeywordMatches(for projectID: String, keywords: [String]) async {
        let normalizedKeywords = Set(keywords.map { Self.normalizeKeyword($0) })
        guard !normalizedKeywords.isEmpty else { return }

        let roomsToClean = allRoomsByProjectID[projectID] ?? allRooms.filter { $0.projectID == projectID }
        for room in roomsToClean {
            for keyword in normalizedKeywords {
                do {
                    let snapshot = try await keywordMatchesCollection(projectID: projectID, roomID: room.id)
                        .whereField("keyword", isEqualTo: keyword)
                        .getDocuments()

                    for document in snapshot.documents {
                        try await document.reference.delete()
                        let data = document.data()
                        if let dataMessageID = data["messageId"] as? String {
                            let matchKey = messageKeywordKey(
                                projectID: projectID,
                                roomID: room.id,
                                messageID: dataMessageID
                            )
                            messageKeywordFlags[matchKey] = nil
                        }
                    }
                } catch {
                    errorMessage = "키워드 정리에 실패했습니다: \(error.localizedDescription)"
                    return
                }
            }
        }

        if selectedProjectID == projectID {
            await loadKeywordMatches(for: projectID)
        }
    }

    private func setRoomArchive(_ room: RoomSummary, archived: Bool) async {
        let roomReference = database
            .collection("projects")
            .document(room.projectID)
            .collection("chatRooms")
            .document(room.id)

        do {
            try await roomReference.setData([
                "isArchived": archived,
                "updatedAt": FieldValue.serverTimestamp(),
                "archivedAt": archived ? FieldValue.serverTimestamp() : NSNull()
            ], merge: true)

            if archived && selectedProjectID == room.projectID && selectedRoomID == room.id {
                selectedRoomID = nil
            }

            bannerMessage = archived ? "채팅방이 보관 처리되었습니다." : "채팅방이 복구되었습니다."
            refreshKeywordMatches(for: selectedProjectID)
            if let projectID = selectedProjectID, rooms.isEmpty {
                refreshSelectedProjectRooms(projectID: projectID)
                reconcileSelectedRoom()
            }
        } catch {
            errorMessage = archived ? "채팅방 보관 처리에 실패했습니다: \(error.localizedDescription)" : "채팅방 복구에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func persistProjectKeywords(for project: ProjectSummary, keywords: [String]) async {
        let normalizedKeywords = Self.sanitizeKeywordList(keywords)
        let projectReference = database.collection("projects").document(project.id)

        do {
            try await projectReference.setData([
                "keywordList": normalizedKeywords,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                var updatedProject = project
                updatedProject.keywordTags = normalizedKeywords
                projects[index] = updatedProject
            }

            bannerMessage = "프로젝트 키워드 설정이 반영되었습니다."
        } catch {
            errorMessage = "키워드 저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private static func normalizeKeyword(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")

        if normalized.isEmpty {
            return ""
        }

        if !normalized.hasPrefix("#") {
            normalized = "#\(normalized)"
        }

        return normalized
    }

    static func sanitizeKeywordList(_ values: [String]) -> [String] {
        var unique: [String: String] = [:]

        for value in values {
            let normalized = normalizeKeyword(value)
            guard !normalized.isEmpty else { continue }
            unique[normalized.lowercased()] = normalized
        }

        return unique.values
            .sorted()
    }

    private static func keywordMatchDocumentID(messageID: String, keyword: String) -> String {
        "\(messageID)__\(normalizeKeyword(keyword).trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased())"
    }

    private func keywordStatusMessage(for error: Error) -> String {
        if let nsError = error as NSError? {
            if nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                return "주요키워드 보관함 권한이 아직 반영되지 않았습니다. Firestore 규칙을 적용한 뒤 다시 확인해 주세요."
            }

            if nsError.code == FirestoreErrorCode.failedPrecondition.rawValue {
                return "주요키워드 조회용 Firestore 인덱스가 아직 준비되지 않았습니다. 인덱스 생성 후 다시 시도해 주세요."
            }
        }

        return "주요키워드 보관함을 불러오지 못했습니다. \(error.localizedDescription)"
    }

    private func userReadStateCollection(for userID: String) -> CollectionReference {
        database
            .collection("users")
            .document(userID)
            .collection("projectChatRoomReads")
    }

    private func keywordMatchesCollection(projectID: String, roomID: String) -> CollectionReference {
        database
            .collection("projects")
            .document(projectID)
            .collection("chatRooms")
            .document(roomID)
            .collection("keywordMatches")
    }

    private func pinnedMessagesCollection(projectID: String, roomID: String) -> CollectionReference {
        database
            .collection("projects")
            .document(projectID)
            .collection("chatRooms")
            .document(roomID)
            .collection("pinnedMessages")
    }

    private func syncRoomSubscriptions() {
        let activeProjectIDs = Set(selectedProjectID.map { [$0] } ?? [])
        for (projectID, listener) in roomListenersByProjectID where !activeProjectIDs.contains(projectID) {
            listener.remove()
            roomListenersByProjectID[projectID] = nil
            allRoomsByProjectID[projectID] = nil
        }

        for projectID in activeProjectIDs where roomListenersByProjectID[projectID] == nil {
            subscribeRooms(for: projectID)
        }

        rebuildRoomCollections()
    }

    private func upsertProjectLocally(_ project: ProjectSummary) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.insert(project, at: 0)
        }
        projects.sort { $0.updatedAt > $1.updatedAt }
    }

    private func upsertRoomLocally(_ room: RoomSummary) {
        var roomsForProject = allRoomsByProjectID[room.projectID] ?? []
        if let index = roomsForProject.firstIndex(where: { $0.id == room.id }) {
            roomsForProject[index] = room
        } else {
            roomsForProject.insert(room, at: 0)
        }

        roomsForProject.sort { lhs, rhs in
            let leftDate = lhs.lastMessageAt ?? lhs.updatedAt
            let rightDate = rhs.lastMessageAt ?? rhs.updatedAt
            return leftDate > rightDate
        }

        allRoomsByProjectID[room.projectID] = roomsForProject
        rebuildRoomCollections()
    }

    private func rebuildRoomCollections() {
        allRooms = allRoomsByProjectID
            .values
            .flatMap { $0 }
            .sorted { lhs, rhs in
                let leftDate = lhs.lastMessageAt ?? lhs.updatedAt
                let rightDate = rhs.lastMessageAt ?? rhs.updatedAt
                return leftDate > rightDate
            }

        reconcileSelectedProject()

        refreshSelectedProjectRooms(projectID: selectedProjectID)
        reconcileSelectedRoom()
        prepareRoomMemberSelection()
        refreshKeywordMatches(for: selectedProjectID)
    }

    private func refreshSelectedProjectRooms(projectID: String?) {
        guard let projectID else {
            rooms = []
            return
        }

        rooms = allRooms
            .filter { $0.projectID == projectID }
            .sorted { lhs, rhs in
                let leftDate = lhs.lastMessageAt ?? lhs.updatedAt
                let rightDate = rhs.lastMessageAt ?? rhs.updatedAt
                return leftDate > rightDate
            }
    }

    private func notifyForIncomingMessages(oldRooms: [RoomSummary], newRooms: [RoomSummary]) {
        guard isChatNotificationEnabled,
              let effectiveUserID = currentOrCachedUserID else {
            return
        }

        let oldRoomsByID = Dictionary(uniqueKeysWithValues: oldRooms.map { ($0.id, $0) })

        for room in newRooms {
            guard !room.isArchived else { continue }
            guard !room.lastMessageSenderID.isEmpty else { continue }
            guard room.lastMessageSenderID != effectiveUserID else { continue }
            guard !room.lastMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let didChange: Bool
            if let oldRoom = oldRoomsByID[room.id] {
                let oldDate = oldRoom.lastMessageAt ?? .distantPast
                let newDate = room.lastMessageAt ?? .distantPast
                didChange = newDate > oldDate
                    || oldRoom.lastMessageText != room.lastMessageText
                    || oldRoom.lastMessageSenderID != room.lastMessageSenderID
            } else {
                didChange = room.lastMessageAt != nil
            }

            guard didChange else { continue }

            let notificationKey = chatNotificationKey(for: room)
            guard !deliveredRoomNotificationKeys.contains(notificationKey) else { continue }
            deliveredRoomNotificationKeys.insert(notificationKey)

            if deliveredRoomNotificationKeys.count > 500 {
                deliveredRoomNotificationKeys.removeAll(keepingCapacity: true)
                deliveredRoomNotificationKeys.insert(notificationKey)
            }

            sendChatNotification(for: room)
        }
    }

    private func chatNotificationKey(for room: RoomSummary) -> String {
        let timestamp = room.lastMessageAt?.timeIntervalSince1970 ?? 0
        return "\(room.id)|\(room.lastMessageSenderID)|\(timestamp)|\(room.lastMessageText)"
    }

    private func sendChatNotification(for room: RoomSummary) {
        let content = UNMutableNotificationContent()
        content.title = room.name
        content.body = chatNotificationPreviewText(from: room.lastMessageText)

        let request = UNNotificationRequest(
            identifier: "project-chat-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)

        if isChatSoundEnabled {
            playChatSound(named: chatNotificationSoundName)
        }
    }

    private func chatNotificationPreviewText(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "새 메시지가 도착했습니다." }

        if trimmed.hasPrefix("[파일 첨부]") {
            let lines = trimmed.components(separatedBy: .newlines)
            if let fileNameLine = lines.first(where: { $0.hasPrefix("이름:") }) {
                let fileName = String(fileNameLine.dropFirst("이름:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !fileName.isEmpty {
                    return "파일 첨부: \(fileName)"
                }
            }
            return "파일 첨부 메시지가 도착했습니다."
        }

        return trimmed
    }

    private func playChatSound(named identifier: String) {
        guard let option = SoundOption.option(for: identifier) else {
            if let rawName = identifier.split(separator: ":").last {
                NSSound(named: NSSound.Name(String(rawName)))?.play()
            }
            return
        }

        switch option.source {
        case .system, .bundled:
            NSSound(named: NSSound.Name(option.name))?.play()
        }
    }

    private func requestNotificationPermissionIfNeeded() {
        guard isChatNotificationEnabled else {
            return
        }

        let hasBundleIdentifier = !(Bundle.main.bundleIdentifier ?? "").isEmpty
        let didFinishLaunching = NSApp.mainWindow != nil || NSApp.windows.isEmpty == false || NSApp.isActive
        guard hasBundleIdentifier, didFinishLaunching else {
            isWaitingForNotificationPermissionAfterLaunch = true
            return
        }

        isWaitingForNotificationPermissionAfterLaunch = false
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { _, _ in }
    }

    @objc private func handleAppDidFinishLaunchingNotification() {
        guard isWaitingForNotificationPermissionAfterLaunch else {
            return
        }

        requestNotificationPermissionIfNeeded()
    }

    private func normalizedChatSoundIdentifier(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "system:Pop"
        }

        if value.hasPrefix("system:") || value.hasPrefix("bundle:") || value.hasPrefix("file:") {
            return value
        }

        return "system:\(value)"
    }

    private func normalizedEmails(from rawValue: String) -> [String] {
        rawValue
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func resolveDirectoryMembers(for emails: [String]) async throws -> (members: [MemberSummary], unresolvedEmails: [String]) {
        var resolvedMembers: [MemberSummary] = []
        var unresolvedEmails: [String] = []

        for email in emails {
            let querySnapshot = try await database.collection("directoryUsers")
                .whereField("emailLowercased", isEqualTo: email)
                .limit(to: 1)
                .getDocuments()

            guard let document = querySnapshot.documents.first else {
                unresolvedEmails.append(email)
                continue
            }

            let data = document.data()
            resolvedMembers.append(
                MemberSummary(
                    id: document.documentID,
                    displayName: data["displayName"] as? String ?? email,
                    email: data["email"] as? String ?? email,
                    photoURLString: data["photoURL"] as? String ?? ""
                )
            )
        }

        return (resolvedMembers, unresolvedEmails)
    }
}
