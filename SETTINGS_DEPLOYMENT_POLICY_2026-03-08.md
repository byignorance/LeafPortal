# StudioLeafPortal Settings Deployment Policy

Date: 2026-03-08
Target app: `StudioLeafPortal`

## Goal

When the app is distributed beyond internal development, settings should be separated by ownership.

The current issue is that `기본 설정` mixes:

- local app behavior
- operator-only portal controls
- external service management

This should be split so user expectations and permissions stay clear.

## Recommended Top-Level Split

### 1. Local App Settings

Owner:

- any signed-in or signed-out user on that device

Examples:

- window/app launch behavior
- local appearance or UI preferences
- device-level helper behavior
- notification presentation preference if it is purely local

Rule:

- stored locally by default
- not treated as portal-wide operations policy

### 2. Collaboration / Tool Settings

Owner:

- each feature owns its own settings

Examples:

- `Render Noti` thresholds, folders, sound settings
- `WakeUp Leaf` timer mode, target apps, keep-awake rules
- `Team Messenger` notification and sound behavior
- `Notion Connector` web session state

Rule:

- keep these inside the feature itself
- avoid duplicating them inside global settings unless the global page is only showing shortcuts

### 3. Portal Operations Settings

Owner:

- administrator only

Examples:

- member management
- external storage templates or provisioning rules
- Notion connection policy used by the portal
- shared collaboration defaults
- cloud or backend operational toggles

Rule:

- move these out of `기본 설정`
- expose them under a dedicated admin area such as `운영 설정`

## Recommended Structure

### Non-admin users

- `일반`
- `아이콘 관리`

Meaning:

- `일반` should be device/local app settings only
- `아이콘 관리` can stay if it is treated as a user-facing local/customization tool

### Admin users

- `일반`
- `아이콘 관리`
- `회원 관리`
- `운영 설정`

Meaning:

- `회원 관리` stays focused on users and access
- `운영 설정` becomes the place for portal-wide policies and service configuration

## What Should Move Out of Current General Settings

These items are better treated as admin/operator settings:

- external storage management policy
- Project Hub template/global setup controls
- shared Notion connection operations policy
- any shared portal behavior that affects all users

These items can remain general/local:

- app launch behavior
- local helper UI behavior
- local-only convenience toggles

## Why This Is Better For Distribution

1. Permissions become predictable
- normal users do not see controls they should not touch

2. Support becomes simpler
- “tool settings” live in the tool
- “portal operations” live in admin settings

3. Future security rules become easier
- admin-only Firestore writes can map directly to `운영 설정`

4. UI meaning improves
- `기본 설정` stops acting like a mixed junk drawer

## Practical Recommendation

Near-term:

1. Keep `Render Noti` and `WakeUp Leaf` settings in their own feature screens
2. Shrink current `기본 설정` to local app behavior only
3. Add admin-only `운영 설정` and move portal-wide items there

Later:

1. connect `memberState == disabled` to collaboration access denial
2. separate local preferences from cloud-backed admin policies
3. keep feature-specific settings near the feature unless they truly apply portal-wide

## Bottom Line

For deployment, the clean model is:

- `일반` = local app settings
- feature settings = inside each feature
- `회원 관리` = admin user control
- `운영 설정` = admin portal control

That separation matches how the app is already evolving and will reduce confusion as more users are added.
