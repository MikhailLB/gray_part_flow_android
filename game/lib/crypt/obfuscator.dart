import 'dart:typed_data';

// ============================================================
// OBFUSCATOR — keystream string hider
// ============================================================
// Sensitive strings (config endpoint, attribution key, messaging
// id, user-agent fragments) live as encoded byte lists, never as
// plaintext literals in the binary.
//
// Scheme (intentionally project-unique):
//   1. A seed phrase feeds an FNV-1a 32-bit hash.
//   2. That hash seeds an xorshift32 generator producing a
//      [_streamLength]-byte keystream (high byte of each state).
//   3. Each output byte = input ^ stream[i % len] ^ (i & 0xFF).
//      The positional XOR makes identical plaintext bytes encode
//      differently depending on their offset.
//
// The transform is symmetric — the same routine encodes (in
// tool/secret_packer.dart) and decodes (here).
//
// ─────────────────────────────────────────────────────────────
// [FINGERPRINT] MANDATORY per-project change
// ─────────────────────────────────────────────────────────────
// EVERY new project MUST change BOTH:
//
//   a) `_seedPhrase`   — pick a fresh 8–20 char ASCII phrase, unique
//                        to this project. No dictionary words that
//                        match the project theme (do not use e.g.
//                        `cloudpickers_seed` for a project named
//                        Cloud Pickers — that link is trivially
//                        greppable). Instead use a random opaque
//                        token, e.g. `V7q!m2Zpn_` or a UUID slice.
//
//   b) `_streamLength` — vary between 16 and 48. Different from the
//                        previous project's value. This changes the
//                        cycle length of the keystream so byte-level
//                        entropy analysis differs between projects.
//
// After changing EITHER value:
//   1. Re-run `dart run tool/secret_packer.dart` (it uses the same
//      seed + length from this file).
//   2. Paste the fresh byte arrays into `lib/env/secure_strings.dart`.
//   3. Old arrays will no longer decode correctly — do not leave
//      stale ones behind.
//
// Do NOT copy a seed between projects even if you rename it. The
// bytes at rest are identical and store scanners can cluster them.
// ============================================================

// [FINGERPRINT] Change to a fresh random ASCII phrase per project.
const String _seedPhrase = 'CHANGE_ME_PER_PROJECT'; // [TODO]

// [FINGERPRINT] Change to a different length (16–48) per project.
const int _streamLength = 24;

Uint8List _buildStream() {
  // FNV-1a 32-bit over the seed bytes.
  int hash = 0x811C9DC5;
  for (final int c in _seedPhrase.codeUnits) {
    hash = (hash ^ c) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  // Guarantee a non-zero xorshift state.
  int state = hash == 0 ? 0x9E3779B9 : hash;
  final Uint8List stream = Uint8List(_streamLength);
  for (int i = 0; i < _streamLength; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    stream[i] = (state >> 16) & 0xFF;
  }
  return stream;
}

final Uint8List _stream = _buildStream();

/// Decodes an encoded byte list back into the original string.
/// Returns "" for empty input — this is the safe path the template
/// takes until real credentials are packed via tool/secret_packer.dart.
String rev(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _stream[i % _streamLength] ^ (i & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
