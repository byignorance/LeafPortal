# Repository Workflow

App: `studioLEAF Portal`
Current repo folder: `/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal`
Current remote: `https://github.com/byignorance/LeafPortal.git`

## Purpose

This file is the app-local Git/GitHub workflow reference for sessions where the app folder is opened without the shared workspace root.

## Core Rules

1. Treat this app folder as the only repository target.
2. Do not run Git commands from the shared workspace root for this app.
3. Do not mix this repository with `NoSleepLeaf`.
4. If the local folder path changes, update manual commands that include absolute paths before continuing.

## Minimum Git Checks At Session Start

1. `git status`
2. `git remote -v`
3. confirm the remote still points to `LeafPortal`
4. if a push is planned, check fetch state first

## Push / Sync Rules

1. Work inside this app folder only.
2. Commit only app-relevant files.
3. If the branch is dirty with unexpected files, stop and inspect before pushing.
4. If the app folder was copied to a new machine or new path, confirm the repository still has:
   - `.git`
   - correct `origin`
   - correct current branch

## New Session Reminder

Before implementation, read:

1. `AGENTS.md`
2. `DEVELOPMENT_GUIDELINES.md`
3. this file
4. latest `SESSION_HANDOFF_*.md`

Then summarize current app status and repo state before coding.
