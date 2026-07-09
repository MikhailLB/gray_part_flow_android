# START HERE — Cursor / AI Agent Entry Point

> **Read this file first. Every time you are asked to work on this
> project, read this file, then read every file in `.cursor/rules/`
> before writing any code.**

This project is a **Gray-Part Flow template** for Android (Flutter).
The gray-flow architecture is documented in full in
`.cursor/rules/android_gray_guide.md` — that document is the API
contract, the state machine, and the setup manual. This file is the
short "where to look" index that points into it.

---

## 1. What "gray flow" means (30-second version)

A dual-mode Flutter app:

- **Gray mode** — full-screen WebView loading a URL from a remote
  config endpoint. Non-organic (paid) users see this.
- **White mode** — a native game (`lib/screens/*`, `lib/game/*`).
  Organic users see this. Also what store reviewers see.

The routing decision is made ONCE per install, by the backend, from
AppsFlyer attribution data. It cannot be spoofed client-side.

Detailed doc: `.cursor/rules/android_gray_guide.md` §"What Is the
Gray Flow?".

---

## 2. Where to look for what

| You need to… | Read |
|---|---|
| Understand the whole architecture end-to-end | `.cursor/rules/android_gray_guide.md` (top-to-bottom) |
| Know the exact config-endpoint request / response | `android_gray_guide.md` §"Config Request Contract" |
| Know the boot sequence + state transitions | `android_gray_guide.md` §"Gray Flow State Machine" |
| Handle the OneLink + offline install scenario | `android_gray_guide.md` §"First-Launch UX Contract" |
| Style the loading screen | `android_gray_guide.md` §"Screen Layout: SplashScreen (Loading)" |
| Style the push-permission screen | `android_gray_guide.md` §"Screen Layout: NotificationPermissionScreen" |
| Style the no-internet screen | `android_gray_guide.md` §"Screen Layout: NoInternetScreen" |
| Avoid the ten known Android bugs | `android_gray_guide.md` §"Android-Specific Bugs & Fixes" + `.cursor/rules/gray_part_pitfalls.md` |
| Wire the custom screen backgrounds | `.cursor/rules/custom_screens.md` |
| Configure the WebView safe-area CSS | `.cursor/rules/webview_safe_area_injection.mdc` |
| Set the User-Agent suffix (Zeus/Magma themes) | `.cursor/rules/gray_user_agent.mdc` |
| Verify a release is ready to ship | `FINAL_CHECKLIST.md` (this repo, root) |

---

## 3. Order of operations for a new project (one-shot generation)

You will normally be handed a customer brief. Do it in this order:

1. **Parse the brief against §"Inputs You Need Before Generating"** in
   `android_gray_guide.md`. If any starred (★) input is missing (config
   endpoint, AppsFlyer key, Firebase config, privacy URL, codec seed,
   icons, screen backgrounds), STOP and ask the user in one batched
   question. Do not scaffold with placeholders that silently break.
2. **Refresh the fingerprint.** Every file marked `[FINGERPRINT]` in
   the code (grep for the marker) must be re-diversified for this
   project. See §4 below.
3. **Fill config layer.** In this order:
   - `lib/env/facade.dart` → identity (packageId / marketId / displayName)
   - `lib/env/legal_links.dart` → privacy + support URLs
   - `tool/secret_packer.dart` → paste raw endpoint / AppsFlyer key /
     Firebase project number
   - `lib/crypt/obfuscator.dart` → change `_seedPhrase` +
     `_streamLength` to fresh unique values
   - Run `dart run tool/secret_packer.dart` → paste the six byte
     arrays into `lib/env/secure_strings.dart`
4. **Sync Android identity.** All three MUST match `TowerFacade.packageId`:
   - `android/app/build.gradle.kts` → `applicationId` + `namespace`
   - `android/app/src/main/kotlin/**/MainActivity.kt` → `package` line
     + folder path
   - `android/app/google-services.json` → `package_name`
5. **Replace assets.** See `assets/README.md`. Rename the addon
   folder + swap the six screen webp files + replace launcher icon
   + replace notification vector.
6. **OneLink** — update `<data android:host="…"/>` in
   `android/app/src/main/AndroidManifest.xml` and the `android:label`
   next to it.
7. **Build & smoke-test.**
   - Debug: `flutter run` — verify loading bar reaches ~90 % during
     network wait, hits 100 % at the route switch, no black frames.
   - Release: `flutter build apk --release --obfuscate
     --split-debug-info=build/debug_info`.
8. **QA against `FINAL_CHECKLIST.md`.** Every point must pass on a
   real device before shipping.

---

## 4. Fingerprint — mandatory per-project changes

Everything below MUST differ between projects. Grep for the marker
`[FINGERPRINT]` to find every location — this list mirrors them:

- `lib/crypt/obfuscator.dart` → `_seedPhrase` + `_streamLength`
- `lib/env/facade.dart` → `packageId` / `marketId` / `displayName`
- `lib/env/legal_links.dart` → all three URLs (unique per project)
- `pubspec.yaml` → `name` + `description` + `version`
- `lib/app_assets.dart` → `_extra` folder segment
- `android/app/build.gradle.kts` → `applicationId` + `namespace`
- `android/app/src/main/kotlin/**/MainActivity.kt` → package + folder,
  `channelName` string
- `lib/veil/web_stage.dart` → `MethodChannel('…/upload')` name (keep
  in sync with MainActivity.kt)
- `lib/bridge/push_hub.dart` → `kChannelId` + `kChannelName`
- `AndroidManifest.xml` → `default_notification_channel_id` value +
  `android:host` OneLink + `android:label`
- `assets/<addon_folder>/` → folder rename + artwork swap
- `res/drawable/ic_notification.xml` → new monochrome vector
- Launcher icon (`assets/generated/app_icon*.png`)

**Also** — vary a few plugin minor versions in `pubspec.yaml`
(see `android_gray_guide.md` §"Library Versions Reference"). Do not
copy any version pin exactly from a previous project.

---

## 5. Things that must NEVER break (invariants)

If your changes threaten any of the following, STOP and reconsider —
these are the load-bearing behaviours of the gray flow:

1. **Non-organic + offline install boot** must show the No-Wi-Fi
   screen on FRAME ONE. Retry after enabling Wi-Fi must reach the
   WebView through the normal pipeline (attribution → gate →
   ContentScreen). No black screen, no game screen, no loop.
2. **Loading bar** starts at 0, monotonically increases, hits 1.0 at
   the exact frame we push the next route. Never freezes at 100 %,
   never jumps back.
3. **Loading screen "Loading…" caption** cycles dots on a stable
   1200 ms controller. Both orientations show the correct portrait /
   landscape background.
4. **`AppMode.pending` never commits to `offline` on a network
   failure** — only a successful HTTP `{ok:false}` commits offline.
   Otherwise the app would trap non-organic users into the game
   forever on the first offline install.
5. **On offline commit, no further config requests may be sent** for
   the lifetime of the install. Reinstall is the only reset.
6. **`push_token` + `firebase_project_id` are omitted from the config
   body when FCM is not initialised** — never sent as empty strings
   or `null`.
7. **WebView back gesture / system back** returns one page inside the
   WebView. Back-from-first-page does NOT close the WebView.
8. **File upload input** opens the native chooser (camera + gallery)
   without a filesystem permission dialog.
9. **The AppsFlyer conversion data payload is forwarded verbatim** to
   the config endpoint — no field is renamed, dropped, or added
   except the seven device-side fields defined in the contract.
10. **User-Agent looks like a real Chrome on a real Android device** —
    no `Dart/…` or `Flutter/…` tokens, no `WebView` substring.

For every invariant there is a matching item in `FINAL_CHECKLIST.md`.

---

## 6. When the user asks something you cannot solve here

- The user is on Windows / PowerShell (paths with spaces are common).
  Always use PowerShell syntax when running commands.
- Prefer `dart run tool/…` over ad-hoc PowerShell loops — see the note
  in `android_gray_guide.md` §"Setup Checklist" Step 2 about integer
  overflows.
- If the user asks for iOS work, this template is Android-first;
  double-check with them before touching `ios/` — some rules
  (`store_id` prefix, App Store id) explicitly differ.
- If the user asks you to "make it work like project X", first grep
  project X's `[FINGERPRINT]` markers to know what MUST diverge.
