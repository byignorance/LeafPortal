import SwiftUI

enum ProjectStorageUploadQueueStatus: Equatable {
    case queued
    case uploading
    case completed
    case failed(String)
    case cancelled

    var title: String {
        switch self {
        case .queued:
            return "대기"
        case .uploading:
            return "업로드 중"
        case .completed:
            return "완료"
        case .failed:
            return "실패"
        case .cancelled:
            return "취소"
        }
    }
}

struct ProjectStorageUploadQueueRow: Identifiable, Equatable {
    let id: String
    let originalFileName: String
    let finalFileName: String
    var progress: Double
    var status: ProjectStorageUploadQueueStatus

    init(
        id: String = UUID().uuidString,
        originalFileName: String,
        finalFileName: String,
        progress: Double = 0,
        status: ProjectStorageUploadQueueStatus = .queued
    ) {
        self.id = id
        self.originalFileName = originalFileName
        self.finalFileName = finalFileName
        self.progress = progress
        self.status = status
    }
}

struct PortalProjectStorageUploadMetadataSheet: View {
    let providerTitle: String
    let folderTitle: String
    let selectedFiles: [String]
    let keywordsPlaceholder: String
    let previewFileName: String
    let uploadQueueRows: [ProjectStorageUploadQueueRow]
    let workGroupSuggestions: [String]
    @Binding var workGroupName: String
    @Binding var projectCode: String
    @Binding var renameMode: ProjectUploadRenameMode
    @Binding var presetCategory: ProjectUploadPresetCategory
    @Binding var selectedPreset: ProjectUploadPreset
    @Binding var versionMode: ProjectUploadVersionMode
    @Binding var dateFormat: ProjectUploadDateFormat
    @Binding var sequenceToken: String
    @Binding var keywords: String
    @Binding var description: String
    let isSubmitting: Bool
    let uploadProgress: PortalProjectArchiveManager.UploadProgressState?
    let onConfirm: () -> Void
    let onRetryFailed: () -> Void
    let onCancelUpload: () -> Void
    let onCancel: () -> Void

    private var filteredPresets: [ProjectUploadPreset] {
        ProjectUploadPreset.defaults(for: presetCategory)
    }

    private var primarySelectedFileName: String {
        selectedFiles.first ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("업로드 메타데이터")
                        .font(.system(size: 24, weight: .black))
                    Text("\(providerTitle) '\(folderTitle)' 폴더에 업로드할 옵션을 설정합니다.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.55))
                }

                Spacer()

                PortalSecondaryButton(title: "취소", disabled: isSubmitting) {
                    onCancel()
                }
            }

            PortalCard(padding: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    infoBlock(
                        title: selectedFiles.count > 1 ? "선택 파일 (\(selectedFiles.count)개)" : "선택 파일",
                        value: primarySelectedFileName
                    )

                    if selectedFiles.count > 1 {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(selectedFiles, id: \.self) { fileName in
                                    Text(fileName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.black.opacity(0.66))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.black.opacity(0.03))
                                        )
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("작업 묶음")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.62))
                        TextField("예: EP01, 교육자료, 인터뷰A", text: $workGroupName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .medium))

                        if !workGroupSuggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(workGroupSuggestions, id: \.self) { suggestion in
                                        Button {
                                            workGroupName = suggestion
                                        } label: {
                                            Text(suggestion)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(workGroupName == suggestion ? Color.white : Color.black.opacity(0.72))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(
                                                    Capsule()
                                                        .fill(workGroupName == suggestion
                                                              ? Color(red: 0.10, green: 0.18, blue: 0.14)
                                                              : Color.black.opacity(0.05))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .clickableCursor()
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("파일명 방식")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.62))
                        Picker("파일명 방식", selection: $renameMode) {
                            ForEach(ProjectUploadRenameMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if renameMode == .applyNamingRule {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("프로젝트 코드")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.62))
                                TextField("예: HyundaiTutVideo", text: $projectCode)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, weight: .medium))
                            }

                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Preset 분류")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.62))
                                    Picker("Preset 분류", selection: $presetCategory) {
                                        ForEach(ProjectUploadPresetCategory.allCases, id: \.self) { category in
                                            Text(category.title).tag(category)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Preset")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.62))
                                    Picker("Preset", selection: $selectedPreset) {
                                        ForEach(filteredPresets, id: \.self) { preset in
                                            Text(preset.title).tag(preset)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }

                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("버전 방식")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.62))
                                    Picker("버전 방식", selection: $versionMode) {
                                        ForEach(ProjectUploadVersionMode.allCases, id: \.self) { mode in
                                            Text(mode.title).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                if versionMode == .dateBased {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Date 형식")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.62))
                                        Picker("Date 형식", selection: $dateFormat) {
                                            ForEach(ProjectUploadDateFormat.allCases, id: \.self) { format in
                                                Text(format.title).tag(format)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Sequence")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.62))
                                        TextField("예: v01", text: $sequenceToken)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                }
                            }

                            infoBlock(title: "업로드 파일명 미리보기", value: previewFileName)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("키워드")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.62))
                        TextField(keywordsPlaceholder, text: $keywords)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .medium))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("보조 설명")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.62))
                        TextField("추가 메모/검색용 텍스트", text: $description)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, weight: .medium))
                    }

                    if !uploadQueueRows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("업로드 큐")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.72))

                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(uploadQueueRows) { row in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(row.finalFileName)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(Color.black.opacity(0.78))
                                                    .lineLimit(1)
                                                Spacer()
                                                Text(row.status.title)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(Color.black.opacity(0.48))
                                            }

                                            if row.originalFileName != row.finalFileName {
                                                Text("원본: \(row.originalFileName)")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(Color.black.opacity(0.48))
                                                    .lineLimit(1)
                                            }

                                            ProgressView(value: row.progress, total: 1)
                                                .progressViewStyle(.linear)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.black.opacity(0.03))
                                        )
                                    }
                                }
                            }
                            .frame(maxHeight: 180)
                        }
                    }

                    if let uploadProgress, isSubmitting {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(uploadProgress.providerTitle) 업로드 진행")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.7))
                                Spacer()
                                Text(uploadProgress.percentageText)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.72))
                            }

                            ProgressView(value: uploadProgress.fractionCompleted, total: 1)
                                .progressViewStyle(.linear)

                            Text(uploadProgress.byteCountText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.48))
                        }
                    }
                }
            }

            HStack {
                Spacer()

                if isSubmitting {
                    PortalSecondaryButton(title: "남은 업로드 취소") {
                        onCancelUpload()
                    }
                } else if uploadQueueRows.contains(where: {
                    if case .failed = $0.status { return true }
                    if case .cancelled = $0.status { return true }
                    return false
                }) {
                    PortalSecondaryButton(title: "실패 항목 재시도") {
                        onRetryFailed()
                    }
                }

                Button {
                    onConfirm()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isSubmitting ? "업로드 중..." : "업로드 시작")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSubmitting ? Color.black.opacity(0.3) : Color(red: 0.08, green: 0.25, blue: 0.17))
                )
                .foregroundStyle(.white)
                .disabled(isSubmitting)
                .clickableCursor(enabled: !isSubmitting)
            }
        }
        .padding(24)
        .frame(minWidth: 640)
        .onChange(of: presetCategory) { _, newValue in
            if !ProjectUploadPreset.defaults(for: newValue).contains(selectedPreset),
               let firstPreset = ProjectUploadPreset.defaults(for: newValue).first {
                selectedPreset = firstPreset
            }
        }
        .onChange(of: presetCategory) { _, category in
            let defaults = ProjectUploadPreset.defaults(for: category)
            if defaults.contains(selectedPreset) == false,
               let firstPreset = defaults.first {
                selectedPreset = firstPreset
            }
        }
    }

    private func infoBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.62))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.82))
                .textSelection(.enabled)
        }
    }
}
