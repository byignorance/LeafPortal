# studioLEAF Portal Access Control Bootstrap

Date: 2026-03-08
Target project: `studioleafportal`

## Purpose

This document records the initial Firestore access-control document used by:

- app-side admin resolution
- Firestore rules admin resolution
- future multi-admin operations

## Firestore Document

- path: `portalSettings/accessControl`

## Initial Payload

```json
{
  "adminUIDs": [],
  "adminEmails": [
    "hello@studioleaf.kr"
  ]
}
```

## Notes

1. `hello@studioleaf.kr` remains the bootstrap admin.
2. Future admins should be added through:
   - `adminUIDs` for stable identity
   - `adminEmails` only when UID is not yet known
3. Long term, `adminUIDs` should become the primary source.
4. Optional `portalAdmin` custom claim can still override and is useful for backend-managed elevation.

## Current Status

- rules deployed: yes
- bootstrap document created: intended in this rollout
