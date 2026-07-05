# Assets — Template Placeholder Pack

This folder ships with placeholder artwork left over from the
**Skyward Towers** demo the template was built from. Every asset here
is **fingerprinted** — do NOT ship it as-is on a real project.

---

## Folders

| Folder | Purpose | Rename per project? |
|---|---|---|
| `gameplay_assets/` | The placeholder game's board art. Replace with your project's real game art. | Optional but recommended |
| `SkywardTowers_additional_assets_webp/` | Gray-flow screen backgrounds (loading / no-wifi / notifications) + main-menu branding. | **YES — mandatory** |
| `generated/` | Launcher icons produced by `flutter_launcher_icons`. Replace source PNGs then regenerate. | Assets replaced, folder can stay |

The addon folder segment (`SkywardTowers_additional_assets_webp`)
appears as a literal path in the compiled APK and is trivial to grep
across store submissions. Rename it per project — see
`.cursor/rules/custom_screens.md` → [FINGERPRINT] section.

---

## Required per-project asset swap

Before the first release build of a new project:

1. **Rename `SkywardTowers_additional_assets_webp/`** to a fresh short
   name (e.g. `crimson_pack/`, `verse_bg/`). Update:
   - `pubspec.yaml` → `flutter.assets`
   - `lib/app_assets.dart` → `_extra` constant
2. **Replace the six screen background webp files** with new artwork
   sized for portrait and landscape:
   - `Vertical_Loading_Screen.webp` + `Horizontal_Loading_Screen.webp`
   - `Vertical_Nowifi_Screen.webp` + `Horizontal_Nowifi_Screen.webp`
   - `Vertical_Notifications_Screen.webp`
     + `Horizontal_Notifications_Screen.webp`
   File names may stay the same — only the folder is fingerprinted.
3. **Replace `gameplay_assets/`** with your real game's artwork if the
   game module was swapped. If you kept the placeholder Skyward Towers
   game, keep this folder but ideally rename it too.
4. **Regenerate launcher icons.** Replace:
   - `assets/generated/app_icon.png` (source, ≥ 1024×1024)
   - `assets/generated/app_icon_foreground.png` (adaptive foreground)
   Then run:  `dart run flutter_launcher_icons`
5. **Replace `res/drawable/ic_notification.xml`** (monochrome vector)
   with a shape distinct from the launcher icon.

---

## Screen dimensions reference

Screen backgrounds must cover the full canvas with `BoxFit.cover` on
every device. Recommended source sizes:

- Portrait webp: **1080 × 1920** (target Android xxxhdpi phones)
- Landscape webp: **1920 × 1080**

Do not ship any single-image "responsive" attempts — the loading /
no-wifi / notifications screens each need a dedicated portrait AND
landscape file. TZ mandates smooth adaptation to both.

---

## What NOT to keep across projects

- The exact `Vertical_*.webp` / `Horizontal_*.webp` byte contents
- The `bg_city.webp` game background
- The launcher icon (`app_icon.png`)
- The notification vector (`ic_notification.xml`)

Two apps sharing any of the above are one binary-diff away from being
clustered as a template family.
