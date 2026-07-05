# FINAL CHECKLIST — Pre-Release Verification

> Run through this **on a real Android device** before every submission.
> Every item is either a TZ requirement, a `.cursor/rules/…` invariant,
> or a fingerprint-safety rule. If any single line fails, the build is
> not shippable.

Use the checkboxes; fill them in a PR / release ticket.

---

## Part A — Fingerprint safety (must differ from every prior project)

- [ ] `lib/crypt/obfuscator.dart` — `_seedPhrase` changed to a fresh
      opaque ASCII token
- [ ] `lib/crypt/obfuscator.dart` — `_streamLength` changed to a new
      value in 16–48
- [ ] `lib/env/secure_strings.dart` — six byte arrays freshly generated
      by `dart run tool/secret_packer.dart` **after** the seed change
- [ ] `lib/env/facade.dart` — `packageId`, `marketId`, `displayName` all
      unique to this project (no `template`, no reused slug)
- [ ] `lib/env/legal_links.dart` — three URLs unique to this project
      (own domain or dedicated path)
- [ ] `pubspec.yaml` — `name`, `description`, `version 1.0.0+1`
- [ ] `pubspec.yaml` — at least two plugin minor versions differ from
      the previous project
- [ ] `lib/app_assets.dart` — `_extra` folder segment renamed
- [ ] `assets/<addon>/` — folder renamed on disk + registered in
      `pubspec.yaml` `flutter.assets`
- [ ] `assets/<addon>/` — all six screen backgrounds replaced
      (portrait + landscape × loading / no-wifi / notifications)
- [ ] `android/app/build.gradle.kts` — `applicationId` + `namespace`
      match `packageId`
- [ ] `android/app/src/main/kotlin/**/MainActivity.kt` — package
      declaration + folder path match `packageId`
- [ ] `android/app/src/main/kotlin/**/MainActivity.kt` — `channelName`
      renamed; **matches** `MethodChannel(...)` in
      `lib/veil/web_stage.dart`
- [ ] `AndroidManifest.xml` — `android:label` = `displayName`
- [ ] `AndroidManifest.xml` — OneLink `android:host` = fresh subdomain
      from AppsFlyer dashboard for this project
- [ ] `AndroidManifest.xml` — `default_notification_channel_id` value
      matches `kChannelId` in `lib/bridge/push_hub.dart`
- [ ] `res/drawable/ic_notification.xml` — new monochrome vector, NOT
      the launcher icon silhouette
- [ ] `assets/generated/app_icon*.png` — new adaptive icon regenerated
      via `dart run flutter_launcher_icons`
- [ ] `android/app/google-services.json` — real file present (not the
      `.example`), `package_name` matches `applicationId`
- [ ] `key.properties` present + `versionCode` bumped from any
      previous store submission

---

## Part B — First-Launch UX Contract (TZ §"Wi-Fi + OneLink" scenario)

Test this on a fresh device. Uninstall any prior build first.

- [ ] Add device GAID to AppsFlyer Test Devices before starting
- [ ] Tap the test OneLink (append `&advertising_id=<GAID>`)
- [ ] **Disable Wi-Fi and mobile data** before installing
- [ ] Install the APK / AAB
- [ ] Open the app — **frame ONE shows the No-Wi-Fi screen**, not a
      splash, not a black screen, not the Flutter branding
- [ ] Portrait background is `Vertical_Nowifi_Screen.webp`, landscape
      is `Horizontal_Nowifi_Screen.webp`
- [ ] Rotate the device on the No-Wi-Fi screen — background swaps
      correctly, Retry button still positioned properly
- [ ] Enable Wi-Fi
- [ ] Tap **Retry** — app transitions into the loading screen
- [ ] Loading bar starts at 0, grows monotonically, reaches 1.0 at
      the exact moment the WebView takes over — no freeze at 100 %,
      no jump backwards, no restart
- [ ] "Loading…" caption cycles dots on a stable rhythm
- [ ] WebView opens with the config URL — no game screen appears at
      any point (attribution is Non-organic)
- [ ] Kill the app, relaunch → WebView reopens directly (savedUrl
      path), no loading longer than ~2 s

---

## Part C — TZ §"Требования к приложению" (24 points)

### 1. Test tracking link
- [ ] Test tracking link ends with `&advertising_id=<GAID/IDFA>` for
      the device being used
- [ ] Device GAID added to AppsFlyer Test Devices list

### 2. Deep link parameters
- [ ] OneLink created on the **dedicated** AppsFlyer account (not the
      shared one)
- [ ] Deep-link install populates `deep_link_value`, `deep_link_sub*`,
      `match_type`, `is_deferred` etc. in the config request body
      (check `[RemoteService] Request body` debug log)

### 3. Test offer resource
- [ ] `https://web.team-s.club/` loads correctly in the WebView
- [ ] All flows exercised on that resource (login, form, upload,
      redirect, external app hand-off) work without visible errors

### 4. App size
- [ ] Release APK / AAB **< 100 MB** (`Get-Item build/app/outputs/**/*.apk`)
- [ ] Ideally < 30 MB — investigate if larger

### 5. Privacy policy
- [ ] Privacy Policy URL loads a real, permanent page (not 404 /
      "coming soon")
- [ ] Menu screen "Privacy Policy" button opens it in the internal
      info WebView
- [ ] Same URL is registered in the Play Console listing

### 6. API levels
- [ ] `android/app/build.gradle.kts` targetSdk = **35**, compileSdk =
      **36**, minSdk = **30**
- [ ] Builds without `flutter_plugin_android_lifecycle` compileSdk
      complaints (see `gray_part_pitfalls.md` §2)

### 7. Adaptive icon
- [ ] Launcher icon fills the mask on Pixel Launcher preview — no
      empty borders, no clipping
- [ ] Icon appears crisp at both 48 dp and 108 dp

### 8. Loading screen (also covered in Part B)
- [ ] Animated "Loading…" caption + animated progress bar
- [ ] Progress bar 0 → 100 % synced with real boot time
- [ ] Portrait AND landscape orientations both look correct
- [ ] Total boot time on normal Wi-Fi < 10 s

### 9. Push permission screen
- [ ] Shown BEFORE the WebView on the first entry into gray mode
- [ ] Portrait AND landscape backgrounds correct
- [ ] Accept → system dialog appears
- [ ] Skip → screen hidden for exactly 3 days (`pushInviteCooldown`)
- [ ] System-level deny → screen never shown again
      (`notification_os_denied` flag set)
- [ ] All three scenarios manually tested

### 10. WebView launch
- [ ] With `af_status: "Non-organic"` in conversion data → WebView opens
- [ ] With `af_status: "Organic"` → native game opens; no gray content
      leaks through

### 11. User-Agent
- [ ] Contains a current Chrome major version and current WebKit
      fragment
- [ ] Contains a real Android model / build id
- [ ] Does NOT contain `Dart`, `Flutter`, `WebView`, or any package
      name
- [ ] Same UA is set on the HTTP client (`towerHttp.userAgent`) AND
      on the WebView (`_web.setUserAgent(...)`)

### 12. WebView within Safe Area
- [ ] Portrait: WebView not covered by camera notch / punch-hole
- [ ] Landscape: WebView respects side cutout — no button under camera
- [ ] After lock → unlock: layout unchanged, no drifted padding
- [ ] Bottom of WebView reaches the bottom edge (no unnecessary inset)

### 13. Screen rotation
- [ ] Auto-rotate works on loading + no-wifi + push-invite + WebView
- [ ] Android manual rotation button (available when auto-rotate off)
      switches all four screens correctly
- [ ] `SystemChrome.setPreferredOrientations` allows all four values
      at boot; only game path re-locks to portrait

### 14. Back navigation (WebView)
- [ ] Android back gesture → WebView goes one page back
- [ ] `_web.canGoBack()` returns false on the first page → back
      gesture does NOTHING (WebView is not closed)
- [ ] No exit-app dialog fires from back on the first page

### 15. Too-many-redirects recovery
- [ ] Redirect-loop testing → up to 3 automatic retries, then
      graceful load of the last known URL
- [ ] No `ERR_TOO_MANY_REDIRECTS` error page ever shown to user

### 16. JavaScript enabled
- [ ] `setJavaScriptMode(JavaScriptMode.unrestricted)` on the WebView
- [ ] Payment gateways / OAuth pop-ups render normally

### 17. Cookies
- [ ] `AndroidWebViewCookieManager.setAcceptThirdPartyCookies(_, true)`
- [ ] Login persists across page reloads within the WebView

### 18. Sessions
- [ ] Session cookies survive between navigation events
- [ ] Killing + reopening the app resumes the last URL with session
      intact (until server-side expiry)

### 19. Inline autoplay video
- [ ] `setMediaPlaybackRequiresUserGesture(false)` set
- [ ] Video on test resource plays inline without tap-to-start

### 20. Protected Media (DRM)
- [ ] `setOnPlatformPermissionRequest((r) => r.grant())` wired
- [ ] DRM-protected streams play without permission modals

### 21. Parameter forwarding
- [ ] Config request body contains **all seven** device-side fields:
      `af_id`, `bundle_id`, `os`, `store_id`, `locale`, `push_token`,
      `firebase_project_id` (unless FCM not initialised — then last
      two omitted, never null)
- [ ] Every field from `onInstallConversionData` passed through
      verbatim (compare debug logs to the SDK payload)
- [ ] `os` value is exactly `"Android"`
- [ ] `locale` in RFC 3066 format (`en`, `en_US`, `ru`, …)

### 22. File upload
- [ ] Site `<input type="file">` opens the native chooser
- [ ] Camera + gallery both offered
- [ ] No app-wide filesystem permission dialog appears
- [ ] Picked file uploads successfully

### 23. Keyboard does not cover inputs
- [ ] Focused email / password input scrolls above the keyboard
- [ ] No jitter, no double-jump (see `gray_part_pitfalls.md` §3)

### 24. Push notifications
- [ ] Test push from Firebase Console shows on the device
- [ ] Notification uses the monochrome `ic_notification` icon
- [ ] Notification shows an image (BigPictureStyleInformation)
- [ ] Cold-start tap → app boots and opens the push URL
- [ ] Warm tap → live URL loaded, NOT persisted as `savedUrl`
- [ ] On the next launch after a cold-start push, the standard
      config URL is used (push URL is one-time)

### 25. Deep links inside WebView
- [ ] `tel:` / `mailto:` / `intent://` / `whatsapp://` / `tg://` links
      open the corresponding system app
- [ ] After the external app opens, returning to our app shows the
      previous WebView page — not an error state

---

## Part D — Backend contract (spot-check via debug logs)

- [ ] Config request logged with `[RemoteService] Request body: …`
- [ ] Body is a **flat** JSON object (no nested attribution key)
- [ ] Response logged with `[RemoteService] Response: 200 …`
- [ ] On `{ok:true}` → `savedUrl` + `expires` written to
      `flutter_secure_storage`
- [ ] On `{ok:false}` first launch → `AppMode.offline` written **once**;
      no subsequent config request fires this install
- [ ] `expires` respected on returning launch — cached URL loaded when
      still valid, refetch when expired
- [ ] Token refresh (`onTokenRotated`) triggers a fresh config POST

---

## Part E — Build hygiene (Windows / Gradle)

- [ ] `cd android; .\gradlew.bat --stop; cd ..` before every clean
- [ ] `Remove-Item android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java`
      + `flutter pub get` after any plugin change
- [ ] Release build:
      `flutter build apk --release --obfuscate --split-debug-info=build/debug_info`
- [ ] `--split-debug-info` output NOT committed to git
- [ ] `google-services.json` NOT committed (only `.example`)
- [ ] `key.properties` NOT committed

---

## Part F — Store submission

- [ ] Play Console listing description does NOT reference the WebView
      or the partner site
- [ ] Screenshots show the native game, never the WebView
- [ ] Privacy Policy URL live before submission
- [ ] Data Safety form declares only what the app actually collects
      (attribution ID, push token, device locale — nothing more)
- [ ] `versionCode` in `pubspec.yaml` AND `build.gradle.kts` bumped
      from the previous store version (see `gray_part_pitfalls.md` §8)

---

## Quick sanity commands

```powershell
# Confirm no leftover template strings
Select-String -Path lib\**\*.dart -Pattern 'skyward|Skyward|template|CHANGE_ME|TODO' -SimpleMatch

# Confirm applicationId consistency
Select-String -Path android\**\*.kts,lib\**\*.dart -Pattern 'com\.example\.template'
Select-String -Path android\**\*.kt -Pattern 'package\s+com\.'

# Build the release
cd android; .\gradlew.bat --stop; cd ..
flutter clean
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build\debug_info
```

Both commands above should return **zero hits** on template
placeholders on the final build (aside from documentation comments).
