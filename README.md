# studioLEAF Portal

macOS portal app for studio workflow utilities.

## Product Direction

- `studioLEAF Portal` is a portal app with multiple internal workflow tools.
- Local project and folder names currently use `StudioLeafPortal`.
- Canonical product naming rules live in `DEVELOPMENT_GUIDELINES.md` and `PORTAL_NAMING_POLICY_2026-03-08.md`.
- Current review notes live in `ARCHITECTURE_REVIEW_2026-03-07.md`.

## Current Tools

- `Render Notification`: monitor Premiere Pro or Adobe Media Encoder render outputs
- `WakeUp Leaf`: keep the Mac awake by timer, indefinite mode, or app lifecycle
- `Notion Connector`: project-oriented Notion views
- `Team Messenger`: project conversation workspace
- `Project Hub`: archive, storage, and linked resource workspace
- `Icon Management`: manage portal and tool icon selections

## Current Status

- The app direction is `portal app + internal tools`.
- Display terminology is standardized.
- New development should follow canonical display names and keep internal identifiers stable unless there is an explicit migration plan.

## Project Structure

- `StudioLeafPortal.xcodeproj`
- `StudioLeafPortal/StudioLeafPortalApp.swift`
- `StudioLeafPortal/AppLifecycle.swift`
- `StudioLeafPortal/Portal/PortalRootView.swift`
- `StudioLeafPortal/Portal/PortalCoreModels.swift`
- `StudioLeafPortal/PortalViewModel.swift`
- `StudioLeafPortal/Features/RenderNotification/RenderNotificationModels.swift`
- `StudioLeafPortal/Features/RenderNotification/RenderNotificationMonitorEngine.swift`
- `StudioLeafPortal/Features/SleepGuard/SleepGuardManager.swift`
- `StudioLeafPortal/Features/NotionHub/NotionHubViewModel.swift`
- `StudioLeafPortal/Features/ProjectChat/PortalProjectChatSection.swift`
- `StudioLeafPortal/Features/IconManagement/PortalIconManagementSection.swift`
- `StudioLeafPortal/Features/IconManagement/PortalSymbolCatalog.swift`
- `StudioLeafPortal/Features/IconManagement/PortalLucideCatalog.swift`
- `DEVELOPMENT_GUIDELINES.md`
- `ARCHITECTURE_REVIEW_2026-03-07.md`
- `design_guideline.md`

## Run

1. Open `StudioLeafPortal.xcodeproj` in Xcode.
2. Select the `StudioLeafPortal` scheme.
3. Build and run on macOS 14.6 or newer.

## Notes

- `Simple` 모드는 5초 1차 알림, 15초 확정 알림 기준의 파일/폴더 감시를 사용합니다.
- `Advanced` 모드는 대상 프로그램 CPU 활동 기준으로 렌더 시작과 종료를 판단합니다.
- Process and Accessibility signals can be expanded further as secondary completion signals.
- File naming and source split policy live in `DEVELOPMENT_GUIDELINES.md`.
- Product naming policy lives in `PORTAL_NAMING_POLICY_2026-03-08.md`.
- Product structure and naming review notes live in `ARCHITECTURE_REVIEW_2026-03-07.md`.
- UI 작업 전에는 `design_guideline.md`를 먼저 참고합니다.

## Common UI/Structure Reference

- 리프포탈 공통 요소 정리: [COMMON_UI_ELEMENTS.md](COMMON_UI_ELEMENTS.md)
