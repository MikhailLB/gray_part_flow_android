# Gray-Part Pitfalls — Battle-Tested Fixes

Mistakes that bit during real builds of gray-flow Flutter apps on Android
(June 2026). Each section lists the symptom, the root cause, and the
exact fix. Apply these proactively when scaffolding a new gray-part
project; do not wait for the error to appear.

---

## 1. `file_picker >= 10.x` breaks `GeneratedPluginRegistrant`

### Symptom

```
GeneratedPluginRegistrant.java:34: error: cannot find symbol
  flutterEngine.getPlugins().add(new com.mr.flutter.plugin.filepicker.FilePickerPlugin());
                                                                     ^
  symbol:   class FilePickerPlugin
  location: package com.mr.flutter.plugin.filepicker
```

Followed by a Flutter warning like:

> Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
> appsflyer\_sdk, device\_info\_plus, file\_picker, package\_info\_plus

### Cause

Starting with `file_picker 10.x`, the Android plugin is **Kotlin-only**
(`FilePickerPlugin.kt`) and ships with its own Kotlin Gradle Plugin
declaration. That KGP clashes with Flutter's Built-in Kotlin support, so
the Kotlin compile step for `:file_picker` is skipped and the Java
`GeneratedPluginRegistrant` finds no class to register.

### Fix

Pin `file_picker` to the last Java-based release:

```yaml
# pubspec.yaml
dependencies:
  # NOTE: do NOT upgrade. 10+ is Kotlin-only and brings its own KGP that
  # collides with Flutter's Built-in Kotlin support.
  file_picker: 8.1.4
```

Then:

```powershell
cd android ; .\gradlew.bat --stop ; cd ..
flutter clean
flutter pub get
# delete the stale registrant — it will regenerate on next build
Remove-Item android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java -ErrorAction SilentlyContinue
```

Always call `FilePicker.platform.pickFiles(...)` (instance) rather than
the deprecated static `FilePicker.pickFiles(...)`. Works on every
version 5.x – 8.x.

---

## 2. Plugin compiled against older Android SDK than its transitive deps

### Symptom

```
> Dependency ':flutter_plugin_android_lifecycle' requires libraries and
  applications that depend on it to compile against version 36 or later
  of the Android APIs.
  :file_picker is currently compiled against android-34.
  Recommended action: Update this project to use a newer compileSdk
  of at least 36, for example 36.
```

### Cause

Older plugin releases hard-code `compileSdk = 34` (or 33). Their
transitive dependencies (e.g. `flutter_plugin_android_lifecycle`) bump
to `36`. Gradle's `CheckAarMetadata` then aborts.

### Fix

Override `compileSdk` for every Android library subproject from the
**root** `android/build.gradle.kts`. The override MUST be registered
**before** the `evaluationDependsOn(":app")` block, otherwise Gradle
throws `Cannot run Project.afterEvaluate(Action) when the project is
already evaluated`.

```kotlin
// android/build.gradle.kts
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // -----------------------------------------------------------------
    // Force every Android library plugin to compile against the same
    // compileSdk our app uses (36+). Some plugins ship with compileSdk=34
    // but their transitive deps require 36.
    //
    // Registered BEFORE evaluationDependsOn(":app") below — otherwise
    // the target projects will already be evaluated and Gradle refuses
    // to attach an afterEvaluate callback.
    // -----------------------------------------------------------------
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}
```

---

## 3. VPN makes the No-Internet screen flash on a healthy connection

### Symptoms

* Switching VPN on/off briefly shows the No-Internet screen even though
  the network is up.
* With VPN **on**, the No-Internet screen never disappears even when
  internet works fine (e.g. browser loads pages).
* Pre-screen flicker shows the WebView's native error page (black canvas
  with the Android-robot icon) for a couple of seconds before the
  styled No-Internet screen.

### Causes

| # | Symptom | Cause |
|---|---------|-------|
| A | None-flash | `connectivity_plus` emits `[ConnectivityResult.none]` for a few hundred ms while the VPN interface is being brought up. |
| B | Stuck on No-Internet w/ VPN | DNS resolution latency through the VPN tunnel exceeds the 3-second probe timeout → `TimeoutException` → false negative. |
| C | Black robot screen | WebView's native error page renders for any `onWebResourceError`, and the redundant DNS re-probe inside `_gotoOfflineIfDown()` keeps it visible up to 7 s. |

### Fixes

**A. Whitelist VPN as a real interface + treat `bluetooth` / `other` too:**

```dart
// core/net_sensor.dart
const _activeResults = {
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,           // ★ VPN IS connectivity
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

Future<bool> isOnline() async {
  final results = await _plugin.checkConnectivity();
  if (!results.any(_activeResults.contains)) return false;
  // …
}
```

**B. Raise DNS probe timeout 3 s → 7 s.** Real "no internet" cases throw
`SocketException` instantly (no route), so the larger timeout is free.

```dart
final answer = await InternetAddress.lookup(host)
    .timeout(const Duration(seconds: 7));
```

**C. Debounce the connectivity stream in `ContentScreen` / `PortalStage`.**
700 ms is invisible to the user and absorbs every observed flicker.

```dart
Timer? _offlineDebounce;

_connSub = widget.netSensor.statusStream.listen((statuses) {
  final allNone = statuses.every((s) => s == ConnectivityResult.none);
  if (!allNone) {
    _offlineDebounce?.cancel();
    return;
  }
  _offlineDebounce?.cancel();
  _offlineDebounce = Timer(const Duration(milliseconds: 700), () {
    _gotoOfflineDirect();
  });
});
```

Don't forget `_offlineDebounce?.cancel()` in `dispose()`.

---

## 4. `ERR_NAME_NOT_RESOLVED` shows the native WebView error page first

### Symptom

When DNS fails inside the WebView (VPN throttling, captive portal, ISP
filter), the user sees a black screen with the small Android-robot icon
in the top-left and tiny grey error text for **2 – 7 seconds** before
the styled No-Internet screen appears.

### Cause

`onWebResourceError` was calling `_gotoOfflineIfDown()`, which itself
does another DNS lookup (up to 7 s). During those seconds Android draws
its built-in error page on top of our otherwise empty WebView.

### Fix

In `onWebResourceError`:

1. **Immediately** flip `_isLoading = true` (or `_spinning = true`) — this
   covers the WebView with a styled spinner overlay so the native error
   page is never visible.
2. **Skip the redundant DNS probe** for the well-known DNS / disconnect
   error codes — just go to the No-Internet screen directly.

```dart
onWebResourceError: (err) {
  if (err.isForMainFrame != true) return;
  final blurb = err.description.toLowerCase();

  // (existing) redirect-loop retry first
  // …

  // Cover the WebView's native error page IMMEDIATELY.
  if (mounted) setState(() => _isLoading = true);

  final isDnsOrDisconnect =
      blurb.contains('name_not_resolved') ||
      blurb.contains('err_name_not_resolved') ||
      blurb.contains('internet_disconnected') ||
      blurb.contains('network_changed') ||
      err.errorCode == -105 || // ERR_NAME_NOT_RESOLVED
      err.errorCode == -106 || // ERR_INTERNET_DISCONNECTED
      err.errorCode == -21;    // ERR_NETWORK_CHANGED

  if (isDnsOrDisconnect) {
    _gotoOfflineDirect();      // skip redundant DNS probe
  } else {
    _gotoOfflineIfDown();
  }
},
```

---

## 5. `flutter_local_notifications 18.x` requires core-library desugaring

### Symptom

```
> Could not resolve all files for configuration ':app:debugRuntimeClasspath'.
  Cannot find a version of 'com.android.tools:desugar_jdk_libs' …
```

or runtime crash because `java.time.*` is unavailable on API 24-25.

### Fix

In `android/app/build.gradle.kts`:

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

---

## 6. Kotlin incremental compilation cache fails when project path has spaces

### Symptom

```
> Could not close incremental caches in
  C:\…\My Projects\foo\android\…
```

### Fix

```properties
# android/gradle.properties
kotlin.incremental=false
```

(Trivial loss in incremental build time; required on Windows whenever
the project path contains a space, slash, non-ASCII character, etc.)

---

## 7. `Project.afterEvaluate(Action)` cannot run when project is already evaluated

### Symptom

```
* Where: Build file 'android/build.gradle.kts' line: 29
* What went wrong:
  Cannot run Project.afterEvaluate(Action) when the project is already evaluated.
```

### Cause

`subprojects { project.evaluationDependsOn(":app") }` triggers eager
evaluation of every subproject. Any **subsequent** `subprojects {
afterEvaluate { … } }` block then arrives too late.

### Fix

Always declare `afterEvaluate` overrides in the same `subprojects` block
that sets `layout.buildDirectory`, **before** the
`evaluationDependsOn(":app")` block.

See section 2 for the full pattern.

---

## 8. Release `versionCode` / `versionName` must be bumped per build

### Symptom

Play Store upload rejected: "You need to use a different version code
for your APK because you already have one with version code 1."

### Fix

Bump version in **two** places, in sync:

```yaml
# pubspec.yaml
version: 1.0.1+2     #  ↑ versionName  ↑ versionCode
```

```kotlin
// android/app/build.gradle.kts
defaultConfig {
    versionCode = 2
    versionName = "1.0.1"
}
```

`flutter` honours `pubspec.yaml` automatically only if `build.gradle.kts`
uses `versionCode = flutter.versionCode` / `versionName = flutter.versionName`.
If those are hard-coded (as in this template), edit both.

---

## 9. Stale `GeneratedPluginRegistrant.java` survives plugin changes

### Symptom

After switching plugin versions, build fails with
`cannot find symbol: SomePlugin` even though the plugin source file
exists in `~/.pub-cache`.

### Fix

The registrant is regenerated by `flutter pub get`, but it is **never
overwritten** if it already exists. Delete it manually and re-run
`flutter pub get` (or just `flutter build`):

```powershell
Remove-Item android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java
flutter pub get
```

Pair this with `gradlew --stop` on Windows.

---

## 10. Quick-recovery cookbook (Windows / paths with spaces)

When the Android side misbehaves and you've changed plugin versions:

```powershell
cd android
.\gradlew.bat --stop
cd ..
flutter clean
Remove-Item android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java -ErrorAction SilentlyContinue
flutter pub get
flutter build apk --debug          # smoke-test compile
flutter build apk --release --obfuscate --split-debug-info=build/debug_info
flutter build appbundle --release --obfuscate --split-debug-info=build/debug_info
```

---

## TL;DR checklist before first release of a gray-part app

- [ ] `file_picker` pinned to `8.1.4` (never `>=10.x`)
- [ ] Root `android/build.gradle.kts` overrides `compileSdk = 36` for all
      library subprojects, registered **before** `evaluationDependsOn`
- [ ] `compileSdk = 36`, `targetSdk = 35`, `minSdk = 30` in app
      `build.gradle.kts`
- [ ] `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4`
- [ ] `kotlin.incremental=false` in `gradle.properties`
- [ ] `NetSensor.isOnline()` whitelist includes `ConnectivityResult.vpn`
- [ ] DNS probe timeout = 7 s
- [ ] Connectivity-drop stream is debounced ≥ 700 ms before routing to
      No-Internet
- [ ] `onWebResourceError` covers WebView with spinner immediately, and
      DNS/disconnect codes skip the redundant probe
- [ ] `FilePicker.platform.pickFiles(...)` everywhere (not the static call)
- [ ] `pubspec.yaml` version AND `build.gradle.kts` versionCode/Name
      bumped together
