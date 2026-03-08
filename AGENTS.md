# App Session Startup Rules

Target app folder:
- `/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal`

## Core Rule

This file applies to `StudioLeafPortal` only.
Do not treat the workspace root or another app folder as the target project.
Do not mix this app with `NoSleepLeaf` even when feature areas overlap.

Before any coding or file edits, confirm the exact current app folder path.
If the local folder has moved, use the new absolute path and do not rely on stale path references from older sessions.

## Required Startup Reads

At the start of every new session for this app, read these files first if they exist:

1. `AGENTS.md`
2. `DEVELOPMENT_GUIDELINES.md`
3. `REPO_WORKFLOW.md`
4. latest `SESSION_HANDOFF_*.md`
5. latest naming policy document
6. latest refactor / security priority report
7. latest member/admin operations policy documents

## Required Startup Behavior

Before implementation, summarize:

- current app status
- canonical naming
- current priorities
- known security / operations constraints
- path-move impact risk
- immediate next recommended actions

Then continue work.

## Naming Rule

Use canonical display names in UI, docs, and discussion.
Keep stable internal identifiers unchanged unless there is an explicit migration plan.

Current canonical collaboration display names:

- `Project Hub`
- `Team Messenger`
- `Notion Connector`

## Path-Move Rule

If this app folder has been moved:

1. treat the moved folder as the new canonical target
2. check docs, scripts, automations, and manual build commands for absolute-path assumptions
3. prefer updating path-sensitive guidance before starting feature work

## Workspace Cleanup Rule

If the broader `mac_apps` workspace is being reorganized:

1. keep `StudioLeafPortal` implementation files inside the app folder
2. keep `NoSleepLeaf` implementation files inside its own app folder
3. do not leave loose app source files in the shared workspace root
4. move loose non-app materials into explicit workspace-level folders such as:
   - docs
   - scripts
   - templates
   - archive
   - ops

## Standalone Copy Rule

This app folder is expected to remain usable even if it is copied away from the shared workspace.
Do not assume workspace-level policy files are available in a future session.
Use the app-local copies of startup, handoff, and repo workflow documents first.
