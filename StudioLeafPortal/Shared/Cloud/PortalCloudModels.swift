import Foundation

struct PortalCloudSettingsSnapshot: Equatable {
    var portal: PortalCloudPortalSettings
    var sleepGuard: PortalCloudSleepGuardSettings

    init(
        portal: PortalCloudPortalSettings = .defaults,
        sleepGuard: PortalCloudSleepGuardSettings = .defaults
    ) {
        self.portal = portal
        self.sleepGuard = sleepGuard
    }

    init?(dictionary: [String: Any]) {
        guard
            let portalDictionary = dictionary["portal"] as? [String: Any],
            let sleepGuardDictionary = dictionary["sleepGuard"] as? [String: Any],
            let portal = PortalCloudPortalSettings(dictionary: portalDictionary),
            let sleepGuard = PortalCloudSleepGuardSettings(dictionary: sleepGuardDictionary)
        else {
            return nil
        }

        self.portal = portal
        self.sleepGuard = sleepGuard
    }

    var firestoreData: [String: Any] {
        [
            "portal": portal.firestoreData,
            "sleepGuard": sleepGuard.firestoreData
        ]
    }
}

struct PortalCloudPortalSettings: Equatable {
    static let defaults = PortalCloudPortalSettings(
        watchMode: WatchMode.premiere.rawValue,
        detectionMode: DetectionMode.simple.rawValue,
        targetKind: MonitorTargetKind.folder.rawValue,
        targetApplicationName: WatchMode.premiere.defaultApplicationName,
        notificationEnabled: true,
        soundEnabled: true,
        preliminarySoundName: "system:Pop",
        completionSoundName: "bundle:RenderDone",
        messagesEnabled: false,
        messagesRecipient: "",
        messagesServiceMode: MessagesServiceMode.automatic.rawValue,
        messagesTemplate: "Render Notification: {target} 렌더 완료 ({time})",
        discordEnabled: false,
        webhookURLString: "",
        iconSelections: [:],
        recentTargetApplications: []
    )

    let watchMode: String
    let detectionMode: String
    let targetKind: String
    let targetApplicationName: String
    let notificationEnabled: Bool
    let soundEnabled: Bool
    let preliminarySoundName: String
    let completionSoundName: String
    let messagesEnabled: Bool
    let messagesRecipient: String
    let messagesServiceMode: String
    let messagesTemplate: String
    let discordEnabled: Bool
    let webhookURLString: String
    let iconSelections: [String: String]
    let recentTargetApplications: [String]

    init(
        watchMode: String,
        detectionMode: String,
        targetKind: String,
        targetApplicationName: String,
        notificationEnabled: Bool,
        soundEnabled: Bool,
        preliminarySoundName: String,
        completionSoundName: String,
        messagesEnabled: Bool,
        messagesRecipient: String,
        messagesServiceMode: String,
        messagesTemplate: String,
        discordEnabled: Bool,
        webhookURLString: String,
        iconSelections: [String: String],
        recentTargetApplications: [String]
    ) {
        self.watchMode = watchMode
        self.detectionMode = detectionMode
        self.targetKind = targetKind
        self.targetApplicationName = targetApplicationName
        self.notificationEnabled = notificationEnabled
        self.soundEnabled = soundEnabled
        self.preliminarySoundName = preliminarySoundName
        self.completionSoundName = completionSoundName
        self.messagesEnabled = messagesEnabled
        self.messagesRecipient = messagesRecipient
        self.messagesServiceMode = messagesServiceMode
        self.messagesTemplate = messagesTemplate
        self.discordEnabled = discordEnabled
        self.webhookURLString = webhookURLString
        self.iconSelections = iconSelections
        self.recentTargetApplications = recentTargetApplications
    }

    init?(dictionary: [String: Any]) {
        guard
            let watchMode = dictionary["watchMode"] as? String,
            let detectionMode = dictionary["detectionMode"] as? String,
            let targetKind = dictionary["targetKind"] as? String,
            let targetApplicationName = dictionary["targetApplicationName"] as? String,
            let notificationEnabled = dictionary["notificationEnabled"] as? Bool,
            let soundEnabled = dictionary["soundEnabled"] as? Bool,
            let preliminarySoundName = dictionary["preliminarySoundName"] as? String,
            let completionSoundName = dictionary["completionSoundName"] as? String,
            let messagesEnabled = dictionary["messagesEnabled"] as? Bool,
            let messagesRecipient = dictionary["messagesRecipient"] as? String,
            let messagesServiceMode = dictionary["messagesServiceMode"] as? String,
            let messagesTemplate = dictionary["messagesTemplate"] as? String,
            let discordEnabled = dictionary["discordEnabled"] as? Bool,
            let webhookURLString = dictionary["webhookURLString"] as? String,
            let iconSelections = dictionary["iconSelections"] as? [String: String],
            let recentTargetApplications = dictionary["recentTargetApplications"] as? [String]
        else {
            return nil
        }

        self.init(
            watchMode: watchMode,
            detectionMode: detectionMode,
            targetKind: targetKind,
            targetApplicationName: targetApplicationName,
            notificationEnabled: notificationEnabled,
            soundEnabled: soundEnabled,
            preliminarySoundName: preliminarySoundName,
            completionSoundName: completionSoundName,
            messagesEnabled: messagesEnabled,
            messagesRecipient: messagesRecipient,
            messagesServiceMode: messagesServiceMode,
            messagesTemplate: messagesTemplate,
            discordEnabled: discordEnabled,
            webhookURLString: webhookURLString,
            iconSelections: iconSelections,
            recentTargetApplications: recentTargetApplications
        )
    }

    var firestoreData: [String: Any] {
        [
            "watchMode": watchMode,
            "detectionMode": detectionMode,
            "targetKind": targetKind,
            "targetApplicationName": targetApplicationName,
            "notificationEnabled": notificationEnabled,
            "soundEnabled": soundEnabled,
            "preliminarySoundName": preliminarySoundName,
            "completionSoundName": completionSoundName,
            "messagesEnabled": messagesEnabled,
            "messagesRecipient": messagesRecipient,
            "messagesServiceMode": messagesServiceMode,
            "messagesTemplate": messagesTemplate,
            "discordEnabled": discordEnabled,
            "webhookURLString": webhookURLString,
            "iconSelections": iconSelections,
            "recentTargetApplications": recentTargetApplications
        ]
    }
}

struct PortalCloudSleepGuardSettings: Equatable {
    static let defaults = PortalCloudSleepGuardSettings(
        mode: SleepGuardManager.Mode.duration.rawValue,
        durationMinutes: 30,
        isNotificationEnabled: true,
        startSoundName: "bundle:countStart",
        stopSoundName: "bundle:countEnd"
    )

    let mode: String
    let durationMinutes: Int
    let isNotificationEnabled: Bool
    let startSoundName: String
    let stopSoundName: String

    init(
        mode: String,
        durationMinutes: Int,
        isNotificationEnabled: Bool,
        startSoundName: String,
        stopSoundName: String
    ) {
        self.mode = mode
        self.durationMinutes = durationMinutes
        self.isNotificationEnabled = isNotificationEnabled
        self.startSoundName = startSoundName
        self.stopSoundName = stopSoundName
    }

    init?(dictionary: [String: Any]) {
        guard
            let mode = dictionary["mode"] as? String,
            let durationMinutes = dictionary["durationMinutes"] as? Int,
            let isNotificationEnabled = dictionary["isNotificationEnabled"] as? Bool,
            let startSoundName = dictionary["startSoundName"] as? String,
            let stopSoundName = dictionary["stopSoundName"] as? String
        else {
            return nil
        }

        self.init(
            mode: mode,
            durationMinutes: durationMinutes,
            isNotificationEnabled: isNotificationEnabled,
            startSoundName: startSoundName,
            stopSoundName: stopSoundName
        )
    }

    var firestoreData: [String: Any] {
        [
            "mode": mode,
            "durationMinutes": durationMinutes,
            "isNotificationEnabled": isNotificationEnabled,
            "startSoundName": startSoundName,
            "stopSoundName": stopSoundName
        ]
    }
}
