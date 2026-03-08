# studioLEAF Portal Naming Policy

Date: 2026-03-08
Target app: `StudioLeafPortal`

## Purpose

This document fixes the naming boundary between:

- user-facing product names
- internal code identifiers
- persisted database/storage identifiers

The goal is to stop accidental feature edits caused by generic or historical names.

## Current Canonical Display Names

- App: `studioLEAF Portal`
- Collaboration:
  - `Project Hub`
  - `Team Messenger`
  - `Notion Connector`
- Tools:
  - `Render Notification`
  - `WakeUp Leaf`
- Shared:
  - `Overview`
  - `Activity`
  - `Settings`
  - `Icon Management`

## Stable Internal Identifiers

These may remain in code, Firestore, and file paths unless there is an explicit migration plan:

- `StudioLeafPortal`
- `projectArchives`
- `ProjectArchive`
- `ProjectChat`
- `NotionHub`
- `SleepGuard`

## Mapping

- `Project Archive` -> `Project Hub`
- `프로젝트 아카이브` -> `Project Hub`
- `Project Chat` -> `Team Messenger`
- `프로젝트 채팅` -> `Team Messenger`
- `Notion Hub` -> `Notion Connector`
- `노션 보기` -> `Notion Connector`

## Rules

1. UI, settings, docs, empty states, banners, and buttons must use canonical display names.
2. Firestore collection names and stable code identifiers do not get renamed unless a separate migration is approved.
3. New docs must use canonical display names when describing product behavior.
4. New code should prefer existing stable identifiers over inventing a third naming variant.
5. If a migration is required later, it must explicitly separate:
   - display rename
   - code rename
   - persisted data rename

## Immediate Guidance For Ongoing Work

- When discussing collaboration features in implementation threads:
  - say `Project Hub`
  - say `Team Messenger`
  - say `Notion Connector`
- When editing Firestore rules or old manager files, expect legacy identifiers like `projectArchives` and `NotionHub`.
