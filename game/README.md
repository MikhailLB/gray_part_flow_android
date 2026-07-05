# gray_part_flow_android

A Flutter/Android **template** for building gray-flow apps: a dual-mode
shell that shows a native game to organic users and a full-screen
WebView with a remote-configured URL to non-organic (paid) users.

The routing decision is made once per install, server-side, from
AppsFlyer attribution data. This repository is meant to be forked
into per-project apps; the template itself never ships to a store.

---

## Read these first

If you are a person or an AI agent about to modify this repository:

1. **`START_HERE.md`** — orientation, file map, order of operations.
2. **`.cursor/rules/android_gray_guide.md`** — full architecture,
   API contracts, and state machine.
3. **`.cursor/rules/gray_part_pitfalls.md`** — Android build fixes.
4. **`.cursor/rules/custom_screens.md`** — screen background contract.
5. **`FINAL_CHECKLIST.md`** — pre-release verification.

Every code file marked `[FINGERPRINT]` in a header comment must be
re-diversified on every new project spawned from this template.

---

## Quick start (for a new project)

```powershell
# 1. Fork this repo, rename the working copy folder
git clone https://github.com/MikhailLB/gray_part_flow_android.git my_new_app
cd my_new_app

# 2. Follow START_HERE.md §3 "Order of operations" step by step.

# 3. Build a debug smoke test
flutter clean
flutter pub get
flutter run

# 4. Release build
flutter build apk --release --obfuscate --split-debug-info=build/debug_info
```

The template compiles and runs out of the box without any manager
credentials — it will simply fall back to the placeholder native
game since the config gate has no endpoint to talk to.

---

## Repository layout

```
lib/
├── main.dart               Bootstrap — Firebase, orientations, bridges
├── app_assets.dart         All asset paths (fingerprinted folder)
├── bridge/                 Attribution / network / push / UA / vault
├── crypt/obfuscator.dart   XOR keystream string hider  [FINGERPRINT]
├── domain/                 Data models (gate reply, shell mode)
├── env/                    Facade / secure strings / legal links [TODO]
├── screens/                Native placeholder game screens
├── shell/                  MaterialApp + FlowRouter (state machine)
├── state/                  Persistent game progress
├── theme/                  App theme
├── veil/                   Gray-flow screens (loading / offline /
│                           push invite / WebView)
└── widgets/                Reusable game UI

android/
├── app/build.gradle.kts    applicationId / namespace [TODO]
├── app/google-services.json.example    Firebase stub [TODO real file]
└── app/src/main/
    ├── AndroidManifest.xml OneLink host + label [TODO]
    ├── kotlin/…/MainActivity.kt   File upload bridge [FINGERPRINT]
    └── res/drawable/       ic_notification.xml [FINGERPRINT]

tool/
├── secret_packer.dart      Encode endpoints/keys into byte arrays
└── gen_icon.dart           Adaptive icon helpers

assets/
├── gameplay_assets/        Game art (SkywardTowers placeholder)
├── SkywardTowers_…/        Loading / no-wifi / notif backgrounds
│                           [FINGERPRINT — rename per project]
└── generated/              Launcher icon source PNGs
```

---

## Placeholder game

This template ships with a small **Skyward Towers** (2048-style)
game as the native placeholder. It exists purely to satisfy the
"real content" defense strategy — reviewers who install organically
see a playable game, not a shell. Replace it with any real game
you own before the first store submission if you do not intend to
keep it.

---

## Contributing

This repo is intentionally lean. Improvements to the gray-flow
mechanics land here so future forks pick them up. Improvements
specific to a single game live in the per-project fork, never here.

Never commit:

- `android/app/google-services.json` (real one)
- `android/key.properties`
- `build/debug_info/`
- `.env`, `secrets/`, or any real endpoint / key / URL

All of these are already in `.gitignore` — but grep before pushing.
