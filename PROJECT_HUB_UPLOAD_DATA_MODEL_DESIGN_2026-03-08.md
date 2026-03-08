# Project Hub Upload Data Model Design

Date: 2026-03-08
Target app: `StudioLeafPortal`
Scope: developer-facing design for `Project Hub` upload naming, work-group, and queue expansion

## Goal

Expand Project Hub uploads from:

- single file
- single folder target
- raw filename passthrough

to:

- optional naming policy
- work-group based path organization
- multi-file sequential queue
- reusable metadata for later Team Messenger integration

This document defines the data model only.

## Design Principles

1. Default upload behavior keeps the original filename.
2. Rename is opt-in per upload.
3. Folder structure remains the primary organizational system.
4. Metadata supplements search, traceability, and later automation.
5. Naming policy is project-scoped, not global-only.
6. The same naming model should be reusable by both Project Hub and Team Messenger attachment upload.

## Naming Policy Scope

Project-level configuration is the source of defaults.

Upload-level input is allowed to override defaults for a specific upload job.

Examples:

- project code defaults to `HyundaiTutVideo`
- upload can choose `original`
- upload can choose `renamed`
- upload can choose `Date Based` with `MMDD`

## New Project-Level Model Fields

Add these fields to `ProjectArchiveSummary` and `ProjectArchiveDraft`.

### projectCode

Type:

- `String?`

Purpose:

- short project identifier used in generated filenames

Examples:

- `HyundaiTutVideo`
- `StudioIntro2026`

Constraints:

- empty allowed
- trimmed
- ASCII-friendly recommended

### uploadNamingDefaults

Type:

- `ProjectUploadNamingDefaults`

Purpose:

- store the default behavior used to seed upload UI

## New Supporting Models

### ProjectUploadRenameMode

Type:

- enum

Cases:

- `keepOriginal`
- `applyNamingRule`

Default:

- `keepOriginal`

### ProjectUploadVersionMode

Type:

- enum

Cases:

- `dateBased`
- `sequenceBased`

Default:

- `dateBased`

### ProjectUploadDateFormat

Type:

- enum

Cases:

- `mmdd`
- `yymmdd`

Default:

- `mmdd`

Examples:

- `0301`
- `260301`

### ProjectUploadPresetCategory

Type:

- enum

Cases:

- `edit`
- `resource`

Purpose:

- separate edit-output presets from reference/resource presets

### ProjectUploadPreset

Type:

- struct

Fields:

- `id: String`
- `category: ProjectUploadPresetCategory`
- `title: String`
- `token: String`
- `sortOrder: Int`
- `isDefault: Bool`

Purpose:

- defines naming token choices shown in upload UI

Initial edit presets:

- `AssemblyCut`
- `RoughCut`
- `FineCut`
- `MasterCut`
- `FinalMaster`

Initial resource presets:

- `Brief`
- `ContextDocs`
- `References`
- `Assets`

Note:

- title and token can initially be the same string
- later they may diverge if localized display differs from file token

### ProjectUploadNamingDefaults

Type:

- struct

Fields:

- `renameMode: ProjectUploadRenameMode`
- `versionMode: ProjectUploadVersionMode`
- `dateFormat: ProjectUploadDateFormat`
- `selectedEditPresetToken: String?`
- `selectedResourcePresetToken: String?`
- `preserveOriginalFileNameInMetadata: Bool`

Default:

- rename mode: `keepOriginal`
- version mode: `dateBased`
- date format: `mmdd`
- preserve original filename in metadata: `true`

### ProjectUploadWorkGroup

Type:

- struct

Fields:

- `id: String`
- `folderId: String`
- `name: String`
- `normalizedPathComponent: String`
- `createdAt: Date?`
- `updatedAt: Date?`

Purpose:

- reusable upload subfolder under a storage folder

Examples:

- `EP01`
- `InterviewA`
- `교육자료`

Initial implementation note:

- phase 1 may use ad hoc work-group input only
- persistence can be added in phase 2 or 3

### ProjectUploadQueueItem

Type:

- struct

Fields:

- `id: String`
- `provider: ProjectStorageProvider`
- `archiveId: String`
- `folderId: String`
- `folderTitle: String`
- `workGroupName: String?`
- `sourceFileURL: URL`
- `sourceFileName: String`
- `targetFileName: String`
- `mimeType: String`
- `renameMode: ProjectUploadRenameMode`
- `presetToken: String?`
- `versionMode: ProjectUploadVersionMode?`
- `dateFormat: ProjectUploadDateFormat?`
- `versionToken: String?`
- `keywords: String`
- `description: String`
- `status: ProjectUploadQueueStatus`
- `progressFraction: Double`
- `bytesSent: Int64`
- `totalBytes: Int64`
- `errorMessage: String?`

Purpose:

- state holder for queued and in-flight uploads

### ProjectUploadQueueStatus

Type:

- enum

Cases:

- `queued`
- `uploading`
- `completed`
- `failed`
- `cancelled`

## Metadata to Persist With Uploaded File

Even when original filename is kept, metadata should preserve naming context.

Recommended stored metadata:

- `originalFileName`
- `uploadedFileName`
- `renameRuleApplied`
- `projectCode`
- `presetToken`
- `workGroupName`
- `versionMode`
- `dateFormat`
- `versionToken`
- `keywords`
- `description`
- `uploadedAt`
- `uploadedBy`

Purpose:

- search
- traceability
- future grouping
- later Team Messenger reuse

## Path Resolution Rules

Final upload path is resolved as:

- `base storage folder relative path`
- plus optional `workGroupName`

Examples:

- `exports`
- `exports/EP01`
- `references/교육자료`

File naming is resolved separately from folder path.

## Filename Resolution Rules

### Mode A: keepOriginal

Target filename:

- source filename unchanged

Stored metadata:

- original and uploaded filename are both preserved

### Mode B: applyNamingRule

Filename is generated from:

- `preset token`
- `project code`
- `version token`

Recommended initial templates:

- edit outputs: `{preset}_{projectCode}_{token}`
- resource files: `{projectCode}_{preset}_{token}`

Examples:

- `AssemblyCut_HyundaiTutVideo_0301.mp4`
- `HyundaiTutVideo_Brief_260103.pdf`

## Version Token Rules

### dateBased

Allowed formats:

- `MMDD`
- `YYMMDD`

Default:

- `MMDD`

### sequenceBased

Initial format:

- `v01`
- `v02`
- `v03`

Initial implementation note:

- sequence can be manual first
- automatic increment can come later

## Archive Persistence Changes

Add to stored Project Hub archive payload:

- `projectCode`
- `uploadNamingDefaults`
- optionally later: saved work groups and custom presets

Do not require queue items to persist in Firestore in the first implementation.
Queue state can remain local UI state initially.

## Phase Mapping

### Phase 0

- documents only

### Phase 1

- `projectCode`
- `uploadNamingDefaults`
- upload-time rename selection
- upload-time work-group input
- preview filename
- target filename application

### Phase 2

- `ProjectUploadQueueItem`
- multi-file sequential queue
- per-file progress state

### Phase 3

- reusable saved work groups
- saved/custom presets
- Team Messenger attachment adoption

## Non-Goals For First Pass

- full file version history UI
- automatic duplicate resolution across cloud listings
- deep storage-side metadata indexing
- Team Messenger full queue parity
- server-side preset enforcement

## Bottom Line

The model should support:

- default original filename uploads
- optional rename-on-upload
- project-scoped naming defaults
- work-group folder organization
- queue-ready upload state

without forcing premature persistence for every upload-state detail.
