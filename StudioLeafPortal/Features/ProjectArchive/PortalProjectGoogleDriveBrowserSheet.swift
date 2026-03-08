import AppKit
import SwiftUI

private enum ProjectStorageListingMode: String, CaseIterable {
    case grouped
    case allFiles

    var title: String {
        switch self {
        case .grouped: return "작업 묶음별"
        case .allFiles: return "전체 파일"
        }
    }
}

struct PortalProjectGoogleDriveBrowserSheet: View {
    @ObservedObject var manager: PortalProjectArchiveManager
    let archive: ProjectArchiveSummary
    @Binding var isShowing: Bool

    @State private var selectedFolderID: String?
    @State private var currentListing: ProjectGoogleDriveFolderListing?
    @State private var isPerformingUpload = false
    @State private var folderItemCounts: [String: Int] = [:]
    @State private var isLoadingFolderCounts = false
    @State private var pendingUploadFileURLs: [URL] = []
    @State private var isShowingUploadMetadataSheet = false
    @State private var uploadQueueRows: [ProjectStorageUploadQueueRow] = []
    @State private var uploadWorkGroupName = ""
    @State private var uploadProjectCode = ""
    @State private var uploadRenameMode: ProjectUploadRenameMode = .keepOriginal
    @State private var uploadPresetCategory: ProjectUploadPresetCategory = .edit
    @State private var uploadPreset: ProjectUploadPreset = .assemblyCut
    @State private var uploadVersionMode: ProjectUploadVersionMode = .dateBased
    @State private var uploadDateFormat: ProjectUploadDateFormat = .mmdd
    @State private var uploadSequenceToken = "v01"
    @State private var uploadKeywords = ""
    @State private var uploadDescription = ""
    @State private var shouldCancelUploadQueue = false
    @State private var listingMode: ProjectStorageListingMode = .grouped

    private var visibleFolders: [ProjectStorageFolder] {
        manager.googleDriveVisibleFolders(for: archive)
    }

    private var selectedFolder: ProjectStorageFolder? {
        if let selectedFolderID {
            return visibleFolders.first(where: { $0.id == selectedFolderID })
        }
        return visibleFolders.first
    }

    private var currentUploadProgress: PortalProjectArchiveManager.UploadProgressState? {
        guard manager.uploadProgress?.provider == .googleDrive else { return nil }
        return manager.uploadProgress
    }

    private var previewFileName: String {
        guard let pendingUploadFileURL = pendingUploadFileURLs.first else { return "" }
        return manager.previewUploadFileName(
            originalFileURL: pendingUploadFileURL,
            renameMode: uploadRenameMode,
            projectCode: uploadProjectCode,
            preset: uploadRenameMode == .applyNamingRule ? uploadPreset : nil,
            versionMode: uploadVersionMode,
            dateFormat: uploadDateFormat,
            sequenceToken: uploadSequenceToken
        )
    }

    private var selectedFileNames: [String] {
        pendingUploadFileURLs.map(\.lastPathComponent)
    }

    private var workGroupSuggestions: [String] {
        let listingFolders = currentListing?.items.filter(\.isFolder).map(\.name) ?? []
        return Array(Set(archive.savedWorkGroups + listingFolders))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted()
    }

    private var groupedFolderItems: [ProjectGoogleDriveItem] {
        currentListing?.items.filter(\.isFolder) ?? []
    }

    private var looseFileItems: [ProjectGoogleDriveItem] {
        currentListing?.items.filter { !$0.isFolder } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(archive.projectName) Google Drive")
                        .font(.system(size: 26, weight: .black))
                    Text("프로젝트 허브 안에서 폴더별 파일 목록을 보고 업로드할 수 있습니다.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.55))
                }

                Spacer()

                if let rootURL = archive.googleDriveRootWebURL {
                    Link(destination: rootURL) {
                        Label("Drive에서 열기", systemImage: "arrow.up.right.square")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }

                PortalSecondaryButton(title: "닫기") {
                    isShowing = false
                }
            }

            if let bannerMessage = manager.bannerMessage, !bannerMessage.isEmpty {
                InlineAlert(text: bannerMessage)
            }

            if let errorMessage = manager.errorMessage, !errorMessage.isEmpty {
                InlineAlert(text: errorMessage, isWarning: true)
            }

            HStack(alignment: .top, spacing: 16) {
                PortalCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("폴더")
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            if isLoadingFolderCounts {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        ForEach(visibleFolders) { folder in
                            Button {
                                selectedFolderID = folder.id
                                Task {
                                    await loadListing(for: folder)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(Color(red: 0.23, green: 0.47, blue: 0.86))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.title)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.84))
                                        HStack(spacing: 6) {
                                            Text(folder.normalizedRelativePath)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Color.black.opacity(0.42))
                                                .lineLimit(2)
                                            if let count = folderItemCounts[folder.id] {
                                                Text("· \(count)개")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(Color.black.opacity(0.48))
                                            }
                                        }
                                    }
                                    Spacer(minLength: 8)
                                    if let folderURL = folderWebURL(for: folder) {
                                        Link(destination: folderURL) {
                                            Image(systemName: "arrow.up.right.square")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.45))
                                                .frame(width: 28, height: 28)
                                                .background(Color.black.opacity(0.04))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                        .clickableCursor()
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedFolderID == folder.id ? Color(red: 0.94, green: 0.97, blue: 0.99) : Color.black.opacity(0.03))
                                )
                            }
                            .buttonStyle(.plain)
                            .clickableCursor()
                        }
                    }
                }
                .frame(width: 240)

                PortalCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(currentListing?.folderTitle ?? selectedFolder?.title ?? "Google Drive")
                                        .font(.system(size: 16, weight: .bold))
                                    if let selectedFolder, let count = folderItemCounts[selectedFolder.id] {
                                        Text("\(count)개")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.45))
                                    }
                                }
                                Text(currentListing?.relativePath ?? selectedFolder?.normalizedRelativePath ?? "")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.45))
                            }

                            Spacer()

                            if let selectedFolder {
                                Button {
                                    Task {
                                        await refreshListing(for: selectedFolder)
                                    }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.55))
                                        .padding(8)
                                        .background(Color.black.opacity(0.04))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(manager.isLoadingGoogleDriveFolderContents || isPerformingUpload || manager.isUploadingGoogleDriveFile)
                                .opacity((manager.isLoadingGoogleDriveFolderContents || isPerformingUpload || manager.isUploadingGoogleDriveFile) ? 0.5 : 1)
                                .clickableCursor(enabled: !(manager.isLoadingGoogleDriveFolderContents || isPerformingUpload || manager.isUploadingGoogleDriveFile))
                            }

                            PortalSecondaryButton(
                                title: isPerformingUpload || manager.isUploadingGoogleDriveFile ? "업로드 중..." : "파일 업로드",
                                disabled: selectedFolder == nil || isPerformingUpload || manager.isUploadingGoogleDriveFile
                            ) {
                                Task {
                                    await selectAndUploadFile()
                                }
                            }
                        }

                        Picker("보기 방식", selection: $listingMode) {
                            ForEach(ProjectStorageListingMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let currentUploadProgress, (isPerformingUpload || manager.isUploadingGoogleDriveFile) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(currentUploadProgress.fileName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.72))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(currentUploadProgress.percentageText)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.62))
                                }

                                ProgressView(value: currentUploadProgress.fractionCompleted, total: 1)
                                    .progressViewStyle(.linear)

                                Text(currentUploadProgress.byteCountText)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.45))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.94, green: 0.97, blue: 0.99))
                            )
                        }

                        if manager.isLoadingGoogleDriveFolderContents {
                            VStack(spacing: 10) {
                                ProgressView()
                                Text("파일 목록을 불러오는 중입니다.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.vertical, 60)
                        } else if let listing = currentListing, listing.items.isEmpty {
                            VStack(spacing: 10) {
                                Text("아직 파일이 없습니다.")
                                    .font(.system(size: 15, weight: .bold))
                                Text("이 폴더에 파일을 업로드하면 여기에서 바로 확인할 수 있습니다.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.vertical, 60)
                        } else if let listing = currentListing {
                            if listingMode == .allFiles {
                                ScrollView {
                                    LazyVStack(spacing: 10) {
                                        ForEach(listing.items) { item in
                                            googleDriveItemRow(item)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            } else {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 16) {
                                        if !groupedFolderItems.isEmpty {
                                            listingSection(title: "작업 묶음") {
                                                ForEach(groupedFolderItems) { item in
                                                    googleDriveItemRow(item)
                                                }
                                            }
                                        }

                                        if !looseFileItems.isEmpty {
                                            listingSection(title: "루트 파일") {
                                                ForEach(looseFileItems) { item in
                                                    googleDriveItemRow(item)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                Text("폴더를 선택해 주세요.")
                                    .font(.system(size: 15, weight: .bold))
                                Text("왼쪽에서 프로젝트 폴더를 고르면 파일 목록을 불러옵니다.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.vertical, 60)
                        }
                    }
                }
            }
        }
        .overlay {
            if isPerformingUpload || manager.isUploadingGoogleDriveFile {
                ZStack {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView(value: currentUploadProgress?.fractionCompleted ?? 0, total: 1)
                            .progressViewStyle(.linear)
                            .frame(width: 220)
                        Text(currentUploadProgress?.fileName ?? "Google Drive 업로드 중입니다...")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.76))
                        if let currentUploadProgress {
                            Text("\(currentUploadProgress.percentageText) · \(currentUploadProgress.byteCountText)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    )
                }
            }
        }
        .padding(24)
        .frame(minWidth: 920, minHeight: 640)
        .sheet(isPresented: $isShowingUploadMetadataSheet, onDismiss: clearPendingUpload) {
            PortalProjectStorageUploadMetadataSheet(
                providerTitle: "Google Drive",
                folderTitle: selectedFolder?.title ?? "Google Drive",
                selectedFiles: selectedFileNames,
                keywordsPlaceholder: "문서, 기획, 최종본",
                previewFileName: previewFileName,
                uploadQueueRows: uploadQueueRows,
                workGroupSuggestions: workGroupSuggestions,
                workGroupName: $uploadWorkGroupName,
                projectCode: $uploadProjectCode,
                renameMode: $uploadRenameMode,
                presetCategory: $uploadPresetCategory,
                selectedPreset: $uploadPreset,
                versionMode: $uploadVersionMode,
                dateFormat: $uploadDateFormat,
                sequenceToken: $uploadSequenceToken,
                keywords: $uploadKeywords,
                description: $uploadDescription,
                isSubmitting: isPerformingUpload || manager.isUploadingGoogleDriveFile,
                uploadProgress: currentUploadProgress,
                onConfirm: {
                    Task {
                        await confirmPendingUpload()
                    }
                },
                onRetryFailed: {
                    Task {
                        await retryFailedUploads()
                    }
                },
                onCancelUpload: {
                    shouldCancelUploadQueue = true
                },
                onCancel: {
                    isShowingUploadMetadataSheet = false
                }
            )
        }
        .task {
            if selectedFolderID == nil {
                selectedFolderID = visibleFolders.first?.id
            }
            seedFolderCountsFromCache()
            await preloadFolderCounts()
            if let folder = selectedFolder {
                currentListing = manager.cachedGoogleDriveFolderListing(archive: archive, folder: folder)
                await loadListing(for: folder)
            }
        }
        .onChange(of: manager.uploadProgress) { _, progress in
            syncQueueProgress(progress)
        }
        .onChange(of: uploadWorkGroupName) { _, _ in
            refreshQueueRowsPreview()
        }
        .onChange(of: uploadProjectCode) { _, _ in
            refreshQueueRowsPreview()
        }
        .onChange(of: uploadRenameMode) { _, _ in
            refreshQueueRowsPreview()
        }
        .onChange(of: uploadPresetCategory) { _, category in
            let defaults = ProjectUploadPreset.defaults(for: category)
            if defaults.contains(uploadPreset) == false,
               let firstPreset = defaults.first {
                uploadPreset = firstPreset
            }
            refreshQueueRowsPreview()
        }
        .onChange(of: uploadPreset) { _, _ in
            refreshQueueRowsPreview()
        }
        .onChange(of: uploadVersionMode) { _, _ in
            refreshQueueRowsPreview()
        }
        .onChange(of: uploadDateFormat) { _, _ in
            refreshQueueRowsPreview()
        }
        .onChange(of: uploadSequenceToken) { _, _ in
            refreshQueueRowsPreview()
        }
    }

    @ViewBuilder
    private func googleDriveItemRow(_ item: ProjectGoogleDriveItem) -> some View {
        let destination = item.webViewURL

        if let destination {
            Link(destination: destination) {
                itemRowContent(item)
            }
            .buttonStyle(.plain)
        } else {
            itemRowContent(item)
        }
    }

    private func itemRowContent(_ item: ProjectGoogleDriveItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(item.isFolder ? Color(red: 0.23, green: 0.47, blue: 0.86) : Color.black.opacity(0.6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
                HStack(spacing: 8) {
                    Text(item.isFolder ? "폴더" : "파일")
                    if let sizeText = fileSizeText(for: item.sizeBytes) {
                        Text(sizeText)
                    }
                    if let modifiedText = modifiedAtText(for: item.modifiedAt) {
                        Text(modifiedText)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.45))
            }

            Spacer()

            if item.webViewURL != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.03))
        )
    }

    private func loadListing(for folder: ProjectStorageFolder) async {
        currentListing = await manager.loadGoogleDriveFolderListing(
            archive: archive,
            folder: folder
        )
        if let currentListing {
            folderItemCounts[folder.id] = currentListing.items.filter { !$0.isFolder }.count
        }
    }

    private func selectAndUploadFile() async {
        guard selectedFolder != nil else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        guard panel.runModal() == .OK, !panel.urls.isEmpty else {
            return
        }

        pendingUploadFileURLs = panel.urls
        uploadWorkGroupName = ""
        uploadProjectCode = archive.projectCode
        uploadRenameMode = archive.namingDefaults.renameMode
        uploadPresetCategory = .edit
        uploadPreset = .assemblyCut
        uploadVersionMode = archive.namingDefaults.versionMode
        uploadDateFormat = archive.namingDefaults.dateFormat
        uploadSequenceToken = "v01"
        uploadKeywords = ""
        uploadDescription = ""
        uploadQueueRows = buildQueueRows(for: panel.urls)
        isShowingUploadMetadataSheet = true
    }

    private func confirmPendingUpload() async {
        guard let folder = selectedFolder, !pendingUploadFileURLs.isEmpty else { return }

        isPerformingUpload = true
        shouldCancelUploadQueue = false
        defer { isPerformingUpload = false }

        var hasFailure = false
        for (index, fileURL) in pendingUploadFileURLs.enumerated() {
            if shouldCancelUploadQueue {
                markQueuedRowsCancelled(startingAfter: index - 1)
                hasFailure = true
                break
            }
            markQueueRowUploading(fileURL: fileURL)
            let result = await manager.uploadFileToGoogleDrive(
                archive: archive,
                folder: folder,
                fileURL: fileURL,
                workGroupName: uploadWorkGroupName,
                renameMode: uploadRenameMode,
                projectCode: uploadProjectCode,
                preset: uploadRenameMode == .applyNamingRule ? uploadPreset : nil,
                versionMode: uploadVersionMode,
                dateFormat: uploadDateFormat,
                sequenceToken: sequenceTokenForUpload(at: index),
                metadataKeywords: uploadKeywords,
                supplementaryDescription: uploadDescription
            )
            if result != nil {
                markQueueRowCompleted(fileURL: fileURL)
            } else {
                hasFailure = true
                markQueueRowFailed(fileURL: fileURL, message: manager.errorMessage ?? "업로드 실패")
            }
        }

        await loadListing(for: folder)
        folderItemCounts[folder.id] = currentListing?.items.filter { !$0.isFolder }.count ?? folderItemCounts[folder.id]

        if !hasFailure {
            isShowingUploadMetadataSheet = false
            clearPendingUpload()
        }
    }

    private func clearPendingUpload() {
        if !(isPerformingUpload || manager.isUploadingGoogleDriveFile) {
            pendingUploadFileURLs = []
            uploadQueueRows = []
            shouldCancelUploadQueue = false
            uploadWorkGroupName = ""
            uploadProjectCode = archive.projectCode
            uploadRenameMode = archive.namingDefaults.renameMode
            uploadPresetCategory = .edit
            uploadPreset = .assemblyCut
            uploadVersionMode = archive.namingDefaults.versionMode
            uploadDateFormat = archive.namingDefaults.dateFormat
            uploadSequenceToken = "v01"
            uploadKeywords = ""
            uploadDescription = ""
        }
    }

    private func buildQueueRows(for fileURLs: [URL]) -> [ProjectStorageUploadQueueRow] {
        fileURLs.enumerated().map { index, fileURL in
            ProjectStorageUploadQueueRow(
                originalFileName: fileURL.lastPathComponent,
                finalFileName: manager.previewUploadFileName(
                    originalFileURL: fileURL,
                    renameMode: uploadRenameMode,
                    projectCode: uploadProjectCode,
                    preset: uploadRenameMode == .applyNamingRule ? uploadPreset : nil,
                    versionMode: uploadVersionMode,
                    dateFormat: uploadDateFormat,
                    sequenceToken: sequenceTokenForUpload(at: index)
                )
            )
        }
    }

    private func refreshQueueRowsPreview() {
        guard !(isPerformingUpload || manager.isUploadingGoogleDriveFile) else { return }
        guard !pendingUploadFileURLs.isEmpty else {
            uploadQueueRows = []
            return
        }
        uploadQueueRows = buildQueueRows(for: pendingUploadFileURLs)
    }

    private func sequenceTokenForUpload(at index: Int) -> String {
        guard uploadVersionMode == .sequenceBased else { return uploadSequenceToken }
        let trimmed = uploadSequenceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = trimmed.prefix { !$0.isNumber }
        let reversedDigits = String(trimmed.reversed().prefix { $0.isNumber })
        let digits = String(reversedDigits.reversed())
        let baseNumber = Int(digits) ?? 1
        let width = max(digits.count, 2)
        return "\(prefix.isEmpty ? "v" : String(prefix))" + String(format: "%0\(width)d", baseNumber + index)
    }

    private func markQueueRowUploading(fileURL: URL) {
        updateQueueRow(fileURL: fileURL) { row in
            row.status = .uploading
            row.progress = 0
        }
    }

    private func markQueueRowCompleted(fileURL: URL) {
        updateQueueRow(fileURL: fileURL) { row in
            row.status = .completed
            row.progress = 1
        }
    }

    private func markQueueRowFailed(fileURL: URL, message: String) {
        updateQueueRow(fileURL: fileURL) { row in
            row.status = .failed(message)
        }
    }

    private func markQueuedRowsCancelled(startingAfter index: Int) {
        guard !uploadQueueRows.isEmpty else { return }
        let startIndex = max(index + 1, 0)
        guard startIndex < uploadQueueRows.count else { return }
        for rowIndex in startIndex..<uploadQueueRows.count {
            if case .queued = uploadQueueRows[rowIndex].status {
                uploadQueueRows[rowIndex].status = .cancelled
            }
        }
    }

    private func updateQueueRow(fileURL: URL, mutation: (inout ProjectStorageUploadQueueRow) -> Void) {
        guard let index = uploadQueueRows.firstIndex(where: { $0.originalFileName == fileURL.lastPathComponent }) else {
            return
        }
        var row = uploadQueueRows[index]
        mutation(&row)
        uploadQueueRows[index] = row
    }

    private func syncQueueProgress(_ progress: PortalProjectArchiveManager.UploadProgressState?) {
        guard let progress else { return }
        guard let index = uploadQueueRows.firstIndex(where: { $0.finalFileName == progress.fileName || $0.originalFileName == progress.fileName }) else {
            return
        }
        var row = uploadQueueRows[index]
        row.progress = progress.fractionCompleted
        row.status = .uploading
        uploadQueueRows[index] = row
    }

    private func refreshListing(for folder: ProjectStorageFolder) async {
        currentListing = await manager.loadGoogleDriveFolderListing(
            archive: archive,
            folder: folder,
            forceRefresh: true
        )
        if let currentListing {
            folderItemCounts[folder.id] = currentListing.items.filter { !$0.isFolder }.count
        }
    }

    private func retryFailedUploads() async {
        guard let folder = selectedFolder else { return }
        let retryURLs = pendingUploadFileURLs.filter { fileURL in
            guard let row = uploadQueueRows.first(where: { $0.originalFileName == fileURL.lastPathComponent }) else {
                return false
            }
            if case .failed = row.status { return true }
            if case .cancelled = row.status { return true }
            return false
        }
        guard !retryURLs.isEmpty else { return }

        isPerformingUpload = true
        shouldCancelUploadQueue = false
        defer { isPerformingUpload = false }

        for retryURL in retryURLs {
            updateQueueRow(fileURL: retryURL) { row in
                row.status = .queued
                row.progress = 0
            }
        }

        for (retryIndex, fileURL) in retryURLs.enumerated() {
            if shouldCancelUploadQueue {
                break
            }
            markQueueRowUploading(fileURL: fileURL)
            let originalIndex = pendingUploadFileURLs.firstIndex(of: fileURL) ?? retryIndex
            let result = await manager.uploadFileToGoogleDrive(
                archive: archive,
                folder: folder,
                fileURL: fileURL,
                workGroupName: uploadWorkGroupName,
                renameMode: uploadRenameMode,
                projectCode: uploadProjectCode,
                preset: uploadRenameMode == .applyNamingRule ? uploadPreset : nil,
                versionMode: uploadVersionMode,
                dateFormat: uploadDateFormat,
                sequenceToken: sequenceTokenForUpload(at: originalIndex),
                metadataKeywords: uploadKeywords,
                supplementaryDescription: uploadDescription
            )
            if result != nil {
                markQueueRowCompleted(fileURL: fileURL)
            } else {
                markQueueRowFailed(fileURL: fileURL, message: manager.errorMessage ?? "업로드 실패")
            }
        }

        await loadListing(for: folder)
    }

    @ViewBuilder
    private func listingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.48))
            content()
        }
    }

    private func seedFolderCountsFromCache() {
        for folder in visibleFolders {
            if let count = manager.cachedGoogleDriveFolderItemCount(archive: archive, folder: folder) {
                folderItemCounts[folder.id] = count
            }
        }
    }

    private func preloadFolderCounts() async {
        guard !visibleFolders.isEmpty else { return }

        isLoadingFolderCounts = true
        defer { isLoadingFolderCounts = false }

        for folder in visibleFolders {
            if folderItemCounts[folder.id] != nil {
                continue
            }
            if let count = await manager.loadGoogleDriveFolderItemCount(archive: archive, folder: folder) {
                folderItemCounts[folder.id] = count
            }
        }
    }

    private func fileSizeText(for sizeBytes: Int64?) -> String? {
        guard let sizeBytes, sizeBytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    private func modifiedAtText(for date: Date?) -> String? {
        guard let date else { return nil }
        return date.formatted(date: .numeric, time: .shortened)
    }

    private func folderWebURL(for folder: ProjectStorageFolder) -> URL? {
        if selectedFolderID == folder.id, let currentListing {
            return URL(string: "https://drive.google.com/drive/folders/\(currentListing.folderID)")
        }

        if let cachedListing = manager.cachedGoogleDriveFolderListing(archive: archive, folder: folder) {
            return URL(string: "https://drive.google.com/drive/folders/\(cachedListing.folderID)")
        }

        return archive.googleDriveRootWebURL
    }
}
