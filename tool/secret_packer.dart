// ignore_for_file: avoid_print
// ============================================================
// SECRET PACKER — encodes plaintext secrets into byte arrays
// ============================================================
// Mirrors lib/crypt/obfuscator.dart exactly. Run with:
//   dart run tool/secret_packer.dart
// then paste the printed arrays into lib/env/secure_strings.dart.
//
// ⚠️ Always run via `dart run` (native 64-bit ints). Never port
//    this to PowerShell — it overflows at 32 bits and corrupts bytes.
//
// Keep the seed below identical to obfuscator.dart's _seedPhrase.
// ============================================================

const String seedPhrase = 'skyR1ver_t0wers';
const int streamLength = 24;

List<int> buildStream() {
  int hash = 0x811C9DC5;
  for (final int c in seedPhrase.codeUnits) {
    hash = (hash ^ c) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  int state = hash == 0 ? 0x9E3779B9 : hash;
  final List<int> stream = List<int>.filled(streamLength, 0);
  for (int i = 0; i < streamLength; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    stream[i] = (state >> 16) & 0xFF;
  }
  return stream;
}

final List<int> stream = buildStream();

List<int> pack(String plain) {
  final List<int> bytes = plain.codeUnits;
  final List<int> out = List<int>.filled(bytes.length, 0);
  for (int i = 0; i < bytes.length; i++) {
    out[i] = (bytes[i] ^ stream[i % streamLength] ^ (i & 0xFF)) & 0xFF;
  }
  return out;
}

void emit(String label, String plain) {
  if (plain.isEmpty) {
    print('// $label — (empty, fill in later)');
    print('const <int>[];\n');
    return;
  }
  final List<int> packed = pack(plain);
  print('// $label  <= "$plain"');
  print('const <int>[${packed.join(', ')}],\n');
}

void main() {
  // ── Fill in the plaintext values, then run this script ──
  const String configEndpoint = 'https://skywardtowerrs.com/config.php';
  const String gcdBase = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const String chromeVersion = '128.0.6613.146';
  const String webkitVersion = '537.36';

  // Provided by the manager:
  const String attributionKey = 'JpHHA4JDz2ZZ9V65x4rxDT'; // AppsFlyer Dev Key
  const String messagingProject = '738149573869'; // Firebase project number

  print('=== Skyward Towers secret_packer ===\n');
  emit('configEndpoint', configEndpoint);
  emit('gcdBase', gcdBase);
  emit('chromeVersion', chromeVersion);
  emit('webkitVersion', webkitVersion);
  emit('attributionKey', attributionKey);
  emit('messagingProject', messagingProject);
}
