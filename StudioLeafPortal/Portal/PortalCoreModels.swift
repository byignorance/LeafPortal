import Foundation

struct ActivityLogEntry: Identifiable {
    enum Kind {
        case success
        case warning
        case error

        var title: String {
            switch self {
            case .success: return "완료"
            case .warning: return "주의"
            case .error: return "오류"
            }
        }
    }

    let id = UUID()
    let title: String
    let detail: String
    let timestamp: Date
    let kind: Kind
}

enum PortalSection: String, CaseIterable, Identifiable {
    case overview = "대시보드"
    case projectChat = "Team Messenger"
    case projectArchive = "Project Hub"
    case notionHub = "Notion Connector"
    case renderNoti = "Render Notification"
    case sleepGuard = "WakeUp Leaf"
    case activity = "활동 로그"
    case settings = "설정"
    case iconManagement = "아이콘 관리"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .projectChat: return "bubble.left.and.bubble.right.fill"
        case .projectArchive: return "archivebox"
        case .notionHub: return "books.vertical.fill"
        case .renderNoti: return "sparkles.tv.fill"
        case .sleepGuard: return "moon.stars.fill"
        case .activity: return "list.bullet.rectangle"
        case .settings: return "gearshape.fill"
        case .iconManagement: return "paintpalette.fill"
        }
    }
}

struct IconOption: Identifiable, Hashable {
    let symbol: String
    let title: String

    var id: String { symbol }
}

struct SoundOption: Identifiable, Hashable {
    enum Source: Hashable {
        case system
        case bundled(extension: String)
    }

    let id: String
    let name: String
    let title: String
    let source: Source

    static let localFilePrefix = "file:"

    static let systemOptions: [SoundOption] = [
        .init(id: "system:Basso", name: "Basso", title: "Basso", source: .system),
        .init(id: "system:Blow", name: "Blow", title: "Blow", source: .system),
        .init(id: "system:Bottle", name: "Bottle", title: "Bottle", source: .system),
        .init(id: "system:Frog", name: "Frog", title: "Frog", source: .system),
        .init(id: "system:Funk", name: "Funk", title: "Funk", source: .system),
        .init(id: "system:Glass", name: "Glass", title: "Glass", source: .system),
        .init(id: "system:Hero", name: "Hero", title: "Hero", source: .system),
        .init(id: "system:Morse", name: "Morse", title: "Morse", source: .system),
        .init(id: "system:Ping", name: "Ping", title: "Ping", source: .system),
        .init(id: "system:Pop", name: "Pop", title: "Pop", source: .system),
        .init(id: "system:Purr", name: "Purr", title: "Purr", source: .system),
        .init(id: "system:Sosumi", name: "Sosumi", title: "Sosumi", source: .system),
        .init(id: "system:Submarine", name: "Submarine", title: "Submarine", source: .system),
        .init(id: "system:Tink", name: "Tink", title: "Tink", source: .system)
    ]

    static let bundledCompletionOptions: [SoundOption] = [
        .init(id: "bundle:RenderDone", name: "RenderDone", title: "RenderDone", source: .bundled(extension: "mp3"))
    ]

    static let wakeUpLeafBundledOptions: [SoundOption] = [
        .init(id: "bundle:countStart", name: "countStart", title: "countStart", source: .bundled(extension: "mp3")),
        .init(id: "bundle:countEnd", name: "countEnd", title: "countEnd", source: .bundled(extension: "mp3"))
    ]

    static let completionOptions: [SoundOption] = bundledCompletionOptions + systemOptions
    static let wakeUpLeafStartOptions: [SoundOption] = [
        .init(id: "bundle:countStart", name: "countStart", title: "countStart", source: .bundled(extension: "mp3"))
    ] + systemOptions
    static let wakeUpLeafStopOptions: [SoundOption] = [
        .init(id: "bundle:countEnd", name: "countEnd", title: "countEnd", source: .bundled(extension: "mp3"))
    ] + systemOptions

    static var allOptions: [SoundOption] {
        var seen = Set<String>()
        return (systemOptions + bundledCompletionOptions + wakeUpLeafBundledOptions).filter {
            seen.insert($0.id).inserted
        }
    }

    static func option(for identifier: String) -> SoundOption? {
        allOptions.first { $0.id == identifier }
    }

    static func localFileIdentifier(for url: URL) -> String {
        localFilePrefix + url.path
    }

    static func localFileURL(from identifier: String) -> URL? {
        guard identifier.hasPrefix(localFilePrefix) else {
            return nil
        }

        let path = String(identifier.dropFirst(localFilePrefix.count))
        guard !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    static func title(for identifier: String, options: [SoundOption]) -> String {
        if let option = options.first(where: { $0.id == identifier }) ?? option(for: identifier) {
            return option.title
        }

        if let url = localFileURL(from: identifier) {
            return url.lastPathComponent
        }

        if identifier.hasPrefix("system:") {
            return String(identifier.dropFirst("system:".count))
        }

        if identifier.hasPrefix("bundle:") {
            return String(identifier.dropFirst("bundle:".count))
        }

        return identifier
    }
}

struct CustomIconAsset: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let path: String

    var fileURL: URL { URL(fileURLWithPath: path) }
}

enum MessagesServiceMode: String, CaseIterable, Identifiable {
    case automatic = "자동"
    case iMessagePreferred = "iMessage 우선"
    case smsIfAvailable = "SMS 가능 시 사용"

    var id: String { rawValue }
}

enum IconSelection: Equatable {
    case system(String)
    case custom(UUID)
    case lucide(String)
}

enum PortalIconRole: String, CaseIterable, Identifiable {
    enum Category {
        case portal
        case tool

        var title: String {
            switch self {
            case .portal:
                return "공통 포털 아이콘"
            case .tool:
                return "기능 도구 아이콘"
            }
        }
    }

    case sidebarOverview
    case sidebarProjectChat
    case sidebarProjectArchive
    case sidebarNotionHub
    case sidebarRenderNoti
    case sidebarSleepGuard
    case sidebarActivity
    case sidebarSettings
    case sidebarIconManagement
    case sessionBanner
    case renderCard
    case pickerBrowse
    case journeys
    case webhook

    var id: String { rawValue }

    var category: Category {
        switch self {
        case .sidebarOverview, .sidebarProjectChat, .sidebarProjectArchive, .sidebarNotionHub, .sidebarActivity, .sidebarSettings, .sidebarIconManagement, .journeys:
            return .portal
        case .sidebarRenderNoti, .sidebarSleepGuard, .sessionBanner, .renderCard, .pickerBrowse, .webhook:
            return .tool
        }
    }

    var title: String {
        switch self {
        case .sidebarOverview: return "앱 포털"
        case .sidebarProjectChat: return PortalFeatureNaming.teamMessenger
        case .sidebarProjectArchive: return PortalFeatureNaming.projectHub
        case .sidebarNotionHub: return PortalFeatureNaming.notionConnector
        case .sidebarRenderNoti: return "Render Notification"
        case .sidebarSleepGuard: return "WakeUp Leaf"
        case .sidebarActivity: return "활동 로그"
        case .sidebarSettings: return "환경설정"
        case .sidebarIconManagement: return "아이콘 관리"
        case .sessionBanner: return "세션 배너"
        case .renderCard: return "Render Notification 카드"
        case .pickerBrowse: return "경로 선택"
        case .journeys: return "최근 여정"
        case .webhook: return "서비스 타일"
        }
    }

    var subtitle: String {
        switch self {
        case .sidebarOverview: return "좌측 메뉴에서 앱 포털을 표시하는 아이콘"
        case .sidebarProjectChat: return "좌측 메뉴 \(PortalFeatureNaming.teamMessenger) 아이콘"
        case .sidebarProjectArchive: return "좌측 메뉴 \(PortalFeatureNaming.projectHub) 아이콘"
        case .sidebarNotionHub: return "좌측 메뉴 \(PortalFeatureNaming.notionConnector) 아이콘"
        case .sidebarRenderNoti: return "좌측 메뉴 Render Notification 아이콘"
        case .sidebarSleepGuard: return "좌측 메뉴 WakeUp Leaf 아이콘"
        case .sidebarActivity: return "좌측 메뉴 활동 로그 아이콘"
        case .sidebarSettings: return "좌측 메뉴 환경설정 아이콘"
        case .sidebarIconManagement: return "좌측 메뉴 아이콘 관리 아이콘"
        case .sessionBanner: return "상단 활성 세션 배너 아이콘"
        case .renderCard: return "Render Notification 메인 카드 아이콘"
        case .pickerBrowse: return "Finder 경로 선택 아이콘"
        case .journeys: return "최근 여정 카드 제목 아이콘"
        case .webhook: return "연동/서비스 타일 기본 아이콘"
        }
    }

    var defaultSymbol: String {
        switch self {
        case .sidebarOverview: return "circle.hexagongrid.fill"
        case .sidebarProjectChat: return "bubble.left.and.bubble.right.fill"
        case .sidebarProjectArchive: return "archivebox"
        case .sidebarNotionHub: return "books.vertical.fill"
        case .sidebarRenderNoti: return "leaf.circle"
        case .sidebarSleepGuard: return "moon.stars.fill"
        case .sidebarActivity: return "book.pages"
        case .sidebarSettings: return "slider.horizontal.3"
        case .sidebarIconManagement: return "paintpalette"
        case .sessionBanner: return "gearshape.fill"
        case .renderCard: return "play.circle.fill"
        case .pickerBrowse: return "folder.fill"
        case .journeys: return "book.closed.fill"
        case .webhook: return "paperplane"
        }
    }

    var options: [IconOption] {
        switch self {
        case .sidebarOverview:
            return [
                .init(symbol: "circle.hexagongrid.fill", title: "포털 격자"),
                .init(symbol: "square.grid.2x2.fill", title: "기본 격자"),
                .init(symbol: "rectangle.grid.2x2", title: "라인 격자"),
                .init(symbol: "house", title: "홈")
            ]
        case .sidebarProjectChat:
            return [
                .init(symbol: "bubble.left.and.bubble.right.fill", title: "대화"),
                .init(symbol: "message.fill", title: "메시지"),
                .init(symbol: "person.2.fill", title: "팀"),
                .init(symbol: "rectangle.3.group.bubble.left.fill", title: "협업")
            ]
        case .sidebarProjectArchive:
            return [
                .init(symbol: "archivebox", title: "아카이브"),
                .init(symbol: "externaldrive", title: "파일 허브"),
                .init(symbol: "folder.fill", title: "프로젝트 폴더"),
                .init(symbol: "link", title: "바로가기")
            ]
        case .sidebarNotionHub:
            return [
                .init(symbol: "books.vertical.fill", title: "위키"),
                .init(symbol: "doc.text.image.fill", title: "문서 허브"),
                .init(symbol: "square.stack.3d.up.fill", title: "데이터 보기"),
                .init(symbol: "list.bullet.clipboard.fill", title: "프로젝트 보드")
            ]
        case .sidebarRenderNoti:
            return [
                .init(symbol: "leaf.circle", title: "리프 서클"),
                .init(symbol: "sparkles.tv", title: "렌더 알림"),
                .init(symbol: "bell.badge", title: "알림"),
                .init(symbol: "viewfinder.circle", title: "감시")
            ]
        case .sidebarSleepGuard:
            return [
                .init(symbol: "moon.stars.fill", title: "문 스타"),
                .init(symbol: "figure.walk", title: "산책"),
                .init(symbol: "power.circle", title: "전원 서클"),
                .init(symbol: "bed.double.fill", title: "베드")
            ]
        case .sidebarActivity:
            return [
                .init(symbol: "book.pages", title: "페이지"),
                .init(symbol: "list.bullet.rectangle", title: "리스트"),
                .init(symbol: "clock.arrow.circlepath", title: "히스토리"),
                .init(symbol: "text.line.first.and.arrowtriangle.forward", title: "로그")
            ]
        case .sidebarSettings:
            return [
                .init(symbol: "slider.horizontal.3", title: "슬라이더"),
                .init(symbol: "gearshape", title: "기어"),
                .init(symbol: "switch.2", title: "토글"),
                .init(symbol: "dial.low", title: "다이얼")
            ]
        case .sidebarIconManagement:
            return [
                .init(symbol: "paintpalette", title: "팔레트"),
                .init(symbol: "swatchpalette", title: "스와치"),
                .init(symbol: "square.grid.3x3.topleft.filled", title: "자산"),
                .init(symbol: "wand.and.stars", title: "스타일")
            ]
        case .sessionBanner:
            return [
                .init(symbol: "gearshape.fill", title: "기어"),
                .init(symbol: "waveform.path.ecg", title: "신호"),
                .init(symbol: "eye.fill", title: "감시"),
                .init(symbol: "bolt.horizontal.circle.fill", title: "엔진")
            ]
        case .renderCard:
            return [
                .init(symbol: "play.circle.fill", title: "재생"),
                .init(symbol: "sparkles.rectangle.stack.fill", title: "렌더"),
                .init(symbol: "bell.circle.fill", title: "알림"),
                .init(symbol: "record.circle.fill", title: "세션")
            ]
        case .pickerBrowse:
            return [
                .init(symbol: "folder.fill", title: "폴더"),
                .init(symbol: "folder.badge.plus", title: "폴더 추가"),
                .init(symbol: "arrow.up.right.square", title: "열기"),
                .init(symbol: "magnifyingglass", title: "탐색")
            ]
        case .journeys:
            return [
                .init(symbol: "book.closed.fill", title: "북"),
                .init(symbol: "clock.arrow.circlepath", title: "최근"),
                .init(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "흐름"),
                .init(symbol: "checklist", title: "체크리스트")
            ]
        case .webhook:
            return [
                .init(symbol: "paperplane", title: "전송"),
                .init(symbol: "paperplane.circle", title: "서클 전송"),
                .init(symbol: "network", title: "네트워크"),
                .init(symbol: "link", title: "링크")
            ]
        }
    }

    var lucideOptions: [String] {
        switch self {
        case .sidebarOverview:
            return ["layout-dashboard", "layout-grid", "app-window-mac", "panels-top-left"]
        case .sidebarProjectChat:
            return ["messages-square", "message-circle", "users-round", "blocks"]
        case .sidebarProjectArchive:
            return ["archive", "folder-open", "folder", "link-2"]
        case .sidebarNotionHub:
            return ["notebook-tabs", "book-open-text", "files", "kanban-square"]
        case .sidebarRenderNoti:
            return ["leaf", "monitor-play", "bell-ring", "tv-minimal-play"]
        case .sidebarSleepGuard:
            return ["moon-star", "footprints", "power", "bed-double"]
        case .sidebarActivity:
            return ["footprints", "history", "book-open", "clipboard-list"]
        case .sidebarSettings:
            return ["settings-2", "sliders-horizontal", "cog", "panel-left"]
        case .sidebarIconManagement:
            return ["palette", "swatch-book", "paintbrush", "wand-sparkles"]
        case .sessionBanner:
            return ["activity", "radar", "eye", "workflow"]
        case .renderCard:
            return ["play", "monitor-play", "sparkles", "tv-minimal-play"]
        case .pickerBrowse:
            return ["folder-open", "folder-search", "folder-output", "folder-plus"]
        case .journeys:
            return ["footprints", "book-open", "clock", "route"]
        case .webhook:
            return ["webhook", "send", "link", "network"]
        }
    }
}
