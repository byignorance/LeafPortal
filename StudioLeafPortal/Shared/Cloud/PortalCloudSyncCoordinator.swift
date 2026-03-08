import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class PortalCloudSyncCoordinator: ObservableObject {
    enum SyncState: Equatable {
        case idle
        case pendingChanges
        case syncing
        case synced(Date)
        case failed(String)
    }

    @Published private(set) var state: SyncState = .idle

    private let authManager: PortalAuthManager
    private let viewModel: PortalViewModel
    private let sleepManager: SleepGuardManager
    private let database = Firestore.firestore()
    private let autosyncInterval: TimeInterval = 60 * 5

    private var cancellables = Set<AnyCancellable>()
    private var settingsListener: ListenerRegistration?
    private var currentUserID: String?
    private var lastSyncedSnapshot: PortalCloudSettingsSnapshot?
    private var lastSuccessfulSyncDate: Date?
    private var isApplyingRemoteSnapshot = false
    private var autosyncTimer: Timer?
    private(set) var hasPendingLocalChanges = false

    init(
        authManager: PortalAuthManager,
        viewModel: PortalViewModel,
        sleepManager: SleepGuardManager
    ) {
        self.authManager = authManager
        self.viewModel = viewModel
        self.sleepManager = sleepManager

        authManager.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .sink { [weak self] userID in
                Task { @MainActor [weak self] in
                    await self?.handleAuthenticationChange(userID: userID)
                }
            }
            .store(in: &cancellables)

        Publishers.Merge(
            viewModel.objectWillChange.map { _ in () },
            sleepManager.objectWillChange.map { _ in () }
        )
        .debounce(for: .milliseconds(700), scheduler: DispatchQueue.main)
        .sink { [weak self] in
            self?.markLocalSnapshotDirtyIfNeeded()
        }
        .store(in: &cancellables)
    }

    deinit {
        settingsListener?.remove()
        autosyncTimer?.invalidate()
    }

    private func handleAuthenticationChange(userID: String?) async {
        settingsListener?.remove()
        settingsListener = nil
        autosyncTimer?.invalidate()
        autosyncTimer = nil
        currentUserID = userID
        lastSyncedSnapshot = nil
        lastSuccessfulSyncDate = nil
        isApplyingRemoteSnapshot = false
        hasPendingLocalChanges = false

        guard let userID else {
            state = .idle
            authManager.updateSyncStatus(state: .idle)
            return
        }

        state = .syncing
        authManager.updateSyncStatus(state: .syncing)
        startAutosyncTimer()

        let settingsReference = settingsDocumentReference(for: userID)
        settingsListener = settingsReference.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    let message = "클라우드 설정을 불러오지 못했습니다. \(error.localizedDescription)"
                    self.state = .failed(message)
                    self.authManager.updateSyncStatus(state: .failed(message))
                    return
                }

                guard let snapshot else { return }

                if let data = snapshot.data(), let remoteSnapshot = PortalCloudSettingsSnapshot(dictionary: data) {
                    self.apply(remoteSnapshot)
                } else if !snapshot.exists {
                    _ = await self.pushLocalSnapshotIfNeeded(force: true)
                }
            }
        }
    }

    private func apply(_ remoteSnapshot: PortalCloudSettingsSnapshot) {
        let currentSnapshot = makeLocalSnapshot()
        guard remoteSnapshot != currentSnapshot else {
            lastSyncedSnapshot = remoteSnapshot
            markSynced(at: Date())
            return
        }

        isApplyingRemoteSnapshot = true
        viewModel.applyCloudSettings(remoteSnapshot.portal)
        sleepManager.applyCloudSettings(remoteSnapshot.sleepGuard)
        isApplyingRemoteSnapshot = false

        lastSyncedSnapshot = remoteSnapshot
        markSynced(at: Date())
    }

    func syncPendingChangesBeforeTermination() async -> Bool {
        guard hasPendingLocalChanges else { return true }
        return await pushLocalSnapshotIfNeeded(force: true)
    }

    private func pushLocalSnapshotIfNeeded(force: Bool = false) async -> Bool {
        guard let currentUserID else { return true }
        guard !isApplyingRemoteSnapshot else { return false }

        let snapshot = makeLocalSnapshot()
        if !force, snapshot == lastSyncedSnapshot {
            hasPendingLocalChanges = false
            if let lastSuccessfulSyncDate {
                state = .synced(lastSuccessfulSyncDate)
                authManager.updateSyncStatus(state: .synced(lastSuccessfulSyncDate))
            }
            return true
        }

        state = .syncing
        authManager.updateSyncStatus(state: .syncing)

        var data = snapshot.firestoreData
        data["updatedAt"] = FieldValue.serverTimestamp()

        do {
            try await settingsDocumentReference(for: currentUserID).setData(data, merge: true)
            lastSyncedSnapshot = snapshot
            markSynced(at: Date())
            return true
        } catch {
            let message = "설정 저장에 실패했습니다. \(error.localizedDescription)"
            state = .failed(message)
            authManager.updateSyncStatus(state: .failed(message))
            hasPendingLocalChanges = true
            return false
        }
    }

    private func markLocalSnapshotDirtyIfNeeded() {
        guard currentUserID != nil else { return }
        guard !isApplyingRemoteSnapshot else { return }

        let snapshot = makeLocalSnapshot()
        let hasChanges = snapshot != lastSyncedSnapshot
        hasPendingLocalChanges = hasChanges

        if hasChanges {
            state = .pendingChanges
            authManager.updateSyncStatus(state: .pendingChanges)
        } else if let lastSuccessfulSyncDate {
            state = .synced(lastSuccessfulSyncDate)
            authManager.updateSyncStatus(state: .synced(lastSuccessfulSyncDate))
        }
    }

    private func markSynced(at date: Date) {
        hasPendingLocalChanges = false
        lastSuccessfulSyncDate = date
        state = .synced(date)
        authManager.updateSyncStatus(state: .synced(date))
    }

    private func startAutosyncTimer() {
        autosyncTimer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: autosyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.hasPendingLocalChanges else { return }
                _ = await self.pushLocalSnapshotIfNeeded()
            }
        }
        timer.tolerance = 30
        autosyncTimer = timer
    }

    private func makeLocalSnapshot() -> PortalCloudSettingsSnapshot {
        PortalCloudSettingsSnapshot(
            portal: viewModel.makeCloudSettings(),
            sleepGuard: sleepManager.makeCloudSettings()
        )
    }

    private func settingsDocumentReference(for userID: String) -> DocumentReference {
        database
            .collection("users")
            .document(userID)
            .collection("settings")
            .document("app")
    }
}
