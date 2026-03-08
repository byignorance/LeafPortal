# StudioLeafPortal Performance / Cost Review

Date: 2026-03-07
Target app: `StudioLeafPortal` / `LeafPortal`

## Scope

This review focuses on:

- app heaviness by feature
- current optimization level
- Firestore / Notion usage patterns
- likely cost pressure areas
- practical next steps for the chat feature thread

This is a code-level review, not a runtime profiling report.
No Instruments, Firebase console metrics, or production traffic logs were used in this pass.

## Executive Summary

Current cost and performance risk is concentrated in `Project Chat`.

Feature-level risk:

- `Project Chat`: high
- `Notion Hub`: medium
- `Cloud settings sync`: low
- `Render Notification`: low
- `WakeUp Leaf`: low
- `Icon Management`: low
- `Activity`: low

Main conclusion:

- If the app gets heavier or more expensive, the first place to optimize is `Project Chat`.
- `Notion Hub` can feel heavy on first load or deep document navigation, but its cache design already reduces repeated load.
- Global settings sync is now light enough after moving to interval sync with termination confirmation.

## Overall App Heaviness

### 1. UI / local feature load

Most non-collaboration features are local-first and not structurally expensive:

- `Render Notification` is mainly local monitoring plus notification logic.
- `WakeUp Leaf` is mainly timer / system state logic.
- `Icon Management` is local asset selection and UI browsing.
- `Activity` is local UI state and log rendering.

These areas may have normal UI rendering cost, but they are not the main network or database pressure points.

### 2. Collaboration feature load

The app becomes meaningfully heavier when collaboration features are active:

- `Project Chat` opens multiple Firestore listeners and performs frequent reads/writes.
- `Notion Hub` performs multi-step API fetches and recursive block loading for linked detail content.

These are the two features that define the app's real scalability profile.

## Feature Review

### Project Chat

Risk level: `High`

Why it is heavy:

- The manager subscribes to the signed-in user's projects in real time.
- It then opens a room listener for each active project.
- It also opens message and pinned-message listeners for the selected room.
- Keyword highlight data is fetched room-by-room using additional queries.
- Read-state writes happen during message consumption.

Observed structural cost drivers:

- one real-time listener for project list
- one real-time listener per project for chat rooms
- one real-time listener for the selected room's messages
- one real-time listener for the selected room's pinned messages
- one real-time listener for user read-state documents
- additional on-demand `getDocuments()` for keyword matches

Write amplification:

Sending one message currently causes multiple writes:

- create message document
- update room document
- update project document timestamp
- create one or more keyword match documents if keywords are matched

Editing or deleting messages can also trigger keyword index cleanup and rebuild work.

Why this matters for cost:

- Firestore read cost scales with listener count and document change frequency.
- Firestore write cost scales with message volume and indexing side effects.
- As project count, room count, and message volume grow, the current model scales roughly in the wrong places.

Current optimization level:

- reasonable cleanup exists when auth state or selection changes
- listeners are removed when switching context
- unread write duplication is partially reduced by timestamp checks

But overall optimization maturity is still not high enough for scale.

Primary issues:

1. Room listeners are opened for every joined project, not just the currently selected project.
2. Selected room message stream loads the full ordered message collection, not a bounded window.
3. Keyword highlights are loaded by iterating rooms and querying each one separately.
4. Message send path performs more writes than necessary.
5. Read-state updates are immediate instead of batched or coalesced.

### Notion Hub

Risk level: `Medium`

Why it is heavy:

- Project list fetch hits the Notion project data source.
- Project detail fetch hits the project page plus three linked data sources:
  - `To-do`
  - `Document`
  - `Memo`
- Linked item detail loads page data plus recursive block children.

Where heaviness appears:

- first load after cache expiry
- force refresh
- opening long linked documents with deep nested blocks

Good existing optimization:

- cached service already exists
- TTL policy already reduces repeated requests
  - projects: 10 min
  - details: 15 min
  - linked item details: 20 min
- cache fallback is used when upstream fetch fails

Why this matters for cost:

- Notion is less about per-document billing than Firestore and more about latency, throughput, and API rate pressure.
- The current direct-client approach risks rate-limit and operational fragility more than raw dollar cost.

Main concerns:

1. Deep linked detail loads can become expensive in user-perceived latency.
2. Recursive block fetches scale with content depth.
3. Internal Notion secret is currently used in the client path, which is an operational/security concern.

### Cloud Settings Sync

Risk level: `Low`

Current state:

- one user-scoped settings document
- one settings snapshot listener
- local changes marked dirty
- interval sync every 5 minutes
- termination-time sync confirmation for unsynced changes

Why cost is low:

- narrow document scope
- low write frequency after interval sync change
- no large collection scans

This is not a significant cost risk compared with chat or Notion.

## Database / API Cost Pressure

### Highest cost pressure: Firestore chat

Most likely cost driver in real usage:

- real-time listeners on projects
- per-project room listeners
- selected-room message listener
- keyword match queries and writes
- read-state writes

This is the area most likely to create surprising monthly cost if usage grows.

### Medium pressure: Notion API

Most likely operational pressure:

- API latency
- request bursts during detail navigation
- recursive content fetching
- cache misses after TTL expiry

This is more likely to create slow UX or rate-limit issues than large direct infra spend.

### Low pressure: settings sync

- narrow Firestore usage
- small payloads
- periodic writes only

## Optimization Priority

### Priority 1: Project Chat

Recommended first-wave changes:

1. Subscribe to rooms only for the currently selected project, not all joined projects.
2. Add message pagination or load only the most recent N messages first.
3. Replace room-by-room keyword highlight reads with a project-level aggregate query or pre-aggregated collection.
4. Batch or debounce read-state writes.
5. Reduce send-path write count where possible.

Expected effect:

- lower Firestore read volume
- lower live listener count
- lower message-screen load cost
- lower write amplification

### Priority 2: Notion Hub

Recommended second-wave changes:

1. Keep current cache policy, but consider longer TTL for rarely changing linked detail.
2. Load summary-first and fetch full linked content lazily.
3. Avoid deep block traversal until the user explicitly opens detail content.
4. Move Notion access behind a backend proxy in production architecture.

Expected effect:

- better first-detail latency
- lower request bursts
- safer secret handling

### Priority 3: Observability

Before deeper optimization, add measurement:

1. Count active Firestore listeners by feature/session.
2. Log message query sizes and room counts.
3. Log Notion fetch durations for project list, detail, and linked content.
4. Estimate average writes per chat action.

This will make the next optimization pass evidence-based instead of intuition-based.

## Recommended Message To Chat Feature Thread

Suggested handoff summary:

`Project Chat is currently the heaviest and most cost-sensitive part of LeafPortal. The main problems are per-project room listeners, full selected-room message streaming without pagination, room-by-room keyword highlight queries, and write amplification on message send/edit/read flows. First optimization pass should focus on reducing listener count, paginating messages, and restructuring keyword highlight access patterns.`

## Final Assessment

Current app status is acceptable for small-team internal usage, but not yet structurally optimized for scale.

If team usage increases, the likely order of pain is:

1. Firestore chat read/write cost
2. chat screen responsiveness under large history
3. Notion detail latency and API burst behavior
4. secondary UI rendering costs

The app does not currently look universally "too heavy."
It looks specifically `chat-heavy`, `Notion-moderate`, and `local-tools-light`.
