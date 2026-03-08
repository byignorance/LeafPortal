# studioLEAF Portal Member State Policy

Date: 2026-03-08
Target app: `StudioLeafPortal`

## States

### `active`

- Firebase sign-in allowed
- collaboration features allowed
- tool features allowed
- visible in member management as normal active user

### `paused`

- Firebase sign-in allowed
- collaboration features blocked
- tool features allowed
- use when a member should temporarily stop using shared collaboration spaces without fully removing local tool access

### `disabled`

- Firebase sign-in may still succeed at provider level
- collaboration features blocked
- tool features allowed unless a stricter future policy is introduced
- use when the member should no longer participate in team spaces

## Current Enforcement

- `Project Hub`: blocked unless member state is `active`
- `Team Messenger`: blocked unless member state is `active`
- `Notion Connector`: blocked unless member state is `active`
- Firestore collaboration rules also require active member state

## Operational Notes

1. `paused` is the temporary operational state.
2. `disabled` is the administrative stop state.
3. Neither state currently blocks local tool usage.
4. If full app lockout is needed later, that should be introduced as a separate explicit policy.
