# studioLEAF Portal Admin Access Runbook

Date: 2026-03-08
Target project: `studioleafportal`

## Admin Resolution Order

Admin is treated as true when one of the following matches:

1. Firebase custom claim `portalAdmin == true`
2. `portalSettings/accessControl.adminUIDs` contains the user UID
3. `portalSettings/accessControl.adminEmails` contains the user email
4. bootstrap email fallback matches `hello@studioleaf.kr`

## Recommended Practice

Use this order for real operations:

1. add target admin UID to `portalSettings/accessControl.adminUIDs`
2. optionally keep matching email in `adminEmails` during transition
3. use custom claim only when backend-managed elevation is needed

## Grant Admin

### Preferred

1. find the target user's Firebase UID from `directoryUsers`
2. add that UID to `portalSettings/accessControl.adminUIDs`
3. ask the user to sign out and sign back in, or wait for the listener refresh

### Temporary fallback

1. add the email to `portalSettings/accessControl.adminEmails`
2. move to UID-based control once the UID is confirmed

## Revoke Admin

1. remove UID from `adminUIDs`
2. remove email from `adminEmails` if present
3. remove `portalAdmin` custom claim if one had been granted
4. ask the user to refresh sign-in

## Member Management Note

- Admin visibility in the app is derived from the same access-control sources.
- `directoryUsers.isAdmin` is treated as synchronized display metadata, not the authoritative source.
