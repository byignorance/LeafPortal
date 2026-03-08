# Session Handoff

Date: 2026-03-08
App: `studioLEAF Portal`
Current target folder: `/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal`

## Purpose

This handoff is for the next Codex session after a local folder move or a fresh session restart.

If the app folder is moved before the next session:

- use the new absolute app path as the session target
- treat this document as still valid unless a newer handoff exists
- re-check absolute-path references in docs, scripts, automations, and manual build commands

This app should also be treated as fully separate from `NoSleepLeaf`.
Do not mix source history, repo assumptions, or feature work between the two apps even if they share earlier workspace history or related tool concepts.

## Current Status

- App maturity is near `1.0 baseline`
- local code is committed and first GitHub push is complete
- remote repository is `https://github.com/byignorance/LeafPortal.git`
- local folder name remains `StudioLeafPortal`, while product display naming has been standardized separately

## Recently Completed

### Product / naming / structure

- canonical display names standardized:
  - `Project Hub`
  - `Team Messenger`
  - `Notion Connector`
- naming policy documented and stabilized
- visible terminology was aligned while internal identifiers were intentionally kept stable where migration cost would be high

### Collaboration / security / access

- Firestore rules were updated and deployed
- collaboration access is now separated from raw sign-in state
- `active / paused / disabled` member states were introduced into actual collaboration gating
- `Project Hub`, `Team Messenger`, and `Notion Connector` are intended for active members only
- admin model was upgraded from pure hardcoded-email logic to:
  - bootstrap email fallback
  - `portalSettings/accessControl`
  - optional custom claim `portalAdmin`

### Operations

- `portalSettings/accessControl` bootstrap document was created in Firestore
- admin/member-state runbooks were documented

### Project Hub

- upload flow was expanded to:
  - multi-file sequential upload
  - per-file progress
  - work-group support
  - optional naming rules
  - retry failed items
  - cancel remaining queue
  - grouped vs flat file browser views

## Canonical Naming

### Display names

- App: `studioLEAF Portal`
- Collaboration:
  - `Project Hub`
  - `Team Messenger`
  - `Notion Connector`
- Tools:
  - `Render Notification`
  - `WakeUp Leaf`

### Stable internal identifiers kept on purpose

- `StudioLeafPortal`
- `projectArchives`
- `ProjectChat`
- `NotionHub`
- `SleepGuard`

Do not rename persisted/internal identifiers casually.
Display-name change and storage/code migration are separate operations.

## Priority Documents To Read First

1. `AGENTS.md`
2. `DEVELOPMENT_GUIDELINES.md`
3. `REPO_WORKFLOW.md`
4. this handoff file
5. `PORTAL_NAMING_POLICY_2026-03-08.md`
6. `APP_REFACTOR_SECURITY_PRIORITY_REPORT_2026-03-08.md`
7. `MEMBER_STATE_POLICY_2026-03-08.md`
8. `ADMIN_ACCESS_RUNBOOK_2026-03-08.md`
9. `ACCESS_CONTROL_BOOTSTRAP_2026-03-08.md`

## Security / Ops Notes

- Firestore rules are already deployed to project `studioleafportal`
- `portalSettings/accessControl` exists and currently bootstraps `hello@studioleaf.kr`
- `directoryUsers.memberState` now matters for collaboration access
- `paused` and `disabled` currently block collaboration features, not local tool usage
- Firebase CLI and gcloud credentials may need to be re-authenticated on another machine
- Notion web session is local-machine state and does not carry automatically

## Build / Run Notes

- recent Debug builds succeeded after the latest auth/rules/naming changes
- app still depends on local environment items such as:
  - Xcode
  - Google/Firebase CLI login for operational tasks
  - macOS permissions
  - Notion web login session for internal Notion pages

## Current Main Risks

1. `PortalProjectChatManager.swift` remains the largest runtime-complexity hotspot
2. `PortalRootView.swift` is still large for a shell file
3. admin/member policy is improved but still needs disciplined operational use
4. path moves may stale absolute-path references in docs and any future automations

## Recommended Next Work

### Required next if work resumes

1. verify moved-path references only if the local folder path changes
2. if another machine takes over, re-check:
   - `git status`
   - `git remote -v`
   - Firebase CLI login
   - gcloud login
   - first Debug build

### Recommended technical next steps

1. continue refactoring `PortalProjectChatManager.swift` by domain responsibility, not tiny helper files
2. reduce `PortalRootView.swift` further into shell-only composition
3. keep `Project Hub` upload scope stable unless real user feedback justifies another expansion

## Startup Rule For Next Session

Before any implementation work:

1. confirm the exact target app folder
2. read the priority documents above
3. summarize:
   - current app status
   - canonical naming
   - current priorities
   - security / ops constraints
   - path-move impact risk
4. only then continue coding

## Workspace Separation Reminder

- `StudioLeafPortal` and `NoSleepLeaf` are separate apps and separate repos
- do not treat `WakeUp Leaf` inside the portal as equivalent to the standalone `NoSleepLeaf` app
- do not move implementation files into the shared workspace root
- if local workspace cleanup is underway, keep app code inside app folders and move loose non-app files into explicit workspace-level folders only
- this app folder now includes its own startup and repo workflow documents so it can be copied and opened as a standalone target
