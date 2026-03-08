import Foundation

enum PortalFeatureNaming {
    static let appDisplayName = "studioLEAF Portal"
    static let portalLabel = "LEAF PORTAL"
    static let projectHub = "Project Hub"
    static let teamMessenger = "Team Messenger"
    static let notionConnector = "Notion Connector"
    static let renderNotification = "Render Notification"
    static let wakeUpLeaf = "WakeUp Leaf"

    static let legacyNameNotes: [String: String] = [
        "Project Archive": projectHub,
        "프로젝트 아카이브": projectHub,
        "Project Chat": teamMessenger,
        "프로젝트 채팅": teamMessenger,
        "Notion Hub": notionConnector,
        "노션 보기": notionConnector
    ]
}
