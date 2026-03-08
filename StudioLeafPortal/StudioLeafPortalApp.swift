import SwiftUI
import FirebaseCore

@main
struct StudioLeafPortalApp: App {
    @State private var isWakeUpLeafMenuBarInserted = false
    @StateObject private var authManager: PortalAuthManager
    @StateObject private var cloudSyncCoordinator: PortalCloudSyncCoordinator
    @StateObject private var notionOAuthManager: NotionOAuthManager
    @StateObject private var notionHubViewModel: NotionHubViewModel
    @StateObject private var projectChatManager: PortalProjectChatManager
    @StateObject private var projectArchiveManager: PortalProjectArchiveManager
    @StateObject private var sleepManager: SleepGuardManager
    @StateObject private var viewModel: PortalViewModel
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var appLifecycle

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let authManager = PortalAuthManager()
        let viewModel = PortalViewModel()
        let sleepManager = SleepGuardManager()
        let notionOAuthManager = NotionOAuthManager()
        let notionHubViewModel = NotionHubViewModel(
            service: NotionHubServiceFactory.makeRuntimeService(oauthManager: notionOAuthManager),
            currentMemberName: authManager.currentUser?.displayName
        )
        let projectChatManager = PortalProjectChatManager(authManager: authManager)
        let projectArchiveManager = PortalProjectArchiveManager(
            authManager: authManager,
            projectChatManager: projectChatManager
        )
        let cloudSyncCoordinator = PortalCloudSyncCoordinator(
            authManager: authManager,
            viewModel: viewModel,
            sleepManager: sleepManager
        )
        _authManager = StateObject(wrappedValue: authManager)
        _cloudSyncCoordinator = StateObject(wrappedValue: cloudSyncCoordinator)
        _notionOAuthManager = StateObject(wrappedValue: notionOAuthManager)
        _notionHubViewModel = StateObject(wrappedValue: notionHubViewModel)
        _projectChatManager = StateObject(wrappedValue: projectChatManager)
        _projectArchiveManager = StateObject(wrappedValue: projectArchiveManager)
        _sleepManager = StateObject(wrappedValue: sleepManager)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some Scene {
        Window("studioLEAF Portal", id: "main") {
            PortalRootView(
                viewModel: viewModel,
                sleepManager: sleepManager,
                authManager: authManager,
                cloudSyncCoordinator: cloudSyncCoordinator,
                notionOAuthManager: notionOAuthManager,
                notionHubViewModel: notionHubViewModel,
                projectChatManager: projectChatManager,
                projectArchiveManager: projectArchiveManager
            )
                .onAppear {
                    appLifecycle.registerWindow()
                    appLifecycle.registerCloudSyncCoordinator(cloudSyncCoordinator)
                    isWakeUpLeafMenuBarInserted = sleepManager.isKeepingAwake
                }
                .onChange(of: sleepManager.isKeepingAwake) { _, isKeepingAwake in
                    isWakeUpLeafMenuBarInserted = isKeepingAwake
                }
                .onOpenURL { url in
                    authManager.handleRedirectURL(url)
                }
        }
        .defaultSize(width: 1180, height: 780)
        .windowResizability(.contentSize)

        MenuBarExtra(isInserted: $isWakeUpLeafMenuBarInserted) {
                SleepGuardMenuBarExtraContent(
                    manager: sleepManager,
                    openPortal: {
                        viewModel.selectedSection = .sleepGuard
                        appLifecycle.openMainWindow()
                    }
                )
        } label: {
                SleepGuardMenuBarLabel(manager: sleepManager)
        }
    }
}
