# Custom Screen Assets — Template Contract

## Purpose

The gray-flow shell uses **orientation-aware background images** for three
foreground screens: the loading screen, the push-permission screen and the
no-internet screen. This rule is the single source of truth for **where
those assets live** and **how each screen must consume them**.

The template ships example artwork under
`assets/<project_addon>_additional_assets_webp/` (currently the SkywardTowers
demo pack — see [FINGERPRINT] note at the bottom). Replace those files with
project-specific artwork on every new build. Do **not** invent new folder
layouts per project — the folder name is fingerprinted, the paths are stable.

---

## Loading Screen (FlowRouter background)

**File:** `lib/shell/flow_router.dart`

**Background assets (both required):**

- Portrait: `assets/<addon>/Vertical_Loading_Screen.webp`
- Landscape: `assets/<addon>/Horizontal_Loading_Screen.webp`

**Implementation pattern (already wired via `AppAssets.horizontalLoading`
and `AppAssets.verticalLoading`):**

```dart
final bool landscape =
    MediaQuery.of(context).orientation == Orientation.landscape;
final String bg = landscape
    ? AppAssets.horizontalLoading
    : AppAssets.verticalLoading;

Image.asset(bg, fit: BoxFit.cover);
```

The animated "Loading…" caption and the progress bar are painted **on top**
of this image; do not bake them into the artwork.

---

## Push Permission Screen (PushInviteStage)

**File:** `lib/veil/push_invite_stage.dart`

**Background assets:**

- Portrait: `assets/<addon>/Vertical_Notifications_Screen.webp`
- Landscape: `assets/<addon>/Horizontal_Notifications_Screen.webp`

**Implementation pattern:**

```dart
final bool landscape =
    MediaQuery.of(context).orientation == Orientation.landscape;
final String bg = landscape
    ? AppAssets.horizontalNotifications
    : AppAssets.verticalNotifications;

Image.asset(bg, fit: BoxFit.cover);
```

The Accept / Skip buttons are `Positioned` widgets overlaying this image.

---

## No-Internet Screen (OfflineStage)

**File:** `lib/veil/offline_stage.dart`

**Background assets:**

- Portrait: `assets/<addon>/Vertical_Nowifi_Screen.webp`
- Landscape: `assets/<addon>/Horizontal_Nowifi_Screen.webp`

**Implementation pattern:**

```dart
final bool landscape =
    MediaQuery.of(context).orientation == Orientation.landscape;
final String bg = landscape
    ? AppAssets.horizontalNoWifi
    : AppAssets.verticalNoWifi;

Image.asset(bg, fit: BoxFit.cover);
```

The Retry button is a `Positioned` widget at the bottom.

**⚠️ CRITICAL:** The offline screen must be shown **immediately** on a
`ConnectivityResult.none` event — no DNS probe first. The DNS probe can
hang for up to 7 s while offline, during which the WebView renders its
built-in error page. See `gray_part_pitfalls.md` §3 and §4.

---

## No-Internet Detection Inside the WebView

**File:** `lib/veil/web_stage.dart`

When connectivity drops **inside** the WebView, jump to `OfflineStage`
directly (no `await widget.linkWatch.isReachable()`):

```dart
_connSub = widget.linkWatch.changes.listen((List<ConnectivityResult> r) {
  if (r.isNotEmpty &&
      r.every((ConnectivityResult e) => e == ConnectivityResult.none)) {
    _openOffline(); // synchronous swap, no DNS probe
  }
});
```

For WebView load errors (which can be transient), use the probe-then-show
path via `_guardOffline()`. The two paths must stay separate.

---

## Landscape Safe Area (camera cutout)

**File:** `lib/veil/web_stage.dart`

Use a `SafeArea(bottom: false, child: WebViewWidget(...))` around the
WebView — this keeps the camera cutout inset in **both** orientations
(top in portrait, side in landscape) without adding a bottom inset that
would clip content. The keyboard is handled by the JS scroll fix; the
bottom inset must remain 0.

---

## Notification Icon

**File:** `android/app/src/main/res/drawable/ic_notification.xml`

The push notification icon must be:

- Vector Drawable XML (`<vector>`), 24×24 dp viewport
- Monochrome white on transparent background (`android:fillColor="#FFFFFF"`)
- **NOT** the same shape as the launcher icon — reviewers pattern-match
  identical launcher + notification icons as a template fingerprint

If you replace this file, keep it in `res/drawable/` (not `mipmap-*/`).

---

## Asset Registration

All directories used above must be declared in `pubspec.yaml` under
`flutter.assets`. When you replace the SkywardTowers artwork with your
own, register the new folder(s):

```yaml
flutter:
  assets:
    - assets/gameplay_assets/
    - assets/<your_addon_folder>/
```

---

## [FINGERPRINT] Rename the asset addon folder per project

The addon folder (currently `assets/SkywardTowers_additional_assets_webp/`)
appears as a literal path in the compiled APK. Two apps shipping the same
folder name is an instant cross-submission fingerprint for store scanners.

For every new project:

1. Rename the folder — pick a fresh short name unique to this project
   (e.g. `assets/crimsonPeak_pack_v1/`, `assets/skyshelf_bg/`).
2. Update all `AppAssets.*` constants in `lib/app_assets.dart` to point at
   the new path.
3. Update `pubspec.yaml` `flutter.assets` accordingly.
4. Run `flutter clean && flutter pub get` before the next build.
5. The file **names inside** the folder (`Vertical_Loading_Screen.webp`, …)
   can stay the same — only the addon-folder segment is fingerprinted.
