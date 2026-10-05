# Rust guard — native protection layer

> Read this whenever a project ships the **Rust guard** instead of (or
> alongside) the Dart-only relay. It explains what the component is, what it
> does, what lives inside it, how it joins the white part, and — most
> importantly — what MUST change from app to app so sibling binaries never
> cluster.

This layer is **optional**. The baseline template routes entirely in Dart
(`lib/relay/wire/verdict_call.dart` + `relay_agent.dart`). The Rust guard moves
the secrets, the crypto, and the network call out of the Dart AOT snapshot into
a native `.so`. Use it when you want the launch decision to be expensive to
reverse: a Dart snapshot leaks class names and string literals; a stripped Rust
`cdylib` leaks far less.

---

## 1. What the Rust component IS

A small `cdylib` (e.g. `libtc_guard.so`) loaded by the gray layer through
`dart:ffi`. It is **not** the game-math library — keep any white-part native
math (e.g. `libslot_core.so`) in a *separate* crate with no network/crypto, so
the two never share a fingerprint.

The guard owns everything the Dart image must never carry in the clear:
- the relay endpoint URL,
- the session AEAD key,
- the AppsFlyer dev key,
- the WebView link-fix JS,
- the envelope codec + the HTTPS call itself.

All of these are stored **obfuscated** (byte arrays, de-obfuscated per call) and
reconstructed at runtime, so `strings`/grep on the `.so` and on the Dart
snapshot find nothing useful.

---

## 2. What it DOES (per launch)

1. Dart hands it the raw signals as C strings: the AppsFlyer conversion map
   (JSON), the AppsFlyer id, the FCM push token, the locale.
2. The guard builds a **neutral** wire payload — no config key names — e.g.
   `{"c":<conv>,"a":"<af_id>","p":"<token>","l":"<locale>"}`.
3. It seals that with AEAD (ChaCha20-Poly1305), producing an opaque envelope,
   and POSTs it to the relay over HTTPS (from inside Rust).
4. It opens the relay's **sealed** answer and returns the destination URL
   (empty string = stay in the native game).
5. A second export relays the **push-open callback** (message_id + af_id) the
   same sealed way.
6. Extra exports hand Dart the de-obfuscated AppsFlyer key (the SDK needs it at
   runtime) and the link-fix JS.

The config-expected key names (`af_id`, `bundle_id`, `os`, `store_id`,
`locale`, `push_token`, `firebase_project_id`) are **rebuilt on the relay**, not
in the app. `config.php` must appear **only** on the proxy, never in the binary.

---

## 3. The ffi contract (example — rename everything per app)

```
tcg_evaluate(conv, af_id, push_token, locale, ua) -> *char   // verdict URL or ""
tcg_notify(message_id, af_id, ua)                 -> *char   // "1" on success
tcg_afkey()                                       -> *char   // AppsFlyer dev key
tcg_js()                                          -> *char   // link-fix script
tcg_free(ptr)                                                // free any of the above
```

Dart opens `DynamicLibrary.open('<lib>.so')`, runs the networky calls on a
background `Isolate` (they block), and frees every returned pointer. The gate is
**dormant** (returns native) until the AppsFlyer key is present, so a build
without credentials is QA- and store-safe.

---

## 4. What we STORE in it (and how)

| Value | In app? | Form |
|---|---|---|
| Relay endpoint URL | yes | obfuscated byte array |
| Session AEAD key (32B) | yes | obfuscated byte array |
| AppsFlyer dev key | yes | obfuscated byte array (SDK needs it in Dart) |
| Link-fix JS | yes | obfuscated byte array |
| `config.php` URL | **NO** | relay `.env` only |
| Firebase project number | **NO** | relay `.env` only |
| config key names | **NO** | relay rebuilds them |

Obfuscation = `byte ^ MASK[i % len] ^ ((i*K + C) & 0xFF)` with a **per-app**
random MASK and constants. De-obfuscate right before use; never hold the
plaintext in a `static`.

---

## 5. How it connects to the white part

- The white game (`lib/screens`, `lib/game`) **never** imports the gray layer or
  the guard. Only `lib/relay/**` loads the `.so`.
- Launch flow: boot screen → coordinator → `guardEvaluate(...)` → non-empty URL
  ⇒ notification opt-in → WebView portal; empty ⇒ native game.
- The guard is reachable only on the gray branch, so a reviewer who gets the
  native branch exercises an app that never touches it.
- Keep the white-part native math (if any) in its **own** crate — a casino app
  shipping one Rust lib that does slot math is unremarkable; shipping one that
  does HTTPS+crypto is the thing to hide, so don't merge them.

---

## 6. What MUST change app-to-app (de-clustering)

Never reuse a row across siblings. The guard is a strong fingerprint if copied.

- **Bridge type** — rotate: `dart:ffi` C-ABI, JNI (Kotlin↔Rust), or Rinf.
- **Crypto family** — rotate: AEAD (ChaCha20-Poly1305 / AES-GCM) vs XOR-keystream
  (HMAC-SHA256 / SHA256). Different crate set ⇒ different symbol graph.
- **HTTP crate** — rotate: `minreq`, `ureq`, `reqwest`, `attohttpc` (changes the
  TLS/dependency fingerprint).
- **Library name** — `libtc_guard.so`, `liblumen_core.so`, `libgate.so`, …
- **Exported symbol names** — `tcg_*`, `lr_*`, JNI names — make them non-descriptive.
- **AEAD/MAC domain tags** — e.g. `tcq-req-v1` — rename to opaque bytes.
- **Obfuscation MASK + index formula** — fresh random per app.
- **Wire field names** — the neutral keys (`c/a/p/l`) and the response fields.
- **Endpoint domain + relay path** (`/v1/session`, `/edge/sync`, …).
- **Response handling** — plaintext verbatim vs sealed-and-decrypted-in-Rust.

Shipped siblings (append, never reuse):

| App | Bridge | Crypto | HTTP | Lib / symbols |
|---|---|---|---|---|
| Stormreach Haven | JNI | XOR-keystream SHA256 | relay-side | `libgate.so` |
| LumenRise | dart:ffi | XOR-keystream HMAC | `ureq` | `liblumen_core.so` / `lr_*` |
| Treasure Clash | dart:ffi | ChaCha20-Poly1305 AEAD | `minreq` | `libtc_guard.so` / `tcg_*` |

---

## 7. Relay side (the proxy does the config work)

The app only talks to our clean proxy. The relay:
1. decrypts the neutral envelope,
2. rebuilds the config-expected body (adds `af_id/bundle_id/os/store_id/
   locale/push_token/firebase_project_id` from the wire payload + its own
   `.env` constants),
3. forwards to the partner `config.php` (never sends `X-Forwarded-For`),
4. extracts the destination URL, **seals** it, returns it.
5. Any malformed / unauthenticated request → `404` decoy; `GET` → `404`.

So `config.php`, the Firebase project number, and the config key names live on
the server, where exposure does not matter.

---

## 8. Build

- Cross-compile with `cargo-ndk` to `arm64-v8a`, `armeabi-v7a`, `x86_64`, output
  straight into `android/app/src/main/jniLibs/`.
- Release profile: `opt-level="s"`, `lto=true`, `strip=true`, `codegen-units=1`,
  `panic="abort"`. (`strip` removes locals, but `#[no_mangle] pub extern`
  exports stay in `dynsym` — hence rule 6: rename them.)
- `getrandom` for the nonce; no `println!`/`eprintln!` anywhere.

---

## 9. Anti-ban sweep for the Rust side

On a release `.so`, these must all be clean:

```powershell
# endpoint / config / partner / project must NOT appear in plaintext
llvm-strings lib*.so | rg -i 'https://|config\.php|interaction\.php|<relay-domain>|<project-number>'
# domain tags / path words should be opaque, not descriptive
llvm-strings lib*.so | rg -i 'req-v1|res-v1|session|notice'
# exported symbols should be non-descriptive
llvm-nm -D --defined-only lib*.so
```

And on the Dart side the only guard-related literals left are the ffi symbol
names and the `.so` filename — encode those too (build the name from bytes at
runtime) if you want zero greppable hints. Attribution key names never appear in
Dart because the relay rebuilds them.

---

## 10. Invariants

1. White part never imports the guard; only `lib/relay/**` loads the `.so`.
2. The app's wire payload carries **neutral** keys only; config keys are rebuilt
   on the relay. `config.php` never ships in the binary.
3. Endpoint, session key, AppsFlyer key and JS live **only** as obfuscated bytes
   in the guard — never as Dart literals, never as plaintext in the `.so`.
4. Networky ffi calls run on a background isolate and every returned pointer is
   freed with the `*_free` export.
5. Gate stays dormant (native for everyone) until the AppsFlyer key is present.
6. Firebase unavailable/banned must never crash or hang: time-box every init and
   token call; on failure continue without notifications.
7. Rotate every item in §6 per app; append to the sibling table, never reuse.
