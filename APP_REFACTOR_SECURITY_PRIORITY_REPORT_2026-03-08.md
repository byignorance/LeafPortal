# StudioLeafPortal Refactor / Security Priority Report

Date: 2026-03-08  
Target app folder: `/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal`

## Scope

This report consolidates current app-wide findings from:

- security and authorization structure
- Firestore rules alignment
- collaboration feature runtime cost and complexity
- large-file refactor pressure
- deployment/operations readiness

This is a static code and architecture review.
It is not a production profiling, penetration test, or live traffic audit.

## Executive Summary

Current priority is not new feature breadth.
Current priority is closing architecture drift introduced by recent feature expansion.

The highest-risk items are:

1. Firestore rules are behind current `Project Hub` data model changes.
2. Collaboration access still appears to depend on membership, not member state enforcement.
3. `Team Messenger` remains the main runtime and maintenance hotspot.
4. Admin privilege is still modeled as a hardcoded email, which is operationally weak.

If these are not addressed, the most likely outcomes are:

- save/update failures in `Project Hub`
- inconsistent collaboration access control
- rising Firestore cost and heavier chat behavior
- fragile admin operations during deployment and account changes

---

## `필수` Priority

### 1. Firestore rules drift against current `Project Hub` schema

Impact:

- high risk of write failures
- security model no longer matches app behavior
- recently added upload/grouping features can become partially broken

Evidence:

- [`firestore.rules`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/firestore.rules)
- `projectArchives` update rule only allows a fixed set of changed keys
- current app model now uses additional fields such as:
  - `projectCode`
  - `uploadNamingDefaults`
  - `savedWorkGroups`

Why this matters:

- `Project Hub` now depends on project-level upload naming and saved work-group state.
- If the rules do not allow these keys, the app can appear to work locally but fail when persisting.

Required action:

- update `projectArchives` rules to explicitly allow the current persisted schema
- review all recently added archive fields against rules before the next feature release
- treat rules update as part of the same change set whenever archive schema changes

Recommendation:

- make “model change -> rules change” a mandatory pair in future `Project Hub` work

### 2. Disabled / paused member states are not fully enforced for collaboration access

Impact:

- access control gap
- operational policy exists in UI/admin metadata but may not be enforced in the app/rules path

Evidence:

- [`PortalAuthManager.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Shared/Auth/PortalAuthManager.swift)
- [`firestore.rules`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/firestore.rules)

Observed issue:

- `directoryUsers` now carries member state metadata.
- collaboration access still appears to be driven mainly by sign-in and membership rules.
- there is no app-wide guarantee yet that `paused` or `disabled` members lose `Project Hub`, `Team Messenger`, and `Notion Connector` access.

Why this matters:

- once member management exists, non-enforced state becomes a false control surface
- operators will assume a disabled user is actually blocked

Required action:

- add app-level gating so `paused` / `disabled` users cannot enter collaboration sections
- align Firestore rules so sensitive collaboration collections also deny access when the member state is not active
- document the exact meaning of:
  - `active`
  - `paused`
  - `disabled`

### 3. `Team Messenger` remains the primary runtime/cost hotspot

Impact:

- highest runtime complexity in the app
- main source of Firestore read/write pressure
- main area where future bugs and regressions are most likely

Evidence:

- [`PortalProjectChatManager.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Shared/Chat/PortalProjectChatManager.swift)
- current size: `2694` lines
- earlier performance reviews already identified overlapping listener topology and read/write pressure
- related review: [`PERFORMANCE_COST_REVIEW_2026-03-07.md`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/PERFORMANCE_COST_REVIEW_2026-03-07.md)

Why this matters:

- view-layer splitting helped readability
- manager-layer complexity is still concentrated
- the app’s scalability profile is still defined by this subsystem

Required action:

- make `PortalProjectChatManager` the next major refactor target
- split responsibilities by domain, not by tiny helpers:
  - subscriptions/listeners
  - message send/edit/delete
  - read-state/unread
  - keyword highlight/index
  - permissions/session
- keep performance work tied to refactor work, not as a separate later pass

### 4. Admin control is still based on a hardcoded email

Impact:

- operational fragility
- weak admin identity model
- poor long-term deployment readiness

Evidence:

- [`PortalAuthManager.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Shared/Auth/PortalAuthManager.swift)
- [`firestore.rules`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/firestore.rules)
- current admin identity is tied to `hello@studioleaf.kr`

Why this matters:

- changing admin ownership, adding backup admins, or handling account migration becomes brittle
- client-visible email equality is not a strong admin model

Required action:

- move admin identity to a server-controlled source
- acceptable options:
  - Firebase custom claims
  - admin registry document only writable by trusted backend/admin process
- keep the email as a bootstrap fallback only if migration is phased

---

## `권장` Priority

### 5. `directoryUsers` sync hides failures with silent error swallowing

Impact:

- operations/debugging blind spot
- can leave membership/profile/admin state inconsistent without visibility

Evidence:

- [`PortalAuthManager.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Shared/Auth/PortalAuthManager.swift)
- `try? await directoryReference.setData(..., merge: true)`

Why this matters:

- this is the central bridge between Firebase auth and member directory state
- silent failure is acceptable for non-critical telemetry, not for access-related profile sync

Recommended action:

- replace silent swallow with explicit logging and recoverable UI/dev diagnostics
- at minimum, surface sync failure to local logs with enough context to investigate

### 6. `PortalRootView` is still too large for a shell-level file

Impact:

- onboarding/readability drag
- higher regression risk when navigation, settings, and global shell behavior change together

Evidence:

- [`PortalRootView.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Portal/PortalRootView.swift)
- current size: `1597` lines

Why this matters:

- shell files should primarily compose feature entry points
- this file still carries too much policy, settings, and section behavior

Recommended action:

- split by large responsibility units only:
  - settings/operations panels
  - collaboration access gating
  - dashboard shell behavior
  - footer/account shell

### 7. `Notion Connector` still has a sensitive architecture boundary

Impact:

- security/operations risk
- complexity around personal session vs fallback internal access

Evidence:

- [`NotionHubAdaptiveService.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Features/NotionHub/NotionHubAdaptiveService.swift)
- adaptive service can prefer personal OAuth token but still falls back to internal secret-backed configuration when present

Why this matters:

- current structure is pragmatic, but the boundary between:
  - user-specific access
  - internal fallback access
  is still sensitive and should remain explicit

Recommended action:

- formalize the supported access modes:
  - personal connection mode
  - internal service fallback mode
- document which screens/features may use fallback access
- long term, prefer a server-mediated model for sensitive shared access

### 8. Member management now exists, but operational semantics are still shallow

Impact:

- admin UI is ahead of policy
- state fields exist, but lifecycle and audit meaning are still underdefined

Evidence:

- member management UI and rules were recently added
- state fields now include member state and admin note

Recommended action:

- define operational semantics before adding more UI:
  - who can be paused
  - what disabled means for access and login
  - whether disabled users may still sign in to tool-only areas
- add audit logging before expanding more admin actions

---

## `선택` Priority

### 9. Further `Project Hub` upload complexity should pause until real use feedback

Impact:

- additional complexity without proof of need

Current state:

- multi-file sequential upload
- progress UI
- work-group storage
- retry and remaining-queue cancel
- grouped vs flat browser view

Relevant design docs:

- [`PROJECT_HUB_UPLOAD_DATA_MODEL_DESIGN_2026-03-08.md`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/PROJECT_HUB_UPLOAD_DATA_MODEL_DESIGN_2026-03-08.md)
- [`PROJECT_HUB_UPLOAD_UI_FLOW_DESIGN_2026-03-08.md`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/PROJECT_HUB_UPLOAD_UI_FLOW_DESIGN_2026-03-08.md)

Recommendation:

- do not rush into:
  - hard cancel for in-flight uploads
  - recursive grouped traversal
  - version history timeline
- wait for actual operator pain points

### 10. `Icon Management` static catalog size is large, but not the first optimization target

Impact:

- code volume and bundle weight pressure
- lower immediate operational risk than collaboration subsystems

Evidence:

- [`PortalSymbolCatalog.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Features/IconManagement/PortalSymbolCatalog.swift)
- current size: `7909` lines

Recommendation:

- only optimize here if startup or browsing behavior shows measurable cost
- otherwise treat this as a secondary cleanup target

---

## Large File Refactor Pressure

Current notable large files:

- [`PortalProjectChatManager.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Shared/Chat/PortalProjectChatManager.swift): `2694`
- [`PortalSymbolCatalog.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Features/IconManagement/PortalSymbolCatalog.swift): `7909`
- [`PortalRootView.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Portal/PortalRootView.swift): `1597`
- [`NotionHubService.swift`](/Users/sangjoonpark/0_local/main_work_macbook/0000_web_system/02_macOS/11_StudioLeafPortal/StudioLeafPortal/Features/NotionHub/NotionHubService.swift): `1057`

Practical order:

1. `PortalProjectChatManager`
2. `PortalRootView`
3. `NotionHubService`
4. `PortalSymbolCatalog` only if runtime evidence justifies it

Refactor rule:

- keep splitting by responsibility blocks
- do not create tiny files for cosmetic line-count reduction

---

## Security / Deployment Readiness Summary

Before wider deployment, the minimum bar should be:

1. archive rules aligned with current schema
2. member-state access enforcement active in app and rules
3. admin model moved off hardcoded email
4. collaboration access semantics documented
5. Notion access mode policy documented

Without these, deployment risk is less about raw crashes and more about:

- incorrect access behavior
- inconsistent operator assumptions
- difficult support/debugging

---

## Recommended Execution Order

### Phase A: Required stabilization

1. Fix `projectArchives` rule drift
2. Enforce `paused` / `disabled` states across collaboration access
3. Replace hardcoded-email admin control with a server-controlled model

### Phase B: Core refactor

1. Refactor `PortalProjectChatManager` by domain responsibilities
2. Reduce `PortalRootView` to shell composition and access policy
3. Clarify `Notion Connector` access modes and fallback boundaries

### Phase C: Optional follow-up

1. Add admin audit logging
2. Revisit `Project Hub` upload hard cancel/version history only after usage feedback
3. Optimize icon catalog only if measured runtime cost appears

---

## Bottom Line

The app is not currently blocked by bundle size or non-collaboration local tools.
The app is primarily at risk from:

- authorization drift
- rules drift
- collaboration subsystem complexity

The correct next move is stabilization and policy alignment, not another feature wave.
