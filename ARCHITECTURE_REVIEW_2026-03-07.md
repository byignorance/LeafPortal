# LeafPortal Architecture Review

Date: 2026-03-07

## Product Definition

`LeafPortal` is a portal app that contains multiple internal tools.

It should be treated as:

- one host application
- one shared portal shell
- multiple tool modules inside the app

It should not be treated as:

- one oversized single-purpose screen
- a renamed copy of an older app
- a place where user-facing feature names and internal code names drift independently

## Current Tool Inventory

Observed tool and portal areas:

- `Overview`
- `Project Chat`
- `Notion Hub`
- `Render Notification`
- `Sleep Guard`
- `Activity`
- `Settings`
- `Icon Management`

## Review Summary

The app direction is valid: a portal shell with multiple internal workflow tools.

The main risk is not the feature set itself, but inconsistent boundaries between:

- portal shell vs tool module
- user-facing naming vs code naming
- finished actions vs placeholder actions
- global state vs feature state

## Main Findings

### 1. Product vocabulary is mixed

The same concept appears under multiple names:

- `Render Notification`
- `Render Noti`
- `renderNoti`
- `WakeUp Leaf`
- `SleepGuard`
- `isWakeUpLeafMenuBarInserted`

This is manageable while the app is small, but becomes expensive once more tools are added.

### 2. Portal shell and tool modules are still too tightly coupled

The portal shell is correct as a concept, but too much feature-specific behavior still lives close to the root view and root view model.

Symptoms:

- root view is very large
- root view model is very large
- multiple tool behaviors are coordinated from shared files instead of feature boundaries

### 3. Some interactions look complete but are not functionally complete

There are controls that behave like final product actions while still being placeholders or route to the wrong destination.

### 4. Failure handling exists conceptually but not always operationally

Some monitoring/error pathways are modeled, but not consistently surfaced to the user.

### 5. Current size suggests the next scaling problem is structure, not UI polish

The feature count is already high enough that file length and mixed responsibilities are becoming the main maintainability risk.

## Architecture Direction To Preserve

The following direction is good and should be reinforced:

- `Portal/` for app shell and cross-tool navigation
- `Features/<FeatureName>/` for tool-local UI, engine, and models
- `Shared/` for reusable services that are truly cross-cutting

Recommended mental model:

- `Portal` = host shell
- `Feature` = one internal tool
- `Shared` = infrastructure used by more than one tool

## Naming Direction To Preserve

Use one canonical display name and one canonical code name per tool.

Recommended canonical display names:

- `LeafPortal`
- `Overview`
- `Project Chat`
- `Notion Hub`
- `Render Notification`
- `Sleep Guard`
- `Activity`
- `Settings`
- `Icon Management`

Recommended canonical code names:

- `Portal`
- `ProjectChat`
- `NotionHub`
- `RenderNotification`
- `SleepGuard`
- `IconManagement`

Avoid introducing new variants such as:

- `Render Noti`
- `WakeUp Leaf`
- mixed spellings of the same feature in labels, enums, and state names

## Working Rules For Future Development

### Portal shell rules

- The portal shell owns navigation, layout frame, and cross-tool entry points.
- The portal shell should not own detailed business logic for each tool.
- Placeholder actions must be marked or disabled, not presented as complete actions.

### Tool module rules

- Each tool should own its own UI sections, state, service or engine layer, and tool-specific settings.
- Tool names should match folder names, major type names, and user-facing labels as closely as possible.
- Tool-specific terms should not leak into unrelated modules.

### Shared layer rules

- A type belongs in `Shared/` only if at least two tools use it or it is truly app-wide infrastructure.
- Do not move feature code into `Shared/` just because a file became large.

## Priority Cleanup Order

When development resumes, use this order:

1. standardize product and tool terminology
2. separate portal shell responsibilities from tool responsibilities
3. replace or disable placeholder actions
4. make failure states observable to users
5. split oversized root files by tool and by screen section

## Review Outcome

`LeafPortal` has a workable product shape.

The next important work is not adding more surface area blindly, but making the portal/tool boundary and naming rules explicit before the app grows further.
