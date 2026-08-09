---
description: Which assets each relay stage consumes and the mandatory per-project artwork rotation. Read before touching the asset folder or the stages.
alwaysApply: true
---

# Custom Screens — Asset Contract

The relay flow renders three foreground surfaces before / around the
portal (WebView): the boot screen, the permission stage, and the
offline stage. Each is an `Image.asset` background with widgets on
top. This rule is the single source of truth for **which asset each
stage consumes** and **how to rotate the artwork per project**.

`lib/app_assets.dart` centralises every asset path — no widget builds
a raw `assets/...` string. Add new asset paths through `AppAssets`.

## 1. Boot screen (loading art)

**File:** `lib/boot/boot_screen.dart`

Backgrounds (both required):

- Portrait: `assets/<addon>/Vertical_Loading_Screen.webp` →
  `AppAssets.verticalLoading`
- Landscape: `assets/<addon>/Horizontal_Loading_Screen.webp` →
  `AppAssets.horizontalLoading`

The animated "Loading…" caption and the progress bar are painted on
top. Do NOT bake them into the artwork. The progress bar reads its
value from `RelayCoordinator.decide(onProgress: ...)`.

## 2. Permission stage (push opt-in)

**File:** `lib/relay/stage/permission_stage.dart`

Backgrounds:

- Portrait: `Vertical_Notifications_Screen.webp` →
  `AppAssets.verticalNotifications`
- Landscape: `Horizontal_Notifications_Screen.webp` →
  `AppAssets.horizontalNotifications`

Accept / Skip buttons are `Positioned` widgets overlaying the image.

## 3. Offline stage

**File:** `lib/relay/stage/offline_stage.dart`

Backgrounds:

- Portrait: `Vertical_Nowifi_Screen.webp` → `AppAssets.verticalNoWifi`
- Landscape: `Horizontal_Nowifi_Screen.webp` →
  `AppAssets.horizontalNoWifi`

Retry is a `Positioned` widget near the bottom. Retry pushes
`BootScreen` again through `pushReplacement`, so the coordinator
re-runs the boot pipeline fresh.

Also used inside `portal_stage.dart` when a live connectivity drop
survives the `reachDropDebounceMs` debounce.

## 4. Notification icon

**File:** `android/app/src/main/res/drawable/ic_notification.xml`

Requirements:

- Vector Drawable XML (`<vector>`), 24×24 dp viewport.
- Silhouette must differ from the launcher icon. Reviewers pattern-
  match identical launcher + notification icons as a template
  fingerprint.
- Rotate the shape per project. Bell / dot / spark / raindrop /
  chevron / triangle — pick a fresh silhouette family. Do NOT
  reuse a shape from a shipped sibling.
- Colour: solid white on transparent, solid black, or a duotone
  accent — as long as the silhouette reads clearly on both light
  and dark system-tray backgrounds.

Keep it in `res/drawable/` (not `mipmap-*/`).

## 5. Addon folder — [FORGE] rotation

The addon folder (currently `assets/SkywardTowers_additional_assets_webp/`)
appears as a literal path in the compiled APK. Two apps shipping the
same folder segment is a trivial cross-submission fingerprint.

Every new project must:

1. Rename the folder on disk — pick a fresh short name unique to
   this project (e.g. `assets/crimsonPeak_pack_v1/`,
   `assets/skyshelf_bg/`).
2. Update `AppAssets._extra` (in `lib/app_assets.dart`) to the new
   path.
3. Update `pubspec.yaml` → `flutter.assets` accordingly.
4. `flutter clean ; flutter pub get` before the next build.

**File names INSIDE the folder stay the same** — only the addon
segment is fingerprinted.

The forge does NOT rename the folder for you today. This is a known
extension point — see `.cursor/rules/relay_forge.md` §6.

## 6. Landscape safe area (camera cutout)

`portal_stage.dart` wraps the WebView in
`Padding(padding: MediaQuery.viewPaddingOf(context), child: ...)`
to keep the notch inset in both orientations without adding a
bottom inset. Do NOT wrap in `SafeArea` — the WebView's own JS
enhancer handles safe-area padding on the site side; a Flutter
`SafeArea` around the widget would double-inset.
