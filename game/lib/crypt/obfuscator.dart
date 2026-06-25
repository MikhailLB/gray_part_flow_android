import 'dart:typed_data';

// ============================================================
// OBFUSCATOR — keystream string hider for Skyward Towers
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
// The transform is symmetric, so the same routine encodes (in
// tool/secret_packer.dart) and decodes (here).
//
// To re-key the whole binary: change [_seedPhrase], then re-run
// `dart run tool/secret_packer.dart` and paste the fresh arrays.
// ============================================================

const String _seedPhrase = 'skyR1ver_t0wers';
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
String rev(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _stream[i % _streamLength] ^ (i & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
