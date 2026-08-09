---
description: Relay forge — recipe schema, mutation contract, codec registry. Read before running tool/forge/mint.dart or extending it.
alwaysApply: true
---

# Relay Forge

> The forge (`tool/forge/mint.dart`) is what turns the template into a
> shippable, uniquely-fingerprinted project. It reads a JSON recipe,
> validates against a portfolio registry, encodes every secret, rotates
> every constant, and rewrites ten files. Nothing else in this
> template ships as-is.

**Golden rules for AI agents:**

- Never edit `lib/relay/config/veiled_bytes.dart`,
  `lib/relay/codec/veil_codec.dart`, or `forge.lock` by hand. They
  are forge-generated artefacts — regenerate through the forge.
- Never invent a value that should live in the recipe (endpoint URL,
  AppsFlyer key, Chrome version, snooze delay, salt bytes, storage
  key prefix, channel id). Ask the operator, put the value in the
  recipe, and re-run the forge.
- Never bypass the portfolio-collision check. If the forge refuses
  to run, ROTATE THE COLLIDING VALUE. Do not disable the check.
- Do not add new codec families without also adding an entry to the
  `_writeVeilCodec` dispatch in `mint.dart` — a family that the
  runtime cannot decode is a permanent build break.

## 1. Recipe schema

`tool/forge/recipe.example.json` is the canonical schema. Copy it
to `tool/forge/recipe.json` (git-ignored) and fill every field
whose value looks like `<...>`. Fields:

### `identity` — public identity

| field | rule |
|---|---|
| `displayName` | Marketing name. Must match AndroidManifest `android:label`, App Store title, Play Console title. |
| `packageSlug` | snake_case, becomes `pubspec.yaml` → `name:`. Must be unique per project. |
| `applicationId` | Full package id, e.g. `com.vendor.project`. Rotates `android/app/build.gradle.kts` → applicationId + namespace, AndroidManifest, MainActivity.kt package. |
| `description` | 60–160 chars. Describes the WHITE game only. Never mentions "template", "gray flow", "partner", "WebView". |

### `endpoints` — URLs

| field | rule |
|---|---|
| `configEndpointUrl` | Backend verdict endpoint. Per-project domain — never reuse. |
| `gcdBaseUrl` | Usually `https://gcdsdk.appsflyer.com/install_data/v4.0/`. Same across projects (it's AppsFlyer's own host); the forge does not encode any relation between it and the app. |
| `privacyUrl` | Public. Must exist in the App Store / Play Console listing verbatim. |
| `supportUrl` | Public. Required by Play policies. |
| `homeUrl` | Optional, defaults to a landing page. |

### `credentials` — secrets that must be new every project

| field | rule |
|---|---|
| `attributionDevKey` | AppsFlyer developer key. NEVER reuse — a leaked shared key groups every sibling under one dashboard, poisoning attribution and creating a graph edge across the portfolio. |
| `messagingProjectId` | Firebase project number. NEVER reuse — same reason. |
| `storeNumericId` | iOS numeric App Store id. Empty on Android-only builds. |

### `userAgent`

| field | rule |
|---|---|
| `chromeVersion` | Rotate per project. Range: `149.0.7500.10` .. `149.0.7900.250` (or a fresh major when Chrome moves on). |
| `webkitVersion` | Usually stable at `537.36` on Android and `605.1.15` on iOS. |

See `.cursor/rules/gray_user_agent.mdc` for the full UA rules.

### `codec`

| field | rule |
|---|---|
| `family` | One of `position_xor`, `fnv_lcg`, `rc4_ksa`. See §3 below. |
| `salt` | 12–24 random bytes. Generate via `dart run tool/forge/mint.dart --gen-salt`. |
| `streamLen` | Int in `[16..48]`. Regenerate per project — the value affects the compiled binary. |

### `timings` — every timing constant

Ranges MUST be respected. See `lib/relay/config/relay_config.dart`
for the per-constant range comment.

| field | range |
|---|---|
| `permissionSnoozeSeconds` | 172800 .. 604800 (2..7 days) |
| `organicRescueDelay` | 4 .. 12 seconds |
| `verdictTimeoutSeconds` | 10 .. 25 seconds |
| `firstInstallAwaitSeconds` | 20 .. 40 seconds |
| `returningInstallAwaitSeconds` | 3 .. 10 seconds |
| `deepLinkAwaitSeconds` | 3 .. 8 seconds |
| `reachProbeTimeoutSeconds` | 4 .. 9 seconds |
| `reachDropDebounceMs` | 500 .. 1200 ms |
| `redirectLoopRetries` | 1 .. 5 |
| `cachedUrlLifetimeSeconds` | 259200 .. 1209600 (3..14 days) |

Each value must be **outside every shipped sibling** by ≥ 10 %.

### `storage`

`keyPrefix` — 3–5 ASCII chars ending in `_`, unrelated to the app
slug. Good: `k7q_`, `rl3_`, `vp8_`. Bad: `myapp_`, `puzzle_`.

### `notifications`

| field | rule |
|---|---|
| `channelId` | Rotates AndroidManifest `default_notification_channel_id` AND `kAlertChannelId`. Must be identical between the two. |
| `channelName` | User-visible in Android system settings. Sounds like a normal app channel, not "template". |

### `webView`

| field | rule |
|---|---|
| `uploadChannelName` | MethodChannel name; must be identical in `portal_stage.dart` and `MainActivity.kt`. |
| `enhancers` | Subset of `safeArea`, `keyboard`, `autoplay`. Drop one and add one — see §5. |

## 2. What the forge does NOT rotate

Some things must live outside the forge:

- OneLink subdomain (`android:host` in the OneLink intent-filter).
  Requires an AppsFlyer dashboard change per project.
- `google-services.json` (real Firebase config). Ship the
  `.example` sibling in git; the real file is downloaded per
  project.
- `android/key.properties` + the keystore itself. New keystore per
  project; never reuse.
- The launcher icon PNGs (`assets/generated/app_icon*.png`) and
  the notification vector `res/drawable/ic_notification.xml`.
- The addon asset folder name (`assets/<addon>_additional_assets_webp/`).
  Rename the folder on disk, then update `pubspec.yaml` → assets.

These are operator responsibilities. `.cursor/rules/portfolio_registry.md`
tracks them so the operator can prove uniqueness across the portfolio.

## 3. Codec families

The template ships three codec families; each lives as a Dart file
in `tool/forge/codecs/<family>.dart` with a matching encoder + a
runtime source template. The active runtime file lives at
`lib/relay/codec/veil_codec.dart` and is entirely regenerated by
the forge — never hand-edit.

| family | shape | good for |
|---|---|---|
| `position_xor` | Weyl-additive salt fold → xorshift32 keystream → per-byte XOR against keystream[i%len] XOR positionMask(i) | Default; short strings, position-varying |
| `fnv_lcg` | FNV-1a hash of salt → LCG (Numerical Recipes) keystream → per-byte XOR against keystream[i%len]. No positionMask. | Small salt, simplest data-flow |
| `rc4_ksa` | Classic RC4 KSA+PRGA. Keystream length equals plain length. | Long strings; but the KSA/PRGA loop is a well-known cluster shape — use only when required for family rotation. |

**Cluster policy.** Two consecutive shipped projects MUST use
different families. `mint.dart` warns when the previous shipped
sibling used the same family. Ideally rotate through all three
before repeating.

**Adding a new family.** Create `tool/forge/codecs/<family>.dart`
with three functions:
- `List<int> encode<Family>({required String plain, required List<int> salt, required int streamLen})`
- `bool roundTrips<Family>({required String plain, required List<int> salt, required int streamLen})`
- `String <family>RuntimeSource({required List<int> salt, required int streamLen})`

Register it in `_writeVeilCodec` (in `mint.dart`), the family switch in
`Mutation.encode`, `Mutation.roundTrips`, `Mutation.codecRuntimeSource`,
and `_validateRecipe`. Add a row to the table above.

## 4. Mutation targets

The forge rewrites exactly these files, in this order:

1. `lib/relay/codec/veil_codec.dart` — full regenerate from codec family
2. `lib/relay/config/veiled_bytes.dart` — full regenerate with encoded arrays
3. `lib/relay/config/relay_config.dart` — identity + timing constants
4. `lib/relay/config/legal_urls.dart` — three public URLs
5. `lib/relay/wire/beacon_keystore.dart` — storage `_keyPrefix`
6. `lib/relay/wire/alert_channel.dart` — `kAlertChannelId` + `kAlertChannelName`
7. `lib/relay/stage/portal_stage.dart` — MethodChannel name
8. `android/app/src/main/AndroidManifest.xml` — `android:label` + notification channel id
9. `android/app/src/main/kotlin/**/MainActivity.kt` — `channelName`
10. `pubspec.yaml` — `name:` + `description:`

Each target is gated by `recipe.targets.<name>` — set to `false`
to skip. Skipping is only useful for partial re-runs (e.g. keep
identity, only rotate the codec).

## 5. JS enhancer bundles

The three body slots in `veiled_bytes.dart` (`_jsSafeAreaScript`,
`_jsKeyboardScript`, `_jsAutoplayScript`) are empty on a fresh
template. They ship empty because scanners cluster on normalized
JS body hashes — the forge is the right place to introduce
per-project variance.

Recommended per-project variance for the enhancer bundle:

- Drop ONE of the three canonical behaviours (safeArea /
  keyboard / autoplay) if the partner site already provides it
  server-side.
- Add ONE harmless project-specific behaviour (e.g. dark
  scrollbar colours, an anti-fatigue background dimmer) so the
  behaviour set has different arity.
- Rewrite the JS with different control flow (arrow fn vs
  function decl; `Array.forEach` vs `for`; `document.querySelector`
  vs `document.getElementById`). The forge does not do this
  automatically today — hand-write the alternative bodies into
  `tool/forge/jsvariants/<family>.js` and paste them into the
  recipe as `webView.enhancerBodies.<name>`. Adding this pipeline
  is a valid forge extension.

## 6. Extension points

If a future project needs a value the current forge does not
rotate, ADD it to the recipe schema and the mutation writer;
DO NOT bypass by editing generated files. The forge is the
single source of truth for project variance.

Suggested additions when portfolio pressure requires them:

- Rotate palette hex values in `lib/app/relay_theme.dart`.
- Rotate the DNS probe host list in `lib/relay/wire/pulse_probe.dart`.
- Rotate the boot-screen progress fraction values in
  `lib/boot/boot_screen.dart`.
- Rotate `RelayCoordinator._decideXxx` progress sub-fractions
  (currently `0.3 / 0.5 / 0.75 / 0.55 / 0.6`).
- Full package-directory rename in `android/app/src/main/kotlin/**/`.
