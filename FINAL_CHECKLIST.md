# FINAL CHECKLIST — Pre-Release Verification

> Run through this **on a real Android device** before every
> submission. Every item is either a `.cursor/rules/…` invariant,
> a store-review requirement, or a fingerprint-safety rule. If any
> single line fails, the build is not shippable.
>
> The forge (`dart run tool/forge/mint.dart`) automates roughly
> half of Part A. The rest is a manual sweep — verify each entry.
>
> Fill in the checkboxes in the release ticket.

---

## Part A — Fingerprint safety (must differ from every prior project)

### A.1 — Forge outputs

- [ ] `forge.lock` is present at the repo root and its `codecFamily`
      is **different** from the last shipped sibling
      (`.cursor/rules/portfolio_registry.md` §"Values that MUST
      rotate")
- [ ] `dart run tool/forge/mint.dart --dry-run` reports zero
      collisions against `..\portfolio.json`
- [ ] `portfolio.json` was appended by the last full mint (not a
      dry-run)
- [ ] Codec family, salt, and stream length differ from the previous
      project (`forge.lock`)
- [ ] `lib/relay/codec/veil_codec.dart` and
      `lib/relay/config/veiled_bytes.dart` are forge-generated (do
      NOT hand-edit)

### A.2 — Identity

- [ ] `lib/relay/config/relay_config.dart` — `applicationId`,
      `marketId`, `displayName` unique to this project (no
      `template`, no reused slug from any shipped sibling)
- [ ] `lib/relay/config/legal_urls.dart` — three URLs unique to
      this project (own domain or dedicated path)
- [ ] `pubspec.yaml` — `name:` unique, `description:` describes the
      WHITE game only (no "template" / "webview" / "partner")
- [ ] `pubspec.yaml` — `version` bumped from any previous store
      submission
- [ ] `android/app/build.gradle.kts` — `applicationId` + `namespace`
      match `RelayConfig.applicationId`
- [ ] `android/app/src/main/kotlin/**/MainActivity.kt` — package
      declaration + folder path match `applicationId`
- [ ] `AndroidManifest.xml` — `android:label` = `RelayConfig.displayName`
- [ ] `AndroidManifest.xml` — `default_notification_channel_id` value
      matches `kAlertChannelId` in `lib/relay/wire/alert_channel.dart`
- [ ] `AndroidManifest.xml` — OneLink `android:host` = fresh subdomain
      from AppsFlyer dashboard for this project

### A.3 — Storage / channels

- [ ] `_keyPrefix` in `lib/relay/wire/beacon_keystore.dart` is a
      short random ASCII token ending in `_`, unrelated to the app
      slug (`.cursor/rules/relay_forge.md` §"storage")
- [ ] `_keyPrefix` differs from every shipped sibling
- [ ] MethodChannel name in `lib/relay/stage/portal_stage.dart`
      matches the `channelName` in
      `android/app/src/main/kotlin/**/MainActivity.kt`
- [ ] Both differ from the template's default (`relay/upload`)

### A.4 — Timing constants (see `RelayConfig` ranges)

- [ ] `permissionSnoozeSeconds` in 172800..604800, non-round
- [ ] `organicRescueDelay` in 4..12
- [ ] `verdictTimeoutSeconds` in 10..25
- [ ] `firstInstallAwaitSeconds` in 20..40
- [ ] `returningInstallAwaitSeconds` in 3..10
- [ ] `deepLinkAwaitSeconds` in 3..8
- [ ] `reachProbeTimeoutSeconds` in 4..9
- [ ] `reachDropDebounceMs` in 500..1200
- [ ] `redirectLoopRetries` in 1..5
- [ ] `cachedUrlLifetimeSeconds` in 259200..1209600
- [ ] Each timing value differs by ≥ 10 % from every shipped sibling

### A.5 — Assets

- [ ] `lib/app_assets.dart` — `_extra` folder segment renamed
      (default `SkywardTowers_additional_assets_webp` is a
      fingerprint — see `custom_screens.md` §5)
- [ ] `assets/<addon>/` — folder renamed on disk + registered in
      `pubspec.yaml` `flutter.assets`
- [ ] `assets/<addon>/` — all six screen backgrounds replaced
      (portrait + landscape × loading / no-wifi / notifications)
- [ ] `res/drawable/ic_notification.xml` — new vector, silhouette
      DIFFERENT from the launcher icon (see `custom_screens.md` §4)
- [ ] `assets/generated/app_icon*.png` — new adaptive icon
      regenerated via `dart run flutter_launcher_icons`

### A.6 — External infrastructure (not tracked by forge)

- [ ] `android/app/google-services.json` — real file present (not
      the `.example`), `package_name` matches `applicationId`
- [ ] Firebase project number in `google-services.json` matches
      the encoded `messagingProjectId` in `veiled_bytes.dart`
- [ ] `android/key.properties` present + new keystore for this
      project (never reused)
- [ ] `versionCode` bumped from any previous store submission
- [ ] Play Console developer account is the one assigned to this
      portfolio slot (not a shared account)

---

## Part B — First-launch UX contract (Wi-Fi + OneLink scenario)

Test on a fresh device. Uninstall any prior build first.

- [ ] Add device GAID to AppsFlyer Test Devices before starting
- [ ] Tap the test OneLink (append `&advertising_id=<GAID>`)
- [ ] **Disable Wi-Fi and mobile data** before installing
- [ ] Install the APK / AAB
- [ ] Open the app — frame ONE shows the loading art then rapidly
      transitions to the offline screen on connectivity failure
- [ ] Portrait background is `Vertical_Nowifi_Screen.webp`,
      landscape is `Horizontal_Nowifi_Screen.webp`
- [ ] Rotate device on the offline stage — background swaps
      correctly, Retry stays anchored
- [ ] Enable Wi-Fi
- [ ] Tap **Retry** — app transitions into the loading screen
      (`BootScreen`)
- [ ] Loading bar grows monotonically, reaches 1.0 at the exact
      moment the next surface takes over — no freeze at 100 %, no
      jump backwards
- [ ] `PermissionStage` appears BEFORE the WebView (first non-organic
      launch only)
- [ ] Accept → system dialog appears
- [ ] After grant, `PortalStage` opens on the verdict URL
- [ ] Kill the app, relaunch → `PortalStage` reopens directly (cache
      path), no loading longer than ~2 s
- [ ] With `af_status: "Organic"` in conversion data → native game
      opens; no gray content leaks through

---

## Part C — Store-review requirements

### C.1 — Test tracking link

- [ ] Test tracking link ends with `&advertising_id=<GAID>` for the
      device being used
- [ ] Device GAID added to AppsFlyer Test Devices list

### C.2 — Deep link parameters

- [ ] OneLink created on the **dedicated** AppsFlyer account (not
      the shared one)
- [ ] Deep-link install populates `deep_link_value`,
      `deep_link_sub*`, `match_type`, `is_deferred` fields in the
      verdict request body (check `[VerdictCall]` debug log in a
      debug build)

### C.3 — Test offer resource

- [ ] The partner offer URL from the recipe loads cleanly in
      `PortalStage`
- [ ] All flows on that resource (login, form, upload, redirect,
      external app hand-off) work without visible errors

### C.4 — App size

- [ ] Release APK / AAB **< 100 MB**
      (`Get-Item build\app\outputs\**\*.apk`)
- [ ] Ideally < 30 MB — investigate if larger

### C.5 — Privacy policy

- [ ] `RelayConfig` / `legal_urls.dart` `privacyUrl` loads a real,
      permanent page (not 404 / "coming soon")
- [ ] Menu screen "Privacy Policy" opens it in the internal info
      WebView
- [ ] Same URL is registered in the Play Console listing

### C.6 — API levels

- [ ] `android/app/build.gradle.kts` targetSdk = **35**,
      compileSdk = **36**, minSdk = **26**
      (see `gray_part_pitfalls.md` §19)
- [ ] Builds without `flutter_plugin_android_lifecycle` compileSdk
      complaints
- [ ] Firebase / AppsFlyer versions at or above the recommended
      pins in `gray_part_pitfalls.md`

### C.7 — Adaptive icon

- [ ] Launcher icon fills the mask on Pixel Launcher preview — no
      empty borders, no clipping
- [ ] Icon crisp at both 48 dp and 108 dp
- [ ] Foreground artwork sits inside the 66 % safe zone
- [ ] Adaptive background is a full-bleed PNG (solid or gradient)
- [ ] Cold-start splash shows NO white / grey rectangle around the
      icon
- [ ] Test after `adb shell pm clear <launcher_package>` — the
      icon still looks correct on a cleared cache

### C.8 — Loading screen

- [ ] Animated "Loading…" caption + animated progress bar
- [ ] Progress bar 0 → 100 % synced with real boot time
- [ ] Portrait AND landscape orientations both look correct
- [ ] Total boot time on normal Wi-Fi < 10 s

### C.9 — Push permission screen

- [ ] Shown BEFORE the WebView on the first entry into gray mode
- [ ] Portrait AND landscape backgrounds correct
- [ ] Accept → system dialog appears
- [ ] Skip → screen hidden for exactly `permissionSnoozeSeconds`
- [ ] System-level deny → screen never shown again (OS-denied
      flag set in `BeaconKeystore.markPermissionBlockedByOs`)
- [ ] All three scenarios manually tested
- [ ] Buttons visible on the darkest region of both backgrounds
- [ ] Button labels centered, no baseline drift

### C.10 — Portal (WebView) launch

- [ ] With `af_status: "Non-organic"` in conversion data →
      `PortalStage` opens
- [ ] With `af_status: "Organic"` → native game opens

### C.11 — User-Agent (see `.cursor/rules/gray_user_agent.mdc`)

- [ ] Contains a current Chrome major and current WebKit fragment
- [ ] Contains a real Android model / build id sourced from
      `device_info_plus` — not hardcoded
- [ ] Does NOT contain `Dart`, `Flutter`, `WebView`, `wv/`, or
      any package name / SDK identifier
- [ ] Same UA on the HTTP client (`relayAgent`) AND on the WebView
      (`_web.setUserAgent(...)` in `portal_stage.dart`)
- [ ] `rg -n 'Mozilla/5\.0|Linux; Android|AppleWebKit|Mobile Safari|like Gecko' lib`
      returns ZERO hits (all UA fragments encoded)
- [ ] Slot game? UA ends with `appid/<applicationId> appname/<AppName>`
      built from encoded fragments — no plaintext `appid/` string
- [ ] Crash game? UA does NOT contain the appid/appname suffix
- [ ] Category decision documented in `device_signature.dart`

### C.12 — WebView within safe area

- [ ] Portrait: WebView not covered by camera notch / punch-hole
- [ ] Landscape: WebView respects side cutout — no button under
      camera; verify on BOTH long edges (rotate 180° and check
      again)
- [ ] Bottom of WebView reaches the bottom edge (no unnecessary
      inset)
- [ ] Cutout tested on: boot screen, permission stage, offline
      stage, portal stage — all four must pass in landscape on a
      device with a side camera / notch
- [ ] Partner site's horizontal gutters look identical to Chrome
      (see `webview_safe_area_injection.mdc` — no over-reach on
      the CSS injection)

### C.13 — Screen rotation

- [ ] Auto-rotate works on boot / offline / permission / portal
- [ ] `SystemChrome.setPreferredOrientations` allows all four
      values at boot; only the game path re-locks to portrait

### C.14 — Back navigation

- [ ] Android back gesture → WebView goes one page back
- [ ] `_web.canGoBack()` returns false on the first page → back
      gesture does NOTHING (WebView is not closed)
- [ ] No exit-app dialog fires from back on the first page

### C.15 — Too-many-redirects recovery

- [ ] Up to `redirectLoopRetries` automatic retries, then graceful
      load of the last known URL
- [ ] No `ERR_TOO_MANY_REDIRECTS` error page ever shown to user

### C.16 — JavaScript enabled

- [ ] `setJavaScriptMode(JavaScriptMode.unrestricted)` on the WebView
- [ ] Payment gateways / OAuth pop-ups render normally

### C.17 — Cookies

- [ ] `AndroidWebViewCookieManager.setAcceptThirdPartyCookies(_, true)`
- [ ] Login persists across page reloads

### C.18 — Inline autoplay video

- [ ] `setMediaPlaybackRequiresUserGesture(false)` set
- [ ] Video on test resource plays inline without tap-to-start

### C.19 — Protected Media (DRM)

- [ ] `setOnPlatformPermissionRequest((r) => r.grant())` wired
- [ ] DRM-protected streams play without permission modals

### C.20 — Parameter forwarding to the verdict endpoint

- [ ] Verdict request body contains all seven device-side fields:
      `af_id`, `bundle_id`, `os`, `store_id`, `locale`,
      `push_token`, `firebase_project_id` (unless FCM not
      initialised — then the last two are OMITTED, never null)
- [ ] Every field from `onInstallConversionData` passed through
      verbatim
- [ ] `os` value is exactly `"Android"`
- [ ] `locale` in RFC 3066 format (`en`, `en_US`, `ru`, …)

### C.21 — File upload

- [ ] Site `<input type="file">` opens the native chooser
- [ ] Camera + gallery both offered
- [ ] Picked file uploads successfully
- [ ] No app-wide filesystem permission dialog appears

### C.22 — Keyboard does not cover inputs

- [ ] Focused input scrolls above the keyboard
- [ ] No jitter, no double-jump

### C.23 — Push notifications

- [ ] Test push from Firebase Console shows on the device
- [ ] Notification uses the `ic_notification` icon
- [ ] Notification icon silhouette DIFFERENT from the launcher icon
- [ ] Notification shows an image (BigPictureStyleInformation)
- [ ] Cold-start tap → app boots and opens the push URL in the
      in-app WebView (via `InlineBeacon.consume`)
- [ ] `network_security_config.xml` base-config has
      `cleartextTrafficPermitted="true"` — partners routinely send
      HTTP push URLs; a "false" base breaks every cold-start tap
      silently
- [ ] Warm tap → live URL loaded, NOT persisted
- [ ] On the next launch after a cold-start push, the standard
      verdict cache is used (push URL is one-time)
- [ ] Test all three states: app killed / backgrounded /
      foregrounded — each opens the push URL in-app without error

### C.24 — Deep links inside WebView

- [ ] `tel:` / `mailto:` / `intent://` / `whatsapp://` / `tg://`
      links open the corresponding system app
- [ ] After the external app opens, returning to our app shows the
      previous WebView page — not an error state

---

## Part D — Backend contract (spot-check via debug logs)

- [ ] Verdict request logged (debug builds only, `assert`-wrapped)
- [ ] Body is a **flat** JSON object (no nested attribution key)
- [ ] Response 200 → cached URL written to secure storage; cached
      expiry written to prefs
- [ ] Response `{ok:false}` on first launch → `RouteMemory.native`
      persisted; no subsequent verdict fires this install
- [ ] Cached URL respected on returning launch — cached loaded when
      still valid, refetch when expired
- [ ] Token refresh (`AlertChannel.onTokenChanged`) triggers a
      fresh verdict POST

---

## Part E — Build hygiene (Windows / Gradle / 16 KB pages)

- [ ] `cd android; .\gradlew.bat --stop; cd ..` before every clean
- [ ] `Remove-Item android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java`
      + `flutter pub get` after any plugin change
- [ ] Release build:
      `flutter build apk --release --obfuscate --split-debug-info=build\debug_info`
- [ ] `--split-debug-info` output NOT committed to git
- [ ] `google-services.json` NOT committed (only `.example`)
- [ ] `key.properties` NOT committed
- [ ] `tool/forge/recipe.json` NOT committed (has plaintext secrets)
- [ ] `forge.lock` committed (identifying tuple only, no secrets)
- [ ] **16 KB page-size support** (Android 15+):
      - [ ] Flutter 3.29+ (`flutter --version`)
      - [ ] Android Gradle Plugin 8.5.2+ in
            `android/settings.gradle.kts`
      - [ ] NDK 27+ pinned in `android/app/build.gradle.kts`
      - [ ] `adb shell getconf PAGE_SIZE` returns `16384` on the
            test emulator / device
      - [ ] App launches without SIGSEGV on a 16 KB device

---

## Part F — Store submission

- [ ] Play Console listing description does NOT reference the
      WebView or the partner site
- [ ] Screenshots show the native game only
- [ ] Privacy Policy URL live before submission
- [ ] Data Safety form declares only what the app actually
      collects (attribution ID, push token, device locale — nothing
      more)
- [ ] `versionCode` bumped from the previous store version

---

## Part G — Forbidden strings (grep gates)

Every one of the greps below must return **zero hits** on
`lib/` for a release-ready build. This is the ultimate sanity
sweep before running `flutter build`.

```powershell
# UA scaffolding — every fragment must be encoded
rg -n 'Mozilla/5\.0|Linux; Android|AppleWebKit|Mobile Safari|like Gecko' lib

# appid/appname plaintext (only ships assembled from encoded fragments)
rg -n 'appid/|appname/' lib

# Partner-site classification vocabulary — client must never classify
rg -n 'deposit|cashier|register|воронк|касс|slot|game_type' lib -i

# Legacy Clarity references
rg -n 'Clarity|Insight|kClarityProjectId|clarity_flutter|AegisInsight' lib

# Legacy naming (means an old migration file survived)
rg -n 'TowerFacade|AppMode|ShellMode|FlowRouter|WebStage|GlassButton|obfuscator' lib

# Template placeholders
rg -n 'com\.example\.template|CHANGE_ME|<FORGE>|skyward_towers' lib android

# Debug logging must be assert-wrapped (stripped in release). Every
# hit below MUST sit inside an `assert(() { ...; return true; }())`
# block — inspect each. A bare print/debugPrint NOT inside an assert
# is a release leak and must be fixed.
rg -n 'print\(|debugPrint\(' lib

# Host allowlists — forbidden (partner URL may change post-release)
rg -n 'allowedHosts|allowedHostSuffixes|domainAllowlist|host\.endsWith' lib
```

If any grep returns hits, STOP. Fix before shipping.

---

## Quick sanity commands

```powershell
Get-Content forge.lock

dart run tool/forge/mint.dart --dry-run --portfolio ..\portfolio.json

flutter analyze

cd android; .\gradlew.bat --stop; cd ..
flutter clean
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build\debug_info
```
