# Project Hub Upload UI Flow Design

Date: 2026-03-08
Scope: developer-facing UI flow for Project Hub upload queue, work group, and naming policy

## 1. Goal

Project Hub upload UX should support:

- work-group based organization under a storage folder
- default original-filename upload
- optional naming-rule based rename
- multi-file sequential upload queue
- per-file and aggregate progress visibility
- later reuse in Team Messenger attachment upload

This document defines screen flow, state transitions, and phase-based rollout.

## 2. Core UI Principles

- Default path must remain fast: select folder, choose file, upload with original filename
- Naming policy UI must stay hidden unless the user explicitly opts into rename
- Work group selection should feel like an organizational aid, not a required taxonomy wall
- Multi-file upload should use queue semantics, not parallel complexity in the first release
- Upload preview must show the exact final path and filename before submission when rename is enabled

## 3. User Entry Points

### 3.1 Project Hub Storage Browser

Entry points:

- Google Drive browser sheet
- Dropbox browser sheet

From either browser, user can:

- browse existing folder contents
- upload file(s) into the current selected storage folder
- optionally place file(s) into a work group subfolder

### 3.2 Team Messenger Attachment Flow

Later phase reuse:

- Team Messenger attachment upload can reuse the same naming policy objects
- Initial behavior may stay simpler, but UI should align conceptually with Project Hub upload metadata flow

## 4. Phase 1 UI Flow

Phase 1 focuses on single-upload enhancement with naming policy and work group support.

### 4.1 Upload Metadata Sheet

Current upload metadata sheet expands with the following sections:

1. Destination
- selected storage folder summary
- work group selector
- new work group input

2. File naming
- naming mode picker
  - `원본 파일명 유지` default
  - `규칙 기반 파일명 적용`

3. Naming options (visible only when rename mode is enabled)
- project code field, prefilled from archive/project setting
- preset category
  - edit
  - resource
- preset picker
- version mode
  - date based
  - sequence based
- date format picker when version mode is date based
  - `MMDD` default
  - `YYMMDD`
- generated filename preview

4. Metadata
- keywords
- supplementary description
- original filename note shown as read-only reference when rename mode is enabled

### 4.2 Work Group UX

Work group behavior:

- if no work group is entered, upload targets the current folder root
- if a work group is entered or chosen, upload path becomes:
  - `{folder.normalizedRelativePath}/{workGroupName}`

Recommended interaction:

- freeform text field with recent/existing work group suggestions
- user can type a new work group without leaving the sheet

### 4.3 Rename UX

Default:

- user sees original filename and uploads as-is

If user switches to `규칙 기반 파일명 적용`:

- extra controls appear
- preview updates live as options change
- original filename remains visible in a secondary row

Preview format examples:

- edit preset:
  - `AssemblyCut_HyundaiTutVideo_0301.mp4`
- resource preset:
  - `HyundaiTutVideo_Brief_260103.pdf`

### 4.4 Validation Rules

Before upload:

- folder is required
- file is required
- if rename mode is enabled:
  - project code must be non-empty
  - preset must be selected
  - generated filename must be valid

Validation errors should stay inline in the sheet, not as modal alerts.

## 5. Phase 2 UI Flow

Phase 2 adds multi-file upload queue with sequential execution.

### 5.1 Multi-file Selection

File picker supports selecting multiple files in one action.

After selection:

- one upload metadata sheet is shown for shared options
- shared options apply to all selected files

Shared options:

- destination folder
- work group
- naming mode
- preset
- version mode
- date format
- keywords
- description

Per-file variation:

- original filename
- generated filename preview
- progress
- upload result

### 5.2 Queue Screen Behavior

Within the same sheet or attached panel, show:

- queue summary
  - total files
  - completed count
  - failed count
  - current active file
- per-file rows
  - original filename
  - final upload filename
  - status
  - progress bar

Statuses:

- queued
- uploading
- completed
- failed

### 5.3 Sequential Upload Execution

UI expectation:

- only one row is actively uploading at a time
- next row starts automatically after completion
- failures do not block already queued items unless failure policy says stop

Recommended first policy:

- continue queue even if one file fails
- failed items remain visible with retry later

## 6. Phase 3 UI Flow

Phase 3 adds reuse and management refinement.

### 6.1 Work Group Reuse

Enhance selector with:

- recent work groups for current folder
- search/filter in existing work groups
- explicit create-new affordance

### 6.2 Preset Reuse

Project-level preset defaults become visible in project settings and reusable in upload flow.

Expected UI:

- archive/project settings editor shows:
  - project code
  - edit presets
  - resource presets
  - naming defaults

### 6.3 Team Messenger Attachment Reuse

Team Messenger attachment upload should reuse:

- naming mode
- project code
- preset selection when upload destination is a Project Hub storage path

If Team Messenger flow is kept lighter, it should at least respect:

- default original filename
- optional rule-based rename
- same filename generator

## 7. Project Settings UI Additions

Project Hub project settings/editor should add:

- project code
- default rename mode
  - keep original
  - apply rule
- default version mode
  - date based
  - sequence based
- default date format
  - `MMDD`
  - `YYMMDD`
- editable preset lists
  - edit presets
  - resource presets

These settings serve as defaults for upload sheets, but the upload sheet may override them per upload.

## 8. Empty and Edge States

### 8.1 No Project Code

If rename mode is enabled but project code is empty:

- show inline warning
- disable submit

### 8.2 Invalid Generated Name

If generated filename contains invalid characters:

- sanitize automatically where possible
- show the final sanitized preview

### 8.3 Long Original Name

When rename mode is disabled:

- original name is uploaded untouched
- optionally truncate visually in the UI, but preserve real name

When rename mode is enabled:

- store original name in metadata
- preview only the generated upload name

## 9. Final UX Decisions Locked

- default upload mode: keep original filename
- rename mode: optional, user-selected
- date-based formats:
  - `MMDD`
  - `YYMMDD`
- default date format: `MMDD`
- initial edit presets:
  - `AssemblyCut`
  - `RoughCut`
  - `FineCut`
  - `MasterCut`
  - `FinalMaster`
- initial resource presets:
  - `Brief`
  - `ContextDocs`
  - `References`
  - `Assets`

## 10. Implementation Notes

- Phase 1 should avoid introducing multi-file complexity in the first UI patch
- Phase 2 should reuse the same metadata form model and expand it to queue semantics
- Phase 3 should reuse the same naming engine across Project Hub and Team Messenger instead of duplicating rename logic
