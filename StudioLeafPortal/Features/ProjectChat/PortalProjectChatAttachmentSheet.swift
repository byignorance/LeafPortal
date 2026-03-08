import ImageIO
import SwiftUI

struct PortalProjectChatAttachmentSheet: View {
    @ObservedObject var archiveManager: PortalProjectArchiveManager
    @ObservedObject var chatManager: PortalProjectChatManager
    let archive: ProjectArchiveSummary
    let fileURL: URL
    @Binding var isShowing: Bool

    @State private var selectedFolderID: String?
    @State private var selectedProvider: ProjectStorageProvider = .googleDrive
    @State private var uploadWorkGroupName = ""
    @State private var uploadProjectCode = ""
    @State private var uploadRenameMode: ProjectUploadRenameMode = .keepOriginal
    @State private var uploadPresetCategory: ProjectUploadPresetCategory = .resource
    @State private var uploadPreset: ProjectUploadPreset = .assets
    @State private var uploadVersionMode: ProjectUploadVersionMode = .dateBased
    @State private var uploadDateFormat: ProjectUploadDateFormat = .mmdd
    @State private var uploadSequenceToken = "v01"
    @State private var uploadKeywords = ""
    @State private var uploadDescription = ""

    private var folders: [ProjectStorageFolder] {
        archive.storageFolders
            .filter { folder in
                switch folder.provider {
                case .googleDrive:
                    return archive.googleDriveRootFolderID != nil
                case .dropbox:
                    return archive.dropboxRootPath != nil
                }
            }
            .sorted { left, right in
                if left.sortOrder == right.sortOrder {
                    return left.provider.rawValue < right.provider.rawValue
                }
                return left.sortOrder < right.sortOrder
            }
    }

    private var isUploading: Bool {
        archiveManager.isUploadingGoogleDriveFile || archiveManager.isUploadingDropboxFile
    }

    private var overlayUploadingText: String {
        guard let folder = selectedFolder else {
            return "스토리지 업로드 중..."
        }
        if folder.provider == .googleDrive {
            return "Google Drive 업로드 중..."
        }
        return "Dropbox 업로드 중..."
    }

    private var currentUploadProgress: PortalProjectArchiveManager.UploadProgressState? {
        guard let folder = selectedFolder,
              archiveManager.uploadProgress?.provider == folder.provider else { return nil }
        return archiveManager.uploadProgress
    }

    private var selectedFolder: ProjectStorageFolder? {
        if let selectedFolderID {
            return folders.first(where: { $0.id == selectedFolderID })
        }
        return folders.first
    }

    private var availableProviders: [ProjectStorageProvider] {
        var providers: [ProjectStorageProvider] = []
        if folders.contains(where: { $0.provider == .googleDrive }) {
            providers.append(.googleDrive)
        }
        if folders.contains(where: { $0.provider == .dropbox }) {
            providers.append(.dropbox)
        }
        return providers
    }

    private var filteredFolders: [ProjectStorageFolder] {
        folders.filter { $0.provider == selectedProvider }
    }

    private var previewFileName: String {
        archiveManager.previewUploadFileName(
            originalFileURL: fileURL,
            renameMode: uploadRenameMode,
            projectCode: uploadProjectCode,
            preset: uploadRenameMode == .applyNamingRule ? uploadPreset : nil,
            versionMode: uploadVersionMode,
            dateFormat: uploadDateFormat,
            sequenceToken: uploadSequenceToken
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("파일 첨부")
                        .font(.system(size: 24, weight: .black))
                    Text("\(fileURL.lastPathComponent)을(를) 업로드할 폴더를 선택하세요.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.55))
                }

                Spacer()

                PortalSecondaryButton(title: "닫기") {
                    isShowing = false
                }
            }

            if let bannerMessage = archiveManager.bannerMessage, !bannerMessage.isEmpty {
                InlineAlert(text: bannerMessage)
            }

            if let errorMessage = archiveManager.errorMessage, !errorMessage.isEmpty {
                InlineAlert(text: errorMessage, isWarning: true)
            }

            PortalCard(padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("업로드 분류")
                        .font(.system(size: 13, weight: .bold))

                    HStack(spacing: 10) {
                        ForEach(availableProviders, id: \.self) { provider in
                            Button {
                                selectedProvider = provider
                                syncSelectionWithProvider()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: provider == .googleDrive ? "externaldrive.fill" : "shippingbox.fill")
                                    Text(provider.title)
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(selectedProvider == provider ? Color.white : Color.black.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedProvider == provider
                                              ? (provider == .googleDrive
                                                 ? Color(red: 0.23, green: 0.47, blue: 0.86)
                                                 : Color(red: 0.02, green: 0.45, blue: 0.87))
                                              : Color.black.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                            .clickableCursor()
                        }
                    }

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredFolders) { folder in
                                Button {
                                    selectedFolderID = folder.id
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: folder.provider == .googleDrive ? "externaldrive.fill" : "shippingbox.fill")
                                            .foregroundStyle(folder.provider == .googleDrive ? Color(red: 0.23, green: 0.47, blue: 0.86) : Color(red: 0.02, green: 0.45, blue: 0.87))
                                        Image(systemName: selectedFolderID == folder.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedFolderID == folder.id ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.black.opacity(0.35))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(folder.title)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.84))
                                            Text(folder.normalizedRelativePath)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Color.black.opacity(0.45))
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedFolderID == folder.id ? Color(red: 0.94, green: 0.97, blue: 0.99) : Color.black.opacity(0.03))
                                    )
                                }
                                .buttonStyle(.plain)
                                .clickableCursor()
                            }
                        }
                    }
                    .frame(maxHeight: 320)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("업로드 메타데이터 (선택)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.72))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("작업 묶음")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.6))
                            TextField("예: EP01, 교육자료, 인터뷰A", text: $uploadWorkGroupName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, weight: .medium))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("파일명 방식")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.6))
                            Picker("파일명 방식", selection: $uploadRenameMode) {
                                ForEach(ProjectUploadRenameMode.allCases, id: \.self) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if uploadRenameMode == .applyNamingRule {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("프로젝트 코드")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.black.opacity(0.6))
                                    TextField("예: HyundaiTutVideo", text: $uploadProjectCode)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11, weight: .medium))
                                }

                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Preset 분류")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.black.opacity(0.6))
                                        Picker("Preset 분류", selection: $uploadPresetCategory) {
                                            ForEach(ProjectUploadPresetCategory.allCases, id: \.self) { category in
                                                Text(category.title).tag(category)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Preset")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.black.opacity(0.6))
                                        Picker("Preset", selection: $uploadPreset) {
                                            ForEach(ProjectUploadPreset.defaults(for: uploadPresetCategory), id: \.self) { preset in
                                                Text(preset.title).tag(preset)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }

                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("버전 방식")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.black.opacity(0.6))
                                        Picker("버전 방식", selection: $uploadVersionMode) {
                                            ForEach(ProjectUploadVersionMode.allCases, id: \.self) { mode in
                                                Text(mode.title).tag(mode)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }

                                    if uploadVersionMode == .dateBased {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Date 형식")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Color.black.opacity(0.6))
                                            Picker("Date 형식", selection: $uploadDateFormat) {
                                                ForEach(ProjectUploadDateFormat.allCases, id: \.self) { format in
                                                    Text(format.title).tag(format)
                                                }
                                            }
                                            .pickerStyle(.segmented)
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Sequence")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Color.black.opacity(0.6))
                                            TextField("예: v01", text: $uploadSequenceToken)
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(size: 11, weight: .medium))
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("업로드 파일명 미리보기")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.black.opacity(0.6))
                                    Text(previewFileName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.74))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.black.opacity(0.03))
                                        )
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("키워드")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.6))
                            TextField("문서, 기획, 최종본", text: $uploadKeywords)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, weight: .medium))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("보조 설명")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.6))
                            TextField("추가 메모/검색용 텍스트", text: $uploadDescription)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
            }

            HStack {
                Text("선택 파일: \(fileURL.lastPathComponent)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
                Spacer()
                PortalSecondaryButton(
                    title: isUploading ? "업로드 중..." : "업로드 후 채팅에 링크 남기기",
                    disabled: selectedFolder == nil || isUploading
                ) {
                    Task {
                        await uploadAndSendMessage()
                    }
                }
            }
        }
        .overlay {
            if isUploading {
                ZStack {
                    Color.black.opacity(0.10)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView(value: currentUploadProgress?.fractionCompleted ?? 0, total: 1)
                            .progressViewStyle(.linear)
                            .frame(width: 220)
                        Text(currentUploadProgress?.fileName ?? overlayUploadingText)
                            .font(.system(size: 13, weight: .bold))
                        if let currentUploadProgress {
                            Text("\(currentUploadProgress.providerTitle) · \(currentUploadProgress.percentageText) · \(currentUploadProgress.byteCountText)")
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
        .frame(minWidth: 620, minHeight: 520)
        .onAppear {
            if availableProviders.contains(selectedProvider) == false,
               let firstProvider = availableProviders.first {
                selectedProvider = firstProvider
            }
            uploadProjectCode = archive.projectCode
            uploadRenameMode = archive.namingDefaults.renameMode
            uploadVersionMode = archive.namingDefaults.versionMode
            uploadDateFormat = archive.namingDefaults.dateFormat
            syncPresetSelection()
            syncSelectionWithProvider()
        }
        .onChange(of: uploadPresetCategory) { _, _ in
            syncPresetSelection()
        }
    }

    private func uploadAndSendMessage() async {
        guard let folder = selectedFolder else { return }
        var thumbnailReference = makeThumbnailDataURL(for: fileURL)

        let messageLines: [String]

        if folder.provider == .googleDrive {
            guard let result = await archiveManager.uploadFileToGoogleDrive(
                archive: archive,
                folder: folder,
                fileURL: fileURL,
                workGroupName: uploadWorkGroupName,
                renameMode: uploadRenameMode,
                projectCode: uploadProjectCode,
                preset: uploadRenameMode == .applyNamingRule ? uploadPreset : nil,
                versionMode: uploadVersionMode,
                dateFormat: uploadDateFormat,
                sequenceToken: uploadSequenceToken,
                metadataKeywords: uploadKeywords,
                supplementaryDescription: uploadDescription
            ) else {
                return
            }

            messageLines = makeMessageLines(
                folder: folder,
                fileName: result.fileName,
                mimeType: result.mimeType,
                fileID: result.fileID,
                openURL: result.webViewURLString
            )
            if thumbnailReference == nil {
                thumbnailReference = result.thumbnailLink
            }
        } else {
            guard let result = await archiveManager.uploadFileToDropbox(
                archive: archive,
                folder: folder,
                fileURL: fileURL,
                workGroupName: uploadWorkGroupName,
                renameMode: uploadRenameMode,
                projectCode: uploadProjectCode,
                preset: uploadRenameMode == .applyNamingRule ? uploadPreset : nil,
                versionMode: uploadVersionMode,
                dateFormat: uploadDateFormat,
                sequenceToken: uploadSequenceToken,
                metadataKeywords: uploadKeywords,
                supplementaryDescription: uploadDescription
            ) else {
                return
            }

            messageLines = makeMessageLines(
                folder: folder,
                fileName: result.fileName,
                mimeType: result.mimeType,
                fileID: result.fileID,
                openURL: result.webViewURLString
            )
        }
        var finalMessageLines = messageLines
        finalMessageLines.insert("스토리지: \(folder.provider.title)", at: 1)

        let workGroupText = uploadWorkGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let metadataKeywordText = uploadKeywords.trimmingCharacters(in: .whitespacesAndNewlines)
        let metadataDescriptionText = uploadDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !workGroupText.isEmpty {
            finalMessageLines.append("작업 묶음: \(workGroupText)")
        }
        if uploadRenameMode == .applyNamingRule,
           let uploadedNameLine = finalMessageLines.first(where: { $0.hasPrefix("이름: ") }) {
            let uploadedName = uploadedNameLine.replacingOccurrences(of: "이름: ", with: "")
            if uploadedName != fileURL.lastPathComponent {
                finalMessageLines.append("원본 이름: \(fileURL.lastPathComponent)")
            }
        }
        if !metadataKeywordText.isEmpty {
            finalMessageLines.append("키워드: \(metadataKeywordText)")
        }
        if !metadataDescriptionText.isEmpty {
            finalMessageLines.append("보조설명: \(metadataDescriptionText)")
        }
        if let thumbnailReference {
            finalMessageLines.append("썸네일: \(thumbnailReference)")
        }

        await chatManager.sendMessage(text: finalMessageLines.joined(separator: "\n"))
        self.isShowing = false
    }

    private func makeMessageLines(
        folder: ProjectStorageFolder,
        fileName: String,
        mimeType: String,
        fileID: String,
        openURL: String
    ) -> [String] {
        [
            "[파일 첨부]",
            "이름: \(fileName)",
            "분류: \(folder.title)",
            "타입: \(mimeType)",
            "파일ID: \(fileID)",
            "열기: \(openURL)"
        ]
    }

    private func makeThumbnailDataURL(for fileURL: URL) -> String? {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(
                imageSource,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 320,
                ] as CFDictionary
              ) else {
            return nil
        }

        let thumbnail = NSImage(cgImage: cgImage, size: .zero)
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.62]
              ) else {
            return nil
        }

        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }

    private func syncSelectionWithProvider() {
        if let selectedFolder, selectedFolder.provider == selectedProvider {
            return
        }
        selectedFolderID = filteredFolders.first?.id
    }

    private func syncPresetSelection() {
        let defaults = ProjectUploadPreset.defaults(for: uploadPresetCategory)
        if defaults.contains(uploadPreset) == false,
           let firstPreset = defaults.first {
            uploadPreset = firstPreset
        }
    }
}
