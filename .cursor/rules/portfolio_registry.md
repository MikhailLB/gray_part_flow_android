---
description: Portfolio registry — anti-collision policy across shipped apps. Read before every forge run.
alwaysApply: true
---

# Portfolio Registry

> `portfolio.json` lives OUTSIDE this repo (typically one directory
> up, alongside all shipped sibling repos). It records every mutation
> that MUST NOT recur. `tool/forge/mint.dart` reads it, refuses to
> ship a recipe that collides on any tracked field, and appends a
> fresh entry on successful mint.

## What the registry tracks

For each shipped project, the registry stores:

- `timestamp` — when the forge was run
- `displayName`
- `applicationId`
- `packageSlug`
- `configEndpointUrl`
- `privacyUrl`
- `attributionDevKey`
- `messagingProjectId`
- `codecFamily`
- `codecStreamLen`

`mint.dart` treats every one of `applicationId`, `packageSlug`,
`configEndpointUrl`, `privacyUrl`, `attributionDevKey`, and
`messagingProjectId` as a **hard uniqueness constraint** — a
collision on any of them aborts the mint with a non-zero exit code.

## Values that MUST be unique per project (hard fail)

| Value | Where it appears | Why it must be unique |
|---|---|---|
| AppsFlyer developer key | `veiled_bytes.dart` (encoded) | Two apps sharing a dev key merge under one dashboard and attribution is corrupt. Also a trivial cross-app graph edge. |
| Firebase project number | `veiled_bytes.dart` + `google-services.json` | Same as above for messaging. |
| Config endpoint URL | `veiled_bytes.dart` (encoded) | The backend needs to route independently per project. Sharing a URL is an instant scanner cluster. |
| Privacy URL | `legal_urls.dart` (plain) | Store review cross-references privacy URLs to detect templated submissions. |
| Application id | `AndroidManifest.xml` + `build.gradle.kts` + `MainActivity.kt` package + `google-services.json` package_name | Play Store enforces uniqueness; scanners cluster on application id too. |
| Package slug (`pubspec.yaml` name) | `pubspec.yaml` + Dart symbol table | Compiled Dart writes the package name into the AOT snapshot; identical slugs are trivially clustered. |

## Values that MUST rotate per project (soft warn on collision)

The forge warns but does not abort when these repeat. Rotate them
whenever possible — a repeat is a partial cluster edge.

- Codec family (should differ from the previous shipped project;
  ideally rotate through all three before repeating)
- Codec salt and stream length
- Storage key prefix (`_keyPrefix` in `beacon_keystore.dart`)
- Notification channel id
- MethodChannel name (`portal_stage.dart` + `MainActivity.kt`)
- Chrome UA version
- Every timing constant in `RelayConfig`
- Palette hex values (once forge learns to rotate them)
- Boot progress fractions

## Values the forge does NOT track — you must

The registry only tracks what `mint.dart` writes. These operator
choices must be kept unique manually — a JSON annex next to
`portfolio.json` (typically `portfolio.notes.md`) is the right
place to record them.

- Keystore file (`android/key.properties` + `.jks`) — new one every
  project. **Never** reuse a keystore across two apps.
- Google Play developer account — one per portfolio slot (a shared
  Play console account is an automatic graph edge).
- AppsFlyer dashboard project — one per app.
- Firebase project — one per app.
- OneLink subdomain — one per app.
- Build machine / CI account / IP — vary if possible; identical
  upload IPs across two IPA/AAB submissions are a weak-but-real
  graph edge.
- WHOIS on the config-endpoint domain — vary registrar or
  registration timing so two sibling apps do not share a
  registration-date pattern.

## Reading and updating the registry

```powershell
# Show the registry
Get-Content ..\portfolio.json | ConvertFrom-Json | Format-Table -AutoSize

# Show the fields that must differ from the last shipped project
Get-Content ..\portfolio.json | ConvertFrom-Json | Select-Object -Last 1

# Dry-run the forge to see the mutation plan without touching the registry
dart run tool/forge/mint.dart --dry-run --portfolio ..\portfolio.json

# Real run — mint.dart appends the new entry on success
dart run tool/forge/mint.dart --portfolio ..\portfolio.json
```

`--dry-run` does NOT modify the registry. Only a full mint appends.
A successful mint also drops `forge.lock` next to `pubspec.yaml` —
that lockfile is the audit trail for what was applied to THIS
project (safe to commit; it does NOT contain plaintext secrets,
only the identifying tuple).

## When you receive a "collision" error

`mint.dart` reports the field that collided and the shipped
sibling that already owns the value. Example:

```
forge: COLLISION on attributionDevKey: this recipe reuses
"JpHHA4JDz2ZZ9V65x4rxDT" from a shipped sibling (Skyward Towers).
Rotate the value and re-run.
```

Do NOT resolve by removing the entry from `portfolio.json`.
Rotate the value — get a fresh AppsFlyer dev key, a fresh privacy
URL path, a fresh application id — and re-run.

## Enforcement in review

Before shipping, the operator MUST:

1. `dart run tool/forge/mint.dart --dry-run` cleanly.
2. Grep the release artefact for values that appear in
   `portfolio.json` under `attributionDevKey` /
   `messagingProjectId` — must return zero hits (proof that the
   codec is doing its job).
3. Confirm the `forge.lock` in the repo matches the tuple appended
   to `portfolio.json`.

Step 2 is captured in `FINAL_CHECKLIST.md`.
