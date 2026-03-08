# StudioLeafPortal App Weight Review

Date: 2026-03-08
Target app: `StudioLeafPortal`

## Scope

This pass covers:

- actual Debug app bundle size
- feature-level loading and runtime weight
- codebase size and concentration
- practical bottleneck checklist
- `Team Messenger` specific heavy points

This is not an Instruments profiling run.
No startup time trace or runtime memory graph was captured in this pass.

## Build Result

- Xcode Debug build: `succeeded`
- Built app: `/tmp/StudioLeafPortalDerivedData/Build/Products/Debug/StudioLeafPortal.app`

Debug app size:

- `.app` total: `68MB`
- `Contents/MacOS`: `56MB`
- `Contents/Resources`: `12MB`
- `Contents/Frameworks`: `360KB`

Important interpretation:

- The current Debug build is not abnormally large for a macOS app with Firebase and collaboration features.
- Most of the Debug app size is the generated debug dylib, not raw asset bloat.
- Release size will likely be meaningfully smaller than this Debug figure.

Largest files inside the Debug app:

- `Contents/MacOS/StudioLeafPortal.debug.dylib`: `56MB`
- `Contents/Resources/LucideIcons_LucideIcons.bundle/Contents/Resources/Assets.car`: `9.3MB`
- `Contents/Resources/RenderDone.mp3`: `1.1MB`
- `Contents/Resources/Assets.car`: `768KB`

## Repository / Source Weight

Project folder size:

- whole project folder: `109MB`
- app source folder only: `3.9MB`
- Swift total: `33,059` lines

Important interpretation:

- Repository weight is currently dominated by `functions/node_modules`, not the macOS app sources.
- The app source itself is still relatively compact by disk size.
- Runtime complexity is coming more from real-time collaboration logic than raw asset size.

## Feature-Level Runtime Weight

### Low

- `Render Noti`
- `WakeUp Leaf`

These are mostly local-first and not structurally expensive.

### Medium

- `Project Hub`
- `Icon Management`

`Project Hub` has moderate runtime complexity from linked resources and storage setup logic.
`Icon Management` has large static catalogs, but that is more code/data weight than active runtime cost.

### Medium to High

- `Notion Connector`

Reasons:

- Notion API fetch chain
- linked item detail loading
- page detail rendering
- shared web session usage

### High

- `Team Messenger`

Reasons:

- multiple Firestore real-time listeners
- selected-room message stream
- pinned-message stream
- keyword highlight loading
- read-state updates
- notification permission and activity side effects

## Current Heaviest Code Areas

- `Shared/Chat/PortalProjectChatManager.swift`: `2735` lines
- `Features/IconManagement/PortalSymbolCatalog.swift`: `7909` lines
- `Portal/PortalRootView.swift`: `1597` lines
- `Features/ProjectArchive/PortalProjectArchiveManager.swift`: `1390` lines
- `Features/ProjectChat/PortalProjectChatSection.swift`: `1207` lines

Interpretation:

- `PortalSymbolCatalog.swift` is heavy in static data volume.
- `PortalProjectChatManager.swift` is the main runtime-complexity hotspot.
- `PortalRootView.swift` is still large for a shell-level file.

## Loading Bottleneck Checklist

### App startup

Check:

- Firebase initialization cost
- number of managers created at launch
- whether collaboration managers start listeners before the user enters the feature
- whether icon catalog data is loaded eagerly

Current concern:

- The app now carries multiple collaboration and session managers.
- Startup can degrade if collaboration-specific setup begins too early.

### Overview dashboard

Check:

- whether collaboration cards trigger network fetches while signed out
- whether Notion project summaries load too early
- whether Team Messenger summary data depends on active listeners

Current concern:

- Overview is lighter than before, but collaboration summaries should remain lazy.

### Project Hub

Check:

- initial list fetch
- template and external storage validation calls
- browser sheet loading for Google Drive / Dropbox

Current concern:

- moderate complexity, but not the first optimization target.

### Team Messenger

Check:

- how many active listeners exist after sign-in
- whether room listeners are scoped to one project or many
- selected room message page size
- keyword highlight query scope
- read-state write frequency

Current concern:

- this is the first optimization target in the whole app.

### Notion Connector

Check:

- first load after cache miss
- linked detail loading depth
- web session / web view transition cost
- fallback rendering when Notion page load fails

Current concern:

- user-perceived latency can spike on deep linked detail pages.

## Team Messenger Heavy Points

Observed structure from `PortalProjectChatManager.swift`:

1. Project subscription
- project list is loaded via a real-time listener

2. Joined-room subscription
- a `collectionGroup("chatRooms")` listener is used for all joined rooms

3. Per-project room subscription
- an additional room listener is opened per project

4. Selected room message subscription
- selected room messages are loaded through a real-time listener with page limit

5. Pinned message subscription
- selected room pinned messages are loaded through a separate real-time listener

6. Keyword highlight loading
- keyword matches are fetched with a collection-group query and then filtered again in memory

7. Read-state writes
- read-state tracking still happens in reaction to message consumption

Practical interpretation:

- Team Messenger is no longer oversized as a view file, but it is still the heaviest runtime subsystem.
- The cost comes from overlapping real-time subscriptions and secondary metadata fetches.

## Main Weight Drivers

### Runtime

1. `Team Messenger` Firestore listener topology
2. `Notion Connector` detail and web-session loading
3. `Project Hub` external storage integration steps

### Disk / bundle

1. Debug dylib size
2. Lucide icon asset bundle
3. audio resources

### Code maintenance

1. `PortalProjectChatManager.swift`
2. `PortalRootView.swift`
3. large icon catalog files

## Recommended Next Steps

### Highest priority

1. Review `Team Messenger` listener topology and reduce overlap
2. Confirm collaboration managers are not doing unnecessary work before feature entry
3. Keep `Notion Connector` on web-view-first detail loading with lazy fallback only when needed

### Second priority

1. Split `PortalRootView.swift` further by large functional sections
2. Consider lazy-loading or generated lookup access for icon catalogs
3. Reduce oversized audio/image assets if bundle size becomes a delivery concern

## Bottom Line

- The app is not currently large as a packaged macOS app.
- The app is moderately heavy in runtime structure because of collaboration features.
- `Team Messenger` is still the main place where performance and cost risk concentrate.
- If optimization work starts now, the first target should be collaboration listener/load behavior, not raw asset trimming.
