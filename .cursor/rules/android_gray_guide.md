# Android Gray Flow — Full Integration Guide
## For AI agents generating a gray-part Flutter/Android project in one shot

This document is the **single source of truth** for building a gray-flow
Android app from a customer brief. Read top-to-bottom before writing any
code; every section is a hard invariant unless it says otherwise.

---

## How to Use This Document (for AI agents)

You will typically receive one customer message containing a brief +
partial credentials. Your job is to produce a complete, buildable Flutter
project matching this guide. Do it in this order:

1. **Parse the brief against §"Inputs You Need Before Generating".** If
   anything is missing that cannot be sensibly defaulted, ask the user
   for it in a single batched question — do not scaffold with placeholders
   that will silently break later (endpoint, AppsFlyer key, Firebase
   config).
2. **Scaffold the file tree from §"Project Structure".** Rename services
   and folders per §"Code Mixing" — never ship two projects with the
   same class/folder names.
3. **Fill the config layer** (`app_settings.dart`, `analytics_info.dart`,
   `net_info.dart`, `game_endpoints.dart`) using XOR-encoded byte arrays
   from `tool/encode_keys.dart` and a fresh codec seed.
4. **Implement services in this dependency order:** `codec.dart` →
   `http_client.dart` → `storage_service.dart` → `connectivity_service.dart`
   → `appsflyer_service.dart` → `push_notification_service.dart` →
   `remote_service.dart`. Each service depends only on those listed
   before it.
5. **Wire the state machine from §"Gray Flow State Machine".** All routing
   lives in `splash_screen.dart`. Do not scatter it across the tree.
6. **Build the two custom screens** — `notification_permission_screen.dart`
   and `no_internet_screen.dart` — matching the layouts in §"Screen
   Layout" and the asset rules in `custom_screens.md`.
7. **Copy the game module unchanged** from the template
   (`lib/game/game_screen.dart`, `game_engine.dart`, `game_painter.dart`,
   `game_assets.dart`).
8. **Configure Android:** `AndroidManifest.xml`, `build.gradle.kts`,
   `google-services.json`, notification icon, OneLink host,
   `POST_NOTIFICATIONS` permission.
9. **Apply every fix from `gray_part_pitfalls.md`** — file_picker pinned
   to 8.1.4, compileSdk override in root gradle, desugaring on, VPN
   whitelisted in the connectivity sensor, etc.
10. **Verify with the checklist in §"Testing Guide"** and the TL;DR at
    the bottom of `gray_part_pitfalls.md` before declaring done.

Companion rule files, all inside `.cursor/rules/`:

- `gray_part_pitfalls.md` — battle-tested Android fixes (must apply)
- `custom_screens.md` — project-specific screen assets
- `webview_safe_area_injection.mdc` — safe-area CSS injection contract
- `gray_user_agent.mdc` — UA identity suffix (Zeus/Magma themes only)

---

## Inputs You Need Before Generating

Refuse to scaffold without the items marked ★. Everything else has a safe
default, but ask if the brief looks incomplete.

### App identity
- ★ `bundleId` — e.g. `com.example.app`
- ★ `appName` — human-readable name as it will appear in the store
- `storeId` — Android: same as `bundleId`. iOS: `id` + numeric App Store
  id (e.g. `id84435554334`). For Android-only projects, record but leave
  Android's `storeId = bundleId`.
- Apple ID (iOS builds only) — numeric App Store id without `id` prefix,
  required by the manager to issue the config endpoint

### Backend
- ★ Config endpoint URL (from manager) — see §"Config Request Contract" §1
- GCD endpoint base URL (default: `https://gcdsdk.appsflyer.com`)

### AppsFlyer
- ★ Dev Key
- ★ OneLink host / subdomain (from AppsFlyer dashboard → App Settings → OneLink)

### Firebase
- ★ `google-services.json` (placed at `android/app/`, git-ignored)
- ★ Firebase project number (or Project ID) — sent as `firebase_project_id`
- Service account `marla-export@marfa-290610.iam.gserviceaccount.com` must
  have Owner role in GCP for the project (manager confirms)

### Legal / policy
- ★ Privacy policy URL (public, permanent)
- ★ Support URL

### Obfuscation
- ★ Codec seed — a short ASCII phrase (6–12 chars) unique to this project.
  Never reuse across projects. Re-run `encode_keys.dart` after every seed
  change.

### Assets
- ★ Notification icon — **monochrome** PNG or vector, distinct from the
  launcher icon (`android/app/src/main/res/drawable/ic_notification.*`)
- ★ Push-permission screen backgrounds — portrait + landscape
  (see `custom_screens.md`)
- ★ No-internet screen backgrounds — portrait + landscape
- Adaptive launcher icon that fills the icon shape without clipping
- Game asset bundle (from template — do not modify)

### Theme flag
- Game theme name (e.g. "Zeus", "Magma", "LavaPeakRun"). If Zeus or Magma,
  additionally apply `gray_user_agent.mdc` — append
  `appid/<bundleId> appname/<AppName>` to the WebView + HTTP User-Agent.

---

## What Is the Gray Flow?

A **gray flow** is a dual-mode Flutter app:

- **Gray mode (online):** Shows a full-screen WebView with a URL received from a remote backend. The app acts as a thin shell.
- **White mode (offline):** Shows a native game (fallback for organic/unattributed users).

The backend decides which mode each user sees based on their **AppsFlyer attribution** — install source, campaign, ad network. Paid (non-organic) users get the WebView. Organic users get the game.

**Why this architecture exists:** One APK serves two entirely different experiences, determined at runtime. The game provides a legitimate Store listing with real content. The WebView delivers partner content to targeted users only.

---

## Why Stealth Matters

Store reviewers and automated scanners look for:
- Apps that are "just WebViews" with no real content
- Apps that behave differently during review vs. production
- Known affiliate/tracking domains in the binary
- Structural fingerprints shared across multiple submissions from the same developer

**What happens if caught:** App removal, developer account ban, associated accounts banned.

**Defense strategy:**
1. Real game = real review content (scanner and human reviewer see the game)
2. All sensitive strings XOR-encoded (API domain, AppsFlyer key, Firebase ID)
3. Attribution gate = only paid installs see the WebView (reviewer gets organic install = game)
4. Unique binary fingerprint per project (different codec seed, class names, folder structure, library versions)
5. Real device User-Agent on all requests (no Dart/Flutter fingerprint)

---

## Project Structure

```
lib/
├── main.dart                   Entry point: Firebase, AppCheck, services, runApp
├── app.dart                    Root MaterialApp widget
├── config/
│   ├── app_settings.dart       ★ FILL FIRST: bundleId, storeId, appName
│   ├── analytics_info.dart     ★ AppsFlyer key + Firebase project# + GCD URL (encoded)
│   ├── net_info.dart           ★ Config endpoint URL (encoded)
│   └── game_endpoints.dart     Privacy policy + support URLs
├── models/
│   ├── app_mode.dart           online / offline / pending enum
│   └── remote_response.dart    API JSON model {ok, url, expires, message}
├── screens/
│   ├── splash_screen.dart      ★ CORE: loading video + gray/white routing
│   ├── content_screen.dart     WebView shell (gray mode UI)
│   ├── notification_permission_screen.dart  Push opt-in promo
│   ├── no_internet_screen.dart No connection error + retry
│   └── info_screen.dart        Mini WebView for legal pages (from game)
├── services/
│   ├── appsflyer_service.dart  SDK init + attribution + GCD retry
│   ├── remote_service.dart     POST to config endpoint + URL caching
│   ├── push_notification_service.dart  FCM + local notifications
│   ├── http_client.dart        Real device User-Agent injection
│   ├── storage_service.dart    SharedPreferences + FlutterSecureStorage
│   └── connectivity_service.dart  DNS probe connectivity check
├── utils/
│   └── codec.dart              XOR deobfuscator (change seed per project)
└── game/
    ├── game_screen.dart        ★ White part (do not modify)
    ├── game_engine.dart        Game mechanics (do not modify)
    ├── game_painter.dart       Canvas rendering (do not modify)
    └── game_assets.dart        Asset preloading (do not modify)

tool/
└── encode_keys.dart            Run to encode secrets → byte arrays

android/app/
├── build.gradle.kts            applicationId, minSdk=26 (Android 8.0), targetSdk=35
├── google-services.json        ★ Firebase config (not in git)
└── src/main/
    ├── AndroidManifest.xml     ★ OneLink host, FCM channel, INTERNET permission
    └── res/drawable/
        └── ic_notification.png ★ Monochrome push notification icon
```

---

## Setup Checklist (new project from this template)

### Step 1 — App identity

Edit `lib/config/app_settings.dart`:
```dart
static const String bundleId = 'com.yourcompany.yourapp';
static const String storeId  = 'com.yourcompany.yourapp';  // same as bundleId on Android
static const String appName  = 'Your App Name';
```

Edit `android/app/build.gradle.kts`:
```kotlin
namespace = "com.yourcompany.yourapp"
defaultConfig {
    applicationId = "com.yourcompany.yourapp"
}
```

Rename the Kotlin package directory:
```
android/app/src/main/kotlin/com/yourcompany/yourapp/
```
Update the `package` declaration in `MainActivity.kt`.

### Step 2 — Encode secrets

Edit `tool/encode_keys.dart` — fill in:
- Config endpoint URL
- AppsFlyer Dev Key
- Firebase project number
- GCD endpoint base URL
- Chrome/WebKit version fragments for User-Agent

Run:
```bash
dart run tool/encode_keys.dart
```

**⚠️ ALWAYS use `dart run`, never PowerShell foreach loops.**
PowerShell overflows integers at 32 bits on Windows → wrong byte values.
Symptom: `FormatException: Invalid HTTP header field value`.

Paste the printed arrays into:
- `lib/config/analytics_info.dart` — AppsFlyer key, Firebase project#, GCD URL
- `lib/config/net_info.dart` — config endpoint
- `lib/services/http_client.dart` — Chrome version fragments

### Step 3 — Change codec seed

Edit `lib/utils/codec.dart` → change `parts` in `_deriveKey()`.
Pick any short ASCII phrase unique to this project (6–12 chars).
**Re-run encode_keys.dart after every seed change.**

### Step 4 — Firebase

Add `android/app/google-services.json` (from Firebase Console → Project Settings → Android app).
Bundle ID in this file must match `applicationId` exactly.

Add `android/app/google-services.json` to `.gitignore` if the repo is public.

### Step 5 — AppsFlyer OneLink

In `android/app/src/main/AndroidManifest.xml`, update the OneLink host:
```xml
<data android:scheme="https" android:host="yourapp.onelink.me" />
```
Get the OneLink subdomain from AppsFlyer dashboard → App Settings → OneLink.

### Step 6 — Notification icon

Place a monochrome PNG at:
```
android/app/src/main/res/drawable/ic_notification.png
```
Requirements:
- Monochrome (white on transparent background)
- NOT the same as the launcher icon
- Size: 24×24dp source, provide mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi versions
  OR provide a single `res/drawable/ic_notification.png` (Android uses it for all densities)

### Step 7 — Firebase service account (push system)

In Firebase Console → Project Settings → Users and permissions → Advanced permission settings (opens GCP):
- Add `marla-export@marfa-290610.iam.gserviceaccount.com`
- Role: Basic → Owner
- Save

Without this, the push notification system cannot send messages.

### Step 8 — Privacy policy URL

Edit `lib/config/game_endpoints.dart`:
```dart
const String privacyPolicyPageUrl = 'https://your-privacy-policy.com';
const String supportPageUrl = 'https://your-support.com';
```

### Step 9 — Code Mixing (mandatory)

See the Code Mixing section below. Every project must have a unique structure.

### Step 10 — Build & verify

```bash
flutter pub get
flutter analyze
flutter build apk --release --obfuscate --split-debug-info=build/debug_info
```

---

## Gray Flow State Machine

```
AppMode.pending (FIRST LAUNCH)
  ├── No internet → NoInternetScreen
  │     └── Retry → SplashScreen (restarts)
  └── Has internet
        ├── appsFlyer.init()
        ├── await [waitForAttribution (30s), waitForDeepLink (5s)]
        │     ⚠️ If af_status=="Organic": wait 5s, retry via GCD API
        ├── buildRequestBody(locale, pushToken)
        ├── remoteApi.fetchRemote(body)
        ├── Response ok+url → setAppMode(online) → ContentScreen
        └── Response fail/no-url → setAppMode(offline) → GameScreen

AppMode.online (RETURNING, WAS WEBVIEW)
  ├── No internet → NoInternetScreen
  ├── Push URL in storage → ContentScreen(pushUrl)  ← HIGHEST PRIORITY
  ├── appsFlyer.init() + attribution (10s timeout)
  ├── fetchRemote() → response.url → ContentScreen(new url)
  └── API fail + savedUrl → ContentScreen(savedUrl)
       └── No savedUrl → NoInternetScreen

AppMode.offline (RETURNING, WAS GAME)
  ├── Load GameAssets
  └── GameScreen (always, no network needed)
```

**Key insight:** Offline users are never shown the WebView on return visits, even if they get internet. The mode is permanently set to offline once the backend says no. This is intentional — the backend decides conversion, not the client. See §"Config Request Contract" §9 for the full behaviour tree, including the hard rule that no further config requests may be sent for the lifetime of an install once `AppMode.offline` is committed.

---

## First-Launch UX Contract (OneLink + Offline Install)

This is a hard invariant for the *very first launch* after installing via
a OneLink (paid attribution present, but the device may have no
connectivity yet). Failing any bullet below is a QA-blocking bug — do not
skip.

### Canonical scenario (must be reproducible on every build)

1. User taps the OneLink on the target device.
2. **Wi-Fi / mobile data is turned OFF** before the install completes.
3. User installs and opens the app.
4. → App must show the **No-Wi-Fi screen IMMEDIATELY**, on the very first
   frame. No splash flicker, no video, no Flutter branding, no default
   Android black screen — the No-Wi-Fi screen is the first pixel the user
   sees.
5. User turns Wi-Fi / mobile data ON.
6. User taps **Retry** / **Reconnect** on the No-Wi-Fi screen.
7. → App transitions into the loading (splash) screen and then routes to
   the gray part (WebView with the config `url`).
   - Loading screen must complete its animation (see §"Screen Layout:
     SplashScreen (Loading)" §Timing contract).
   - No return to No-Wi-Fi mid-way, no game screen shown at any point in
     this scenario (attribution is Non-organic → WebView).

### Implementation rules

- **Connectivity gate runs before AppsFlyer init.** Check
  `connectivity_plus` + a fast DNS probe (7 s max — see
  `gray_part_pitfalls.md` §3) *before* `appsFlyer.init()`. If offline,
  push `NoInternetScreen` synchronously via `Navigator.pushReplacement` on
  the first frame. Do not `await appsFlyer.init()` first — that call can
  hang for tens of seconds without connectivity and the user will stare
  at the OS launch background.
- **No pre-check splash flicker.** The route decision must be resolved in
  the first Flutter frame after `runApp`. Use a synchronous
  `AppMode.pending` bootstrap that inspects connectivity *before*
  building the splash tree. If offline, build `NoInternetScreen` directly
  as the initial route.
- **Retry restarts the full splash pipeline.** Tapping Retry must call
  `Navigator.pushReplacement` back to `SplashScreen`, which then re-runs
  the connectivity check → `appsFlyer.init()` → attribution wait →
  `remoteApi.fetchRemote()` → route. Do not "patch" state in place;
  the pipeline is idempotent by design.
- **AppMode stays `pending` throughout.** Because we never received a
  config response, the mode has not been committed to `online` or
  `offline` yet — do NOT persist `offline` merely because of the initial
  network failure. Only a *successful* HTTP response with `ok: false`
  commits `offline` (see §"Config Request Contract" §9).
- **Debounce the connectivity stream (700 ms)** everywhere except this
  boot-time first-frame check — the boot check must be instant. The
  debounce prevents VPN-flicker false-positives on returning launches
  (see `gray_part_pitfalls.md` §3).
- **No game fallback on offline boot.** Do not preload
  `GameAssets` on the offline path — the moment internet returns and
  the fetch succeeds, we go to `ContentScreen`, not the game.

### Sequence diagram

```
Install via OneLink, Wi-Fi OFF
        │
runApp()
        │
SplashScreen.build() ── connectivity check ── offline? ── YES
        │                                                  │
        │                                                  ▼
        │                                    Navigator.pushReplacement
        │                                    → NoInternetScreen (first frame)
        │                                                  │
        │                                    user enables Wi-Fi
        │                                                  │
        │                                    user taps Retry
        │                                                  │
        │                                    Navigator.pushReplacement
        │                                                  │
        ▼                                                  │
SplashScreen.build() ◀────────────────────────────────────┘
        │
    connectivity OK
        │
    Loading animation starts (0% → 100%)
        │
    appsFlyer.init() ─ attribution wait ─ GCD retry if Organic
        │
    remoteApi.fetchRemote()
        │
    Response ok+url → wait for loading bar to hit 100%
        │
    Navigator.pushReplacement → ContentScreen(url)  ← gray part
```

---

## Config Request Contract (AUTHORITATIVE)

Every rule below is a hard invariant. Deviating from any of them breaks
routing, tests, or the push subsystem. When generating from scratch, treat
this section as the API spec and mirror it exactly in `remote_service.dart`
and `appsflyer_service.dart`.

### 1. Endpoint

| Field | Value |
|---|---|
| URL | Provided by the project manager, stored XOR-encoded in `lib/config/net_info.dart` |
| Method | `POST` |
| Headers | `Content-Type: application/json`, `Accept: application/json` |
| Timeout | 15 seconds |

**How to obtain the endpoint.** The manager gives you a URL like
`https://example.com/config.php`. To receive it, you must first supply:

- `bundleId` (e.g. `com.example.app`)
- Apple ID — numeric App Store id, iOS builds only
- App name exactly as it will appear in the target store

For Android-only projects, still record the Apple ID field as "N/A".
Never hard-code the endpoint at a call site — always deref through
`NetInfo.apiEndpoint` so a single edit propagates everywhere.

### 2. Request body — merge order

The body is a single flat JSON object built by merging three sources.
First-write-wins on key collision (`putIfAbsent`), then device-side
fields are added last and **overwrite** duplicates:

| Priority | Source | Overwrite rule |
|---|---|---|
| 1 | `onInstallConversionData` (AppsFlyer attribution) | writes all keys as-is |
| 2 | `onAppOpenAttribution` (returning-user attribution) | putIfAbsent |
| 3 | `onDeepLinking` (UDL data — see §4) | putIfAbsent |
| 4 | Device-side fields (see §3) | overwrites |

**Hard rules:**

- ❌ **NEVER** filter, rename, drop, or mutate any key/value received from
  AppsFlyer. The list of parameters varies per install source — pass it
  through unchanged even if a key looks unfamiliar.
- ❌ Do not JSON-nest. The body must be one flat object.
- ✅ Log the final body in `kDebugMode` for QA (see §11 Testing).

### 3. Device-side fields (added last, always overwrite)

| Key | Type | Source | Notes |
|---|---|---|---|
| `af_id` | string | `AppsflyerSdk.getAppsFlyerUID()` | Empty in Unity Editor, real everywhere else |
| `bundle_id` | string | `AppSettings.bundleId` | e.g. `com.example.app` |
| `os` | string | `"Android"` or `"iOS"` | Case-sensitive — exactly these two literals |
| `store_id` | string | see below | **Android:** identical to `bundle_id`. **iOS:** `"id" + numericStoreId`, e.g. `"id84435554334"` |
| `locale` | string | Device primary locale in **RFC 3066** | Preferred: `ru`, `en`, `en_US`, `pt_BR`. Also accepted by backend: `English`, `French`, `Spanish`, `Italian`, ... Do not lowercase, do not strip region. |
| `push_token` | string | `FirebaseMessaging.instance.getToken()` | **Omit key entirely if FCM not initialised — see §5** |
| `firebase_project_id` | string | Firebase `Project number` OR `Project ID` from `google-services.json` | **Omit key entirely if FCM not initialised — see §5** |

Never send `push_token: ""` or `push_token: null` — omit the key. The
backend distinguishes "no push subsystem" from "empty token" and mis-routes
if either sentinel value leaks through.

### 4. UDL / Deep-link fields (from `onDeepLinking`)

If the SDK delivers deep-link data, merge every field it returns
(`putIfAbsent`, i.e. do not overwrite keys already provided by conversion
data). Full set the SDK may deliver — none are guaranteed:

```
campaign_id, campaign, media_source, timestamp,
match_type            // "probabilistic" | "deterministic"
deep_link_value       // primary payload the campaign attached
deep_link_sub1..N     // additional sub-parameters
is_deferred           // bool
click_http_referrer   // origin URL
af_sub1..5, af_sub_1..5
```

Reminder: **the SDK's field list is authoritative** — pass through whatever
it delivers, even fields not listed here. The table exists only so you know
which extra keys can appear beyond the standard attribution set.

### 5. Firebase Messaging not initialised

If FCM fails to initialise (missing `google-services.json`, Play Services
absent, permission denied, first-launch race), the request must be sent
**without both** `push_token` **and** `firebase_project_id`. Skip the keys
entirely; do not substitute empty strings or `null`.

Recovery path — no manual retry, driven by SDK events:

1. Register `pushService.onTokenRefresh = _onPushTokenRefresh` at startup.
2. When the callback fires (first token arrival, or token rotation),
   **immediately** re-POST the config request with the full body
   including the new token.
3. Persist the resulting `url` / `expires` as usual.

Never poll `getToken()` in a loop — the refresh callback is the contract.

### 6. Example request body

Attribution fields vary per install source. This is a representative
Non-organic install merged with device fields:

```json
{
  "adset": "s1s3",
  "af_adset": "mm3",
  "af_status": "Non-organic",
  "campaign": "MyApp_US_Facebook_2025",
  "campaign_id": "6068535534218",
  "media_source": "Facebook Ads",
  "is_first_launch": true,
  "is_paid": true,
  "af_sub1": "439223",
  "deep_link_value": "promo_2026",
  "match_type": "probabilistic",
  "is_deferred": true,
  "af_id": "1688042316289-7152592750959506765",
  "bundle_id": "com.example.app",
  "os": "Android",
  "store_id": "com.example.app",
  "locale": "en_US",
  "push_token": "dl28EJC...",
  "firebase_project_id": "8934278530"
}
```

### 7. Response — success (HTTP 200)

```json
{ "ok": true, "url": "https://link.example/...", "expires": 1689002181 }
```

- `url` — load into the WebView **unchanged**. No query-string rewriting,
  no domain substitution, no scheme upgrades.
- `expires` — Unix timestamp in seconds. Persist alongside `url`.
- On subsequent launches, before making any network call, compare
  `DateTime.now().millisecondsSinceEpoch ~/ 1000` against `expires`.
  If not expired → load `savedUrl` immediately (see §9 for the full
  returning-user tree).

### 8. Response — failure

Any of:

- HTTP status ≠ 200 (typically `404`)
- `ok: false` in a 200 body
- Socket / DNS / timeout error

is a **NEGATIVE** answer for the "should we show the WebView?" question.
Payload example:

```json
{ "ok": false, "message": "No data" }
```

### 9. Behavior contract on failure

The following tree is a hard invariant. Do not add "just one more retry" —
extra requests are visible to store scanners and to the backend as noise.

**First install — never fetched a successful `url` before:**

1. Config request fails ⇒ set `AppMode.offline` **permanently** in
   `StorageService` (persisted flag).
2. Launch the game screen (`GameScreen`).
3. **Do not send any further config requests for the entire remaining
   lifetime of this install**, on this launch or any future launch, unless
   a different behaviour was explicitly agreed with the manager for this
   specific project.
4. Uninstall + reinstall is the only way to reset this state (intentional).

**Returning launch — we previously stored a valid `url` and `expires`:**

1. If `expires` not passed → load `savedUrl` in WebView, skip the network
   call entirely.
2. If `expires` passed → send a fresh config request:
   - Success ⇒ overwrite `savedUrl` + `expires`, load new `url`.
   - Failure ⇒ **still load `savedUrl`**. Never fall back to game, never
     show a blank state. The saved URL is the last-known-good.
3. If the returning launch has a pending push URL in storage, that URL
   wins over both `savedUrl` and any fresh fetch — see §Push routing.

### 10. Backend test-environment quirks (know before QA)

- On the default (unconfigured) test backend, a `url` is returned **only**
  when `af_status == "Non-organic"`. Organic installs receiving
  `{ ok: false }` is **correct behaviour** — do not treat this as a client
  bug and do not add fallback logic.
- End-to-end push notification tests **require every client-side field**
  from §3 to be present in the request:
  `af_id`, `bundle_id`, `os`, `store_id`, `locale`, `push_token`,
  `firebase_project_id`. If any of these are missing, the backend cannot
  target the device, and pushes will silently never arrive — even though
  the config response looks correct. Log the final body and verify all
  seven keys before opening a QA ticket.

### 11. QA-friendly logging (debug builds only)

Wrap every log in `if (kDebugMode)`. Emit:

- `[AppsFlyerService] onInstallConversionData: <payload>`
- `[AppsFlyerService] onDeepLinking: <payload>`
- `[AppsFlyerService] GCD retry data: <payload>` (only when organic-retry fires)
- `[RemoteService] Request body: <final merged JSON>`
- `[RemoteService] Response: <status> <body>`

Never log in release — those strings become fingerprints.

---

## AppsFlyer: Organic False-Positive Fix

**Problem:** AppsFlyer sometimes fires `onInstallConversionData` with `af_status: "Organic"` even for paid installs (SDK timing bug on first-run).

**Detection:** `payload['af_status'] == 'Organic'`

**Fix in `appsflyer_service.dart`:**
```dart
if (payload['af_status'] == 'Organic') {
  await Future.delayed(Duration(seconds: AppSettings.syncRetrySeconds)); // 5s
  final retryData = await _refreshAttribution();
  _attributionData = retryData ?? payload;
} else {
  _attributionData = payload;
}
```

**GCD API call (in `_refreshAttribution()`):**
```
GET https://gcdsdk.appsflyer.com/install_data/v4.0/{bundleId}?device_id={appsFlyerUID}
Authorization: Bearer {analyticsKey}
```
Returns the true attribution JSON on success.

Use the last successfully received data for the config request.

---

## Push Notifications: Complete Implementation

### Permission flow (per TZ)

1. Show `NotificationPermissionScreen` **before** opening ContentScreen (WebView).
2. Screen shown only once if permission not yet granted and it can still be requested.
3. If user taps "Skip": set `skipUntil = now + 259200` (3 days). Show again after 3 days.
4. If user taps "Accept": call `pushService.requestPermission()` → system dialog appears.
5. If system dialog denied: can't show again (Android OS restriction). No retry.

### shouldShowNotificationScreen() logic (in StorageService):
```dart
bool shouldShowNotificationScreen() {
  if (isNotificationGranted()) return false;        // already granted
  if (isNotificationOsDenied()) return false;       // OS denied — can't request again
  final skipUntil = getNotificationSkipUntil();
  if (skipUntil == null) return true;               // first time
  return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= skipUntil;
}
```

### ⚠️ ВАЖНО: флаг OS-denied (обязательно реализовать)

**Проблема:** Если пользователь нажал "Запретить" в системном диалоге, Android больше не покажет диалог запроса разрешений. Однако без флага `notification_os_denied` через 3 дня (после истечения `skipUntil`) `shouldShowNotificationScreen()` снова вернёт `true` и экран появится, хотя нажатие "Accept" ничего не даст — системный диалог просто не откроется.

**Обязательная реализация в `requestPermission()`:**
```dart
if (status == AuthorizationStatus.denied) {
  await _storage.setNotificationOsDenied(); // never show again
}
```

**Требуется в StorageService:**
- `static const _keyNotificationOsDenied = 'notification_os_denied';`
- `bool isNotificationOsDenied() => _prefs.getBool(_keyNotificationOsDenied) ?? false;`
- `Future<void> setNotificationOsDenied() => _prefs.setBool(_keyNotificationOsDenied, true);`

### Push URL routing (per TZ — CRITICAL DISTINCTION):

| Scenario | Method | Action |
|----------|--------|--------|
| App KILLED, user taps push | `getInitialMessage()` at boot | SAVE url to storage via `setPushUrl()` |
| App BACKGROUNDED, user taps push | `onMessageOpenedApp` | Call `onNotificationUrl` callback (NOT saved) |
| App FOREGROUNDED, push arrives | `onMessage` → local notification shown → tap → `onDidReceiveNotificationResponse` | Call `onNotificationUrl` callback (NOT saved) |

The "do not save on warm tap" rule exists because: saved URL persists across sessions, but the spec says push URLs are one-time — on next launch the app should use the config URL, not the push URL.

### Android 13+ permission (API 33+)

Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

This is required for the system permission dialog to appear. Without it, `requestPermission()` is silently ignored on API 33+.

### Notification channel

Create in `_initLocalNotifications()`:
```dart
await androidPlugin?.createNotificationChannel(
  const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.high,
  ),
);
```

Must match AndroidManifest meta-data:
```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="high_importance_channel" />
```

---

## Screen Layout: SplashScreen (Loading)

The splash / loading screen is the **only** screen shown during the
attribution + config fetch pipeline. It must feel like the app is doing
real work — a static logo is not enough. Two elements are mandatory:

1. An animated **"Loading"** caption with cycling trailing dots.
2. An animated **loading bar** that starts at `0` and reaches the far
   right edge at the exact moment routing decides the next screen.

Both must adapt to portrait and landscape.

### Portrait layout (bottom-anchored stack)

- Logo / hero art — centered, ~35 % from top; static image or looping video.
- "Loading . . ." caption — centered, bottom offset ≈ `size.height * 0.22`;
  18 sp semi-bold white, letterSpacing 1.5, opacity 0.9.
- Loading bar — width `size.width - 2*32dp`, height 6 dp, radius 3 dp, bottom
  offset ≈ `size.height * 0.14`; track white 15 %, fill gold gradient
  (#FFCC00 → #FF9900), optional soft glow.

### Landscape layout

- Logo — shrinks to ≈ `size.height * 0.35`, centered.
- "Loading . . ." caption — centered, bottom offset ≈ `size.height * 0.20`.
- Loading bar — width ≈ `size.width * 0.60`, centered, bottom offset ≈
  `size.height * 0.10`.

### "Loading . . ." caption animation

- Base text: the literal word `Loading` (localise only if the brief
  explicitly requires it — most gray-flow builds keep it English).
- Trailing dots cycle through: `""`, `"."`, `". ."`, `". . ."`, then wrap.
- Each frame lasts **400 ms** (full cycle 1600 ms). Use
  `AnimationController(duration: Duration(milliseconds: 1600))` with
  `IntTween(begin: 0, end: 4)` on `.round()`; rebuild only the dots slice
  via `AnimatedBuilder`, do NOT rebuild the whole tree.
- Do not fade dots individually — a monospaced/steady step is what the
  design asks for.

### Loading bar animation — timing contract

The loading bar is the *heartbeat* of the boot sequence. Users perceive
its speed as "how fast the app is", so its length must **always** map to
the real time until routing:

- Start `progress = 0.0` at the first frame of `SplashScreen.build()`.
- End `progress = 1.0` at the exact frame we call
  `Navigator.pushReplacement` into the next screen.
- Never let the bar reach `1.0` early and freeze — that reads as a hang.
- Never jump backwards.

Recommended implementation (two-phase driver):

1. **Estimated phase.** From splash start until `remoteApi.fetchRemote()`
   returns, drive `progress` on a `Tween(0.0 → 0.90)` with
   `Curves.easeOutCubic` and `duration = AppSettings.expectedBootMs`
   (default `4000 ms`, tuneable per project). Cap at `0.90` — never
   exceed while the network call is still in flight.
2. **Finalise phase.** The moment the fetch completes (success OR
   failure) AND connectivity + attribution are resolved, animate from
   the current value to `1.0` over `250 ms` with `Curves.easeInOut`,
   then push the next route on the animation's `.completed` status.
3. If the boot pipeline exceeds the estimate, the bar has already
   easeOut'd near `0.90` — that's the desired "almost there" feel. Do
   NOT restart the tween, do NOT jitter, just wait.

Never tie the bar to `WebView.onPageFinished` — that page belongs to
`ContentScreen`, not the splash.

### Key measurements

- Bar height: `6 dp` portrait, `5 dp` landscape
- Bar horizontal margin: `32 dp` portrait, `size.width * 0.20` landscape
- Caption gap above bar: `16 dp` portrait, `12 dp` landscape
- Background: solid brand color OR muted looping video — must not
  contain UI chrome, buttons, or clickable regions
- No AppBar, no BottomNavigationBar, no system status bar tint changes
  (keep whatever the theme applies globally)

### Behavior invariants

- Splash must be non-interactive. `IgnorePointer` wraps the whole tree.
- Back button does nothing during splash — override with
  `PopScope(canPop: false)`.
- If the fetch fails and connectivity is still up, splash must transition
  into the routing decision (`AppMode.offline` → game or, on first
  launch retry from No-Wi-Fi, ContentScreen with the fresh URL) —
  **never loop back to another splash cycle**.
- Landscape rotation mid-splash must not restart the progress — use a
  single `AnimationController` bound to `State`, not to build context.

---

## Screen Layout: NotificationPermissionScreen

### Portrait layout

Full-screen, no AppBar / system bars. Looping muted video background
(`BoxFit.cover`); Accept button + a subdued Skip link stacked at the bottom.

Key measurements (current implementation):
- Accept button: `left/right = size.width * 0.08`, `bottom = size.height * 0.07`
- Skip link: 18dp below Accept
- Accept uses gold gradient (#FFCC00 → #FF9900), border-radius 50, glow animation
- Skip uses white text, animated opacity on press

### Landscape layout

Same full-screen video; Accept + Skip centered at the bottom (narrower).

Key measurements (current implementation):
- Both buttons centered horizontally (left: 0, right: 0)
- Accept width: `size.width * 0.32`
- Positioned from bottom: `size.height * 0.06`
- Both buttons use `compact: true` (smaller padding)

### Button animation details
- Accept: AnimationController pulsing glow (0.35→0.75 alpha, 900ms, repeat+reverse)
- Accept: Scale 0.96 on press (AnimatedScale, 80ms)
- Skip: AnimatedOpacity 0.85→0.5 on press (80ms)
- Both: GestureDetector (onTapDown/Up/Cancel) instead of InkWell for better control

---

## Screen Layout: NoInternetScreen

### Portrait layout

`SafeArea` + centered `Column`: pulsing amber `wifi_off_rounded` icon (52 dp
in a 100×100 circle), "No Internet Connection" title (22 sp bold white), a
subtitle (15 sp, white 50 %), then a full-width Retry button.

Key measurements:
- Horizontal padding: 36dp
- Icon container: 100×100, circle shape
- Gap icon → title: 32dp
- Gap title → subtitle: 12dp
- Gap subtitle → button: 48dp
- Button height: 54dp, full width, border-radius 16

### Retry button states:
- **Normal:** Gold gradient + glow shadow
- **Retrying:** Amber 30% opacity fill, no gradient, spinner + "Connecting..." text
- Press animation: AnimationController 1.0→0.94 scale, 120ms (ScaleTransition)
- Guard: `_isRetrying = true` to prevent double-taps

### No landscape override needed:
This screen uses `SafeArea` + `Column(mainAxisAlignment: center)` which
naturally adapts to landscape. No separate landscape layout required.

---

## Android-Specific Bugs & Fixes

### 1. Keyboard covers inputs in WebView

**Symptom:** User taps an email/password field in the WebView. The keyboard appears but the input stays hidden behind it.

**Three-layer fix (ALL three are required):**

**Layer 1 — `AndroidManifest.xml`:**
```xml
android:windowSoftInputMode="adjustResize"
```
NOT `adjustPan` — pan shifts the entire window including status bar.

**Layer 2 — Scaffold:**
```dart
Scaffold(resizeToAvoidBottomInset: false, ...)
```
With `adjustResize` in Manifest, Flutter must NOT also resize. Conflict causes layout fights.

**Layer 3 — JavaScript injection (`_injectKeyboardScrollFix` in ContentScreen):**
- Uses `visualViewport.resize` event (more reliable than `window.onresize`)
- `scrollIntoView({ behavior: 'auto' })` — NOT smooth (see bug #3)
- Single `setTimeout(doScroll, 350)` — NOT 3× at 250/500/800ms

### 2. Status bar shows in portrait WebView

**Symptom:** A colored status bar band is visible at the top of the WebView in portrait mode.

**Fix in `ContentScreen.build()`:**
```dart
Padding(
  padding: EdgeInsets.only(
    top: MediaQuery.of(context).orientation == Orientation.landscape
        ? 0
        : MediaQuery.of(context).viewPadding.top,
  ),
  child: WebViewWidget(controller: _controller),
)
```
Applies status bar height as padding in portrait, removes it in landscape (immersive).

### 3. Keyboard visibly jumps when focusing inputs (jitter)

**Symptom:** Keyboard animates up, then jerks again. Happens randomly. "Reinstall fixes it temporarily."

**Two independent root causes — both must be fixed:**

**Cause A:** `scrollIntoView({ behavior: 'smooth' })` fires during keyboard animation.
Two animators (keyboard + smooth scroll) run concurrently → compositor conflict → jump.
```javascript
// ❌ Wrong
el.scrollIntoView({ behavior: 'smooth', block: 'center' });
// ✅ Correct
el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
```

**Cause B:** `setInterval(apply, 2500)` in `_injectSiteAreaKill` patches `viewport-fit` meta
while keyboard is visible → forces WKWebView layout recalc mid-animation.
```javascript
// ✅ Add guard
function kbOpen() {
  if (!window.visualViewport) return false;
  return window.visualViewport.height < window.innerHeight * 0.75;
}
function apply() {
  if (kbOpen()) return; // skip during keyboard
  // ... rest unchanged
}
```
Note: On Android this is less common than iOS but can occur on some OEM WebViews.

### 4. Too many redirects loop

**Symptom:** Affiliate site does a redirect chain. WebView shows error after 20+ redirects.

**Fix (in `ContentScreen` NavigationDelegate):**
```dart
onWebResourceError: (error) {
  final desc = error.description.toLowerCase();
  if (desc.contains('too_many_redirects') || error.errorCode == -1007) {
    if (_lastRedirectUrl != null && _redirectRetryCount < 3) {
      _redirectRetryCount++;
      _controller.loadRequest(Uri.parse(_lastRedirectUrl!));
      return;
    }
  }
  _checkAndShowNoInternet();
},
```
Track `_lastRedirectUrl` in `onNavigationRequest` for `isMainFrame` requests.

### 5. Safe-area white bars on notched Android

**Symptom:** White or dark horizontal band at top/bottom of WebView content. Varies by device.

**Fix:** `_injectSiteAreaKill()` in `ContentScreen.onPageFinished`:
- Sets all `--safe-area-inset-*` CSS variables to `0px !important`
- Sets `viewport-fit=contain` in viewport meta
- Re-applies on SPA route changes (pushState/replaceState/popstate)
- Safety net: `setInterval(apply, 2500)` for lazy-loaded sites

### 6. Videos don't autoplay in WebView

**Symptom:** Videos on the casino/affiliate site require a tap to start, or show a play button overlay.

**Fix in `_configurePlatform()`:**
```dart
androidController.setMediaPlaybackRequiresUserGesture(false);
```

If still not working, inject JS after `onPageFinished`:
```javascript
document.querySelectorAll('video').forEach(v => {
  v.muted = true; v.defaultMuted = true;
  v.setAttribute('playsinline', '');
  v.play().catch(() => {});
});
```

### 7. Firebase App Check blocks requests in debug mode

**Symptom:** Config endpoint returns 403. Works on real device but not on emulator.

**Fix in `main.dart`:**
```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: kDebugMode
      ? AndroidProvider.debug    // emulator/debug
      : AndroidProvider.playIntegrity,  // release
);
```
Also add the debug token from Firebase Console → App Check → Apps → {your app} → Manage debug tokens.

### 8. Gradle build fails with AccessDeniedException

**Symptom:** `flutter build` or `flutter clean` fails with "Access is denied" on Windows.

**Fix:** Stop the Gradle daemon before cleaning:
```powershell
cd android; .\gradlew.bat --stop; cd ..; flutter clean; flutter pub get
```

### 9. FCM token is null at first launch

**Symptom:** `push_token` is empty in the config request body. Push notifications don't work.

**Cause:** `getToken()` is called before FCM is fully initialized (race condition on first launch).

**Fix:** `pushService.init()` is called early in `_run()`. The token is stored in `_token` field. If still null when `buildRequestBody()` is called, **omit both `push_token` and `firebase_project_id` keys entirely** — do not write `null` or `""` (see §"Config Request Contract" §3, §5). The token will be sent on next launch or on token refresh.

For token refresh: register `pushService.onTokenRefresh = _onPushTokenRefresh` to **immediately** re-POST the full config request when the token rotates. This is the only supported recovery path — never poll `getToken()` in a loop.

### 10. `adjustResize` + `resizeToAvoidBottomInset: true` causes layout glitch

If you accidentally set `resizeToAvoidBottomInset: true` in ContentScreen's Scaffold,
Flutter will try to shrink the WebView when the keyboard appears, while Android also
does `adjustResize`. The WebView receives two resize signals and content jumps.
**Fix:** Always `resizeToAvoidBottomInset: false` in ContentScreen.

---

## Obfuscation: What to Hide

### Safe to hide (do it)

| What | Where | How |
|------|-------|-----|
| Config endpoint domain | `net_info.dart` | XOR byte array via `d()` |
| AppsFlyer Dev Key | `analytics_info.dart` | XOR byte array via `d()` |
| Firebase project number | `analytics_info.dart` | XOR byte array via `d()` |
| Chrome/WebKit UA fragments | `http_client.dart` | XOR byte array via `d()` |
| Log statements | All services | Wrap in `if (kDebugMode)` |
| Class names with intent | Rename per project | See Code Mixing section |
| `webview`, `betting`, `casino` in route names | Use neutral names | `/content`, `/reader` |

### Do NOT hide (breaks functionality)

| What | Why |
|------|-----|
| `INTERNET` permission in Manifest | App can't make HTTP requests |
| `POST_NOTIFICATIONS` permission | System push dialog never appears on API 33+ |
| FCM channel meta-data | Push notifications silently dropped |
| `adjustResize` in Manifest | Keyboard covers inputs |
| `google-services.json` | Firebase fails to initialize |
| `FirebaseAppCheck.activate()` | All API requests rejected (403) |

---

## Code Mixing: Mandatory Per-Project Changes

**Never ship two apps with the same folder names, class names, or codec seed.**
Stores scan for cross-submission structural patterns.

### Minimum changes per project

1. **Codec seed** — change `parts` array in `lib/utils/codec.dart`
2. **Library versions** — use different versions from the ranges in pubspec.yaml
3. **Class names** — rename at least `AppsFlyerService`, `RemoteService`, `StorageService`, `ContentScreen`, `SplashScreen`
4. **Folder names** — rename `lib/services/` to e.g. `lib/core/`, `lib/network/`; `lib/config/` to `lib/env/` or `lib/setup/`
5. **File names** — rename `content_screen.dart`, `splash_screen.dart`, etc.

See the full Code Mixing section in `gray_flow_guide.md` for all options and example mappings.

### Build obfuscation

Always build release with:
```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug_info
```

`--obfuscate` renames Dart symbols. Keep `build/debug_info` local — never commit.

---

## Library Versions Reference

Recommended pins as of the current template revision (2026). These are
the versions the template is actively tested against — see
`gray_part_pitfalls.md` §19 for the absolute minimum floors and the
reasoning behind each attribution-SDK pin.

```yaml
dependencies:
  # ── Attribution & push stack — do NOT downgrade (see pitfalls §19)
  appsflyer_sdk: ^6.18.0            # min 6.16.0
  firebase_core: ^4.11.0            # min 3.13.0
  firebase_messaging: ^16.4.0       # min 15.2.0
  firebase_app_check: ^0.4.5        # min 0.3.2+10
  flutter_local_notifications: ^22.0.1  # min 18.0.0
  flutter_secure_storage: ^10.3.1   # min 10.0.0

  # ── Rest of the stack — stagger minor versions per project
  connectivity_plus: ^7.1.1
  http: ^1.6.0
  device_info_plus: 11.4.0
  shared_preferences: ^2.5.5
  webview_flutter: ^4.14.0
  webview_flutter_android: ^4.13.0
  url_launcher: ^6.3.2
  # video_player / file_picker / package_info_plus — add only if used
  # (file_picker MUST stay <= 8.x — see pitfalls §1)
```

**Per-project diversification:** Stagger minor versions between projects
by bumping WITHIN or ABOVE the recommended pins — never below. Check
pub.dev for the latest compatible releases at project start and prefer
the newer one. Downgrading Firebase or AppsFlyer to "match some other
example" is the single most common cause of Organic-vs-Non-Organic
misclassification on this template (§pitfalls §19).

---

## Testing Guide

### Test the tracking link (non-organic install)

To simulate a paid install and see the WebView:
1. Add your device's GAID to AppsFlyer Test Devices list
2. Click this link on the test device BEFORE installing:
```
https://app.appsflyer.com/{bundleId}?pid=Test%20Source&c=testsub_testsub2_testsub_testsub_testsub_testsub_testsub_testsub1%20%23extra&siteid=test&adset=testsub&af_adset=testsub3&af_c_id=testsub4&agency=Test%20Agency&af_sub1=testextra2&af_sub2=testextra3&af_sub3=testextra4&af_sub4=testextra5&af_sub5=testextra6&is_retargeting=true
```
Or use a OneLink with equivalent params.
3. Install the app
4. Expected: WebView opens with the config URL

### Test organic install (game)

Install WITHOUT clicking a tracking link first.
Expected: Game screen, no push permission, no WebView.

### Test offer URL

Use `https://web.team-s.club/` as the WebView content during testing.
This is a test resource that partially validates WebView behavior and app logic.

### Test push notifications

Can only be tested with a Firebase configuration that has push sending capability.
Use the Firebase Console → Cloud Messaging → Test message.
Push token must be in the config request (check debug logs: `[AppsFlyerService] Request body`).

### Check attribution logs

In debug builds, `[AppsFlyerService]` logs:
- `onInstallConversionData:` — raw attribution payload
- `GCD retry data:` — GCD response (only if first response was Organic)
- `Request body:` — final merged body sent to config endpoint

---

## App Requirements (per TZ)

| Requirement | Value |
|------------|-------|
| Target SDK | 35 |
| Min SDK | 30 |
| App size | < 30 MB (100+ MB is unacceptable) |
| Privacy policy | Must be accessible (URL in game + WebView info screen) |
| Loading screen | Must adapt to portrait AND landscape |
| Push promo screen | Must adapt to portrait AND landscape |
| Loading time | < 10 seconds on normal internet speed |
| Adaptive icon | Must fill the icon shape, no empty borders, no clipping |
| Notification icon | Separate monochrome icon (NOT the launcher icon) |
| Push images | Must be supported (BigPictureStyleInformation) |

---

## Common Errors Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| `FormatException: Invalid HTTP header field value` | Byte arrays generated with PowerShell | Use `dart run tool/encode_keys.dart` |
| Config returns 403 | Firebase App Check not configured | Set `androidProvider: kDebugMode ? debug : playIntegrity` |
| Push token null | FCM init race condition | Token sent on next launch or refresh — normal on first run |
| WebView blank on organic | No URL returned — correct behavior | Game should show instead |
| Keyboard hides inputs | Missing one of the three keyboard layers | Apply all three: `adjustResize` + `resizeToAvoidBottomInset:false` + JS inject |
| White bar in WebView | Safe-area CSS not overridden | Check `_injectSiteAreaKill()` fires on `onPageFinished` |
| Videos need tap to play | `setMediaPlaybackRequiresUserGesture` not called | Call in `_configurePlatform()` for Android |
| App crashes on `flutter clean` Windows | Gradle daemon holds file locks | Run `gradlew.bat --stop` first |
| Push shows no image | Missing BigPictureStyleInformation | Check `_handleForegroundMessage` image download |
| Attribution always Organic | GCD retry not implemented | Implement `_refreshAttribution()` in AppsFlyerService |
