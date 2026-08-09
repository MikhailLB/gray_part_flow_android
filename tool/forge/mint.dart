// ignore_for_file: avoid_print
// ============================================================
// FORGE MINT — recipe → project mutation
// ============================================================
// Usage:
//   dart run tool/forge/mint.dart                     (uses recipe.json)
//   dart run tool/forge/mint.dart --recipe path.json
//   dart run tool/forge/mint.dart --portfolio path.json
//   dart run tool/forge/mint.dart --dry-run
//   dart run tool/forge/mint.dart --gen-salt
//
// Contract:
//   1. Read the recipe JSON (default: tool/forge/recipe.json).
//   2. Read the portfolio registry JSON (default: path from recipe).
//   3. Reject if any value in the recipe collides with a shipped
//      sibling (see `.cursor/rules/portfolio_registry.md`).
//   4. Rewrite target files with the recipe values:
//        • lib/relay/codec/veil_codec.dart          (family + salt + streamLen)
//        • lib/relay/config/veiled_bytes.dart       (encoded byte arrays)
//        • lib/relay/config/relay_config.dart       (identity + timings)
//        • lib/relay/config/legal_urls.dart         (public URLs)
//        • lib/relay/wire/beacon_keystore.dart      (storage key prefix)
//        • lib/relay/wire/alert_channel.dart        (channel id + name)
//        • lib/relay/stage/portal_stage.dart        (upload channel name)
//        • android/app/src/main/AndroidManifest.xml (label + channel id + host)
//        • android/app/src/main/kotlin/**/MainActivity.kt (channel name)
//        • pubspec.yaml                             (name + description + version)
//   5. Append the recipe's identifying tuple to the portfolio registry
//      and write `forge.lock` next to the project root.
//
// The forge does NOT rotate: OneLink subdomain, keystore file, Google
// Play developer account, Firebase project bytes (google-services.json),
// AppsFlyer console project. Those are operator responsibilities and
// are captured in `.cursor/rules/portfolio_registry.md`.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'codecs/fnv_lcg.dart' as fnv_lcg;
import 'codecs/position_xor.dart' as position_xor;
import 'codecs/rc4_ksa.dart' as rc4_ksa;

// ============================================================
// Entry point
// ============================================================

Future<void> main(List<String> argv) async {
  final Map<String, String> args = _parseArgs(argv);

  if (args.containsKey('gen-salt')) {
    _emitSalt();
    return;
  }

  final String recipePath = args['recipe'] ?? 'tool/forge/recipe.json';
  final File recipeFile = File(recipePath);
  if (!recipeFile.existsSync()) {
    _bail('recipe not found: $recipePath\n'
        'copy tool/forge/recipe.example.json → tool/forge/recipe.json '
        'and fill it in');
  }

  final Map<String, Object?> recipe = jsonDecode(recipeFile.readAsStringSync())
      as Map<String, Object?>;
  _validateRecipe(recipe);

  final String portfolioPath =
      args['portfolio'] ?? recipe['portfolioRegistryPath'] as String? ?? '';
  final List<Map<String, Object?>> portfolio =
      portfolioPath.isEmpty ? <Map<String, Object?>>[] : _loadPortfolio(portfolioPath);

  _checkCollisions(recipe, portfolio);

  final bool dryRun = args.containsKey('dry-run');
  _log('recipe:     $recipePath');
  _log('portfolio:  ${portfolioPath.isEmpty ? "<none>" : portfolioPath}');
  _log('dry-run:    $dryRun');
  _log('');

  final Mutation mut = Mutation.fromRecipe(recipe);

  _writeVeilCodec(mut, dryRun: dryRun);
  _writeVeiledBytes(mut, dryRun: dryRun);
  _writeRelayConfig(mut, dryRun: dryRun);
  _writeLegalUrls(mut, dryRun: dryRun);
  _writeBeaconKeystore(mut, dryRun: dryRun);
  _writeAlertChannel(mut, dryRun: dryRun);
  _writePortalStage(mut, dryRun: dryRun);
  _writeAndroidManifest(mut, dryRun: dryRun);
  _writeMainActivity(mut, dryRun: dryRun);
  _writePubspec(mut, dryRun: dryRun);

  if (!dryRun) {
    _writeForgeLock(recipe);
    if (portfolioPath.isNotEmpty) {
      portfolio.add(_registryEntry(recipe));
      File(portfolioPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(portfolio),
      );
      _log('portfolio:  updated ($portfolioPath)');
    }
  }
  _log('\nOK — forge complete.');
}

// ============================================================
// Recipe → Mutation
// ============================================================

class Mutation {
  Mutation({
    required this.identity,
    required this.endpoints,
    required this.credentials,
    required this.userAgent,
    required this.codec,
    required this.timings,
    required this.storage,
    required this.notifications,
    required this.webView,
    required this.targets,
  });

  factory Mutation.fromRecipe(Map<String, Object?> r) => Mutation(
        identity: r['identity'] as Map<String, Object?>? ?? const {},
        endpoints: r['endpoints'] as Map<String, Object?>? ?? const {},
        credentials: r['credentials'] as Map<String, Object?>? ?? const {},
        userAgent: r['userAgent'] as Map<String, Object?>? ?? const {},
        codec: r['codec'] as Map<String, Object?>? ?? const {},
        timings: r['timings'] as Map<String, Object?>? ?? const {},
        storage: r['storage'] as Map<String, Object?>? ?? const {},
        notifications:
            r['notifications'] as Map<String, Object?>? ?? const {},
        webView: r['webView'] as Map<String, Object?>? ?? const {},
        targets: r['targets'] as Map<String, Object?>? ?? const {},
      );

  final Map<String, Object?> identity;
  final Map<String, Object?> endpoints;
  final Map<String, Object?> credentials;
  final Map<String, Object?> userAgent;
  final Map<String, Object?> codec;
  final Map<String, Object?> timings;
  final Map<String, Object?> storage;
  final Map<String, Object?> notifications;
  final Map<String, Object?> webView;
  final Map<String, Object?> targets;

  bool wants(String key) => targets[key] != false;

  String get codecFamily => codec['family'] as String? ?? 'position_xor';
  List<int> get codecSalt =>
      (codec['salt'] as List<Object?>? ?? const <Object?>[])
          .whereType<int>()
          .toList();
  int get codecStreamLen => codec['streamLen'] as int? ?? 22;

  /// Encode [plain] with the selected codec family + salt.
  List<int> encode(String plain) {
    switch (codecFamily) {
      case 'position_xor':
        return position_xor.encodePositionXor(
          plain: plain,
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      case 'fnv_lcg':
        return fnv_lcg.encodeFnvLcg(
          plain: plain,
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      case 'rc4_ksa':
        return rc4_ksa.encodeRc4Ksa(
          plain: plain,
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      default:
        _bail('unknown codec family: $codecFamily '
            '(supported: position_xor, fnv_lcg, rc4_ksa)');
    }
  }

  bool roundTrips(String plain) {
    switch (codecFamily) {
      case 'position_xor':
        return position_xor.roundTripsPositionXor(
          plain: plain,
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      case 'fnv_lcg':
        return fnv_lcg.roundTripsFnvLcg(
          plain: plain,
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      case 'rc4_ksa':
        return rc4_ksa.roundTripsRc4Ksa(
          plain: plain,
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      default:
        _bail('unknown codec family (roundTrip): $codecFamily');
    }
  }

  String codecRuntimeSource() {
    switch (codecFamily) {
      case 'position_xor':
        return position_xor.positionXorRuntimeSource(
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      case 'fnv_lcg':
        return fnv_lcg.fnvLcgRuntimeSource(
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      case 'rc4_ksa':
        return rc4_ksa.rc4KsaRuntimeSource(
          salt: codecSalt,
          streamLen: codecStreamLen,
        );
      default:
        _bail('unknown codec family (source): $codecFamily');
    }
  }
}

// ============================================================
// File writers
// ============================================================

void _writeVeilCodec(Mutation m, {required bool dryRun}) {
  if (!m.wants('codec')) {
    _log('skip: veil_codec (target off)');
    return;
  }
  const String path = 'lib/relay/codec/veil_codec.dart';
  final String source = m.codecRuntimeSource();
  _writeFile(path, source, dryRun: dryRun);
}

void _writeVeiledBytes(Mutation m, {required bool dryRun}) {
  if (!m.wants('veiledBytes')) {
    _log('skip: veiled_bytes (target off)');
    return;
  }
  const String path = 'lib/relay/config/veiled_bytes.dart';

  final Map<String, String> plaintext = <String, String>{
    '_endpointUrl': m.endpoints['configEndpointUrl'] as String? ?? '',
    '_gcdBaseUrl': m.endpoints['gcdBaseUrl'] as String? ?? '',
    '_attributionKey': m.credentials['attributionDevKey'] as String? ?? '',
    '_messagingProject':
        m.credentials['messagingProjectId'] as String? ?? '',
    '_uaProduct': 'Mozilla/5.0',
    '_uaLinuxOpen': '(Linux; Android',
    '_uaBuildLabel': ' Build/',
    '_uaBuildClose': ')',
    '_uaEngineLabel': ' AppleWebKit/',
    '_uaEngineTail': ' (KHTML, like Gecko)',
    '_uaChromeLabel': ' Chrome/',
    '_uaMobileSafari': ' Mobile Safari/',
    '_chromeVersion': m.userAgent['chromeVersion'] as String? ?? '',
    '_webkitVersion': m.userAgent['webkitVersion'] as String? ?? '',
    // JS bodies stay empty in the template shipment; a per-project
    // JS variant pack lands here in a future mint iteration.
    '_jsSafeAreaScript': '',
    '_jsKeyboardScript': '',
    '_jsAutoplayScript': '',
  };

  // Verify every non-empty value round-trips.
  for (final MapEntry<String, String> e in plaintext.entries) {
    if (e.value.isEmpty) continue;
    if (!m.roundTrips(e.value)) {
      _bail('${e.key} does not round-trip through ${m.codecFamily} '
          '— salt or streamLen is invalid');
    }
  }

  final Map<String, List<int>> encoded = <String, List<int>>{
    for (final MapEntry<String, String> e in plaintext.entries)
      e.key: m.encode(e.value),
  };

  final String source = _renderVeiledBytes(encoded);
  _writeFile(path, source, dryRun: dryRun);
}

String _renderVeiledBytes(Map<String, List<int>> encoded) {
  final StringBuffer buf = StringBuffer(_veiledHeader);
  encoded.forEach((String name, List<int> bytes) {
    buf.write('const List<int> $name = ${_formatBytesInline(bytes)};\n\n');
  });
  buf.write(_veiledFooter);
  return buf.toString();
}

const String _veiledHeader = r'''
import '../codec/veil_codec.dart';

// ============================================================
// VEILED BYTES — generated by tool/forge/mint.dart
// ============================================================
// Do NOT hand-edit. Re-run the forge to change any value here.
// ============================================================

''';

const String _veiledFooter = r'''
String unlockEndpointUrl() => reveal(_endpointUrl);
String unlockGcdBaseUrl() => reveal(_gcdBaseUrl);
String unlockAttributionKey() => reveal(_attributionKey);
String unlockMessagingProject() => reveal(_messagingProject);

String unlockUaProduct() => reveal(_uaProduct);
String unlockUaLinuxOpen() => reveal(_uaLinuxOpen);
String unlockUaBuildLabel() => reveal(_uaBuildLabel);
String unlockUaBuildClose() => reveal(_uaBuildClose);
String unlockUaEngineLabel() => reveal(_uaEngineLabel);
String unlockUaEngineTail() => reveal(_uaEngineTail);
String unlockUaChromeLabel() => reveal(_uaChromeLabel);
String unlockUaMobileSafari() => reveal(_uaMobileSafari);
String unlockChromeVersion() => reveal(_chromeVersion);
String unlockWebkitVersion() => reveal(_webkitVersion);

String unlockJsSafeAreaScript() => reveal(_jsSafeAreaScript);
String unlockJsKeyboardScript() => reveal(_jsKeyboardScript);
String unlockJsAutoplayScript() => reveal(_jsAutoplayScript);

String unlockGcdCallUrl(String applicationId, String deviceId) {
  final String base = unlockGcdBaseUrl();
  if (base.isEmpty) return '';
  return '$base$applicationId?devkey=${unlockAttributionKey()}&device_id=$deviceId';
}
''';

String _formatBytesInline(List<int> bytes) {
  if (bytes.isEmpty) return '<int>[]';
  final StringBuffer buf = StringBuffer('<int>[\n');
  for (int i = 0; i < bytes.length; i++) {
    if (i % 12 == 0) buf.write('  ');
    buf.write(bytes[i]);
    buf.write(',');
    if (i % 12 == 11 || i == bytes.length - 1) {
      buf.write('\n');
    } else {
      buf.write(' ');
    }
  }
  buf.write(']');
  return buf.toString();
}

void _writeRelayConfig(Mutation m, {required bool dryRun}) {
  if (!m.wants('relayConfig')) {
    _log('skip: relay_config (target off)');
    return;
  }
  const String path = 'lib/relay/config/relay_config.dart';
  final File file = File(path);
  if (!file.existsSync()) _bail('missing $path');

  String source = file.readAsStringSync();

  source = _replaceConst(
      source, 'applicationId', "'${m.identity['applicationId'] ?? 'com.example.template'}'");
  source = _replaceConst(source, 'marketId',
      "'${m.identity['applicationId'] ?? 'com.example.template'}'");
  source = _replaceConst(source, 'displayName',
      "'${m.identity['displayName'] ?? 'Template App'}'");
  source = _replaceConst(source, 'storeNumericId',
      "'${m.credentials['storeNumericId'] ?? ''}'");

  final Map<String, String> intFields = <String, String>{
    'permissionSnoozeSeconds': 'permissionSnoozeSeconds',
    'organicRescueDelay': 'organicRescueDelay',
    'verdictTimeoutSeconds': 'verdictTimeoutSeconds',
    'firstInstallAwaitSeconds': 'firstInstallAwaitSeconds',
    'returningInstallAwaitSeconds': 'returningInstallAwaitSeconds',
    'deepLinkAwaitSeconds': 'deepLinkAwaitSeconds',
    'reachProbeTimeoutSeconds': 'reachProbeTimeoutSeconds',
    'reachDropDebounceMs': 'reachDropDebounceMs',
    'redirectLoopRetries': 'redirectLoopRetries',
    'cachedUrlLifetimeSeconds': 'cachedUrlLifetimeSeconds',
  };
  for (final MapEntry<String, String> e in intFields.entries) {
    final Object? v = m.timings[e.value];
    if (v is int) {
      source = _replaceConst(source, e.key, v.toString());
    }
  }

  _writeFile(path, source, dryRun: dryRun);
}

String _replaceConst(String src, String name, String newValue) {
  final RegExp rx = RegExp(
    r'(static const \w+\s+' + name + r'\s*=\s*)[^;]+;',
  );
  if (!rx.hasMatch(src)) {
    return src;
  }
  return src.replaceFirstMapped(rx, (Match m) => '${m.group(1)}$newValue;');
}

void _writeLegalUrls(Mutation m, {required bool dryRun}) {
  if (!m.wants('legalUrls')) {
    _log('skip: legal_urls (target off)');
    return;
  }
  const String path = 'lib/relay/config/legal_urls.dart';
  final File file = File(path);
  if (!file.existsSync()) _bail('missing $path');
  String src = file.readAsStringSync();
  src = _replaceTopLevelString(
      src, 'homeLink', m.endpoints['homeUrl'] as String? ?? '');
  src = _replaceTopLevelString(
      src, 'privacyLink', m.endpoints['privacyUrl'] as String? ?? '');
  src = _replaceTopLevelString(
      src, 'supportLink', m.endpoints['supportUrl'] as String? ?? '');
  _writeFile(path, src, dryRun: dryRun);
}

String _replaceTopLevelString(String src, String name, String value) {
  final RegExp rx =
      RegExp(r"(const String " + name + r"\s*=\s*)'[^']*';");
  return src.replaceFirstMapped(rx, (Match m) => "${m.group(1)}'$value';");
}

void _writeBeaconKeystore(Mutation m, {required bool dryRun}) {
  if (!m.wants('keystorePrefix')) {
    _log('skip: beacon_keystore (target off)');
    return;
  }
  const String path = 'lib/relay/wire/beacon_keystore.dart';
  final File file = File(path);
  if (!file.existsSync()) _bail('missing $path');
  String src = file.readAsStringSync();
  final String prefix = m.storage['keyPrefix'] as String? ?? 'rl3_';
  src = src.replaceFirstMapped(
    RegExp(r"const String _keyPrefix = '[^']*';"),
    (Match _) => "const String _keyPrefix = '$prefix';",
  );
  _writeFile(path, src, dryRun: dryRun);
}

void _writeAlertChannel(Mutation m, {required bool dryRun}) {
  const String path = 'lib/relay/wire/alert_channel.dart';
  final File file = File(path);
  if (!file.existsSync()) _bail('missing $path');
  String src = file.readAsStringSync();
  final String id = m.notifications['channelId'] as String? ?? 'app_alerts';
  final String label =
      m.notifications['channelName'] as String? ?? 'Notifications';
  src = src.replaceFirstMapped(
    RegExp(r"const String kAlertChannelId = '[^']*';"),
    (Match _) => "const String kAlertChannelId = '$id';",
  );
  src = src.replaceFirstMapped(
    RegExp(r"const String kAlertChannelName = '[^']*';"),
    (Match _) => "const String kAlertChannelName = '$label';",
  );
  _writeFile(path, src, dryRun: dryRun);
}

void _writePortalStage(Mutation m, {required bool dryRun}) {
  const String path = 'lib/relay/stage/portal_stage.dart';
  final File file = File(path);
  if (!file.existsSync()) _bail('missing $path');
  String src = file.readAsStringSync();
  final String channel =
      m.webView['uploadChannelName'] as String? ?? 'relay/upload';
  src = src.replaceFirstMapped(
    RegExp(r"MethodChannel\('[^']*'\)"),
    (Match _) => "MethodChannel('$channel')",
  );
  _writeFile(path, src, dryRun: dryRun);
}

void _writeAndroidManifest(Mutation m, {required bool dryRun}) {
  if (!m.wants('androidManifest')) {
    _log('skip: android_manifest (target off)');
    return;
  }
  const String path = 'android/app/src/main/AndroidManifest.xml';
  final File file = File(path);
  if (!file.existsSync()) _bail('missing $path');
  String src = file.readAsStringSync();
  final String label = m.identity['displayName'] as String? ?? 'Template App';
  final String channelId =
      m.notifications['channelId'] as String? ?? 'app_alerts';
  src = src.replaceFirstMapped(
    RegExp(r'android:label="[^"]*"'),
    (Match _) => 'android:label="$label"',
  );
  src = src.replaceFirstMapped(
    RegExp(
      r'(android:name="com\.google\.firebase\.messaging\.default_notification_channel_id"\s*android:value=")[^"]*(")',
    ),
    (Match match) => '${match.group(1)}$channelId${match.group(2)}',
  );
  _writeFile(path, src, dryRun: dryRun);
}

void _writeMainActivity(Mutation m, {required bool dryRun}) {
  if (!m.wants('mainActivity')) {
    _log('skip: main_activity (target off)');
    return;
  }
  const String base = 'android/app/src/main/kotlin';
  final Directory root = Directory(base);
  if (!root.existsSync()) _bail('missing $base');
  final File? activity = _findFile(root, 'MainActivity.kt');
  if (activity == null) _bail('MainActivity.kt not found under $base');
  String src = activity.readAsStringSync();
  final String channel =
      m.webView['uploadChannelName'] as String? ?? 'relay/upload';
  src = src.replaceFirstMapped(
    RegExp(r'private val channelName = "[^"]*"'),
    (Match _) => 'private val channelName = "$channel"',
  );
  _writeFile(activity.path, src, dryRun: dryRun);
  _log('NOTE: package rename of $base/**/MainActivity.kt is manual — '
      'rename the folders + `package ...` declaration to match applicationId.');
}

File? _findFile(Directory root, String name) {
  for (final FileSystemEntity entity in root.listSync(recursive: true)) {
    if (entity is File && entity.uri.pathSegments.last == name) return entity;
  }
  return null;
}

void _writePubspec(Mutation m, {required bool dryRun}) {
  if (!m.wants('pubspec')) {
    _log('skip: pubspec (target off)');
    return;
  }
  const String path = 'pubspec.yaml';
  final File file = File(path);
  if (!file.existsSync()) _bail('missing $path');
  String src = file.readAsStringSync();
  final String slug =
      m.identity['packageSlug'] as String? ?? 'relay_template';
  final String desc = m.identity['description'] as String? ??
      'Relay template — regenerated per project by tool/forge.';
  src = src.replaceFirstMapped(
    RegExp(r'^name:\s+[^\s#]+', multiLine: true),
    (Match _) => 'name: $slug',
  );
  src = src.replaceFirstMapped(
    RegExp(r'^description:.*$', multiLine: true),
    (Match _) => 'description: "$desc"',
  );
  _writeFile(path, src, dryRun: dryRun);
}

// ============================================================
// Portfolio registry
// ============================================================

List<Map<String, Object?>> _loadPortfolio(String path) {
  final File file = File(path);
  if (!file.existsSync()) return <Map<String, Object?>>[];
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! List) _bail('portfolio must be a JSON array');
  return decoded.whereType<Map<String, Object?>>().toList();
}

Map<String, Object?> _registryEntry(Map<String, Object?> r) {
  final Map<String, Object?> id = r['identity'] as Map<String, Object?>? ?? const {};
  final Map<String, Object?> ep = r['endpoints'] as Map<String, Object?>? ?? const {};
  final Map<String, Object?> cr = r['credentials'] as Map<String, Object?>? ?? const {};
  final Map<String, Object?> co = r['codec'] as Map<String, Object?>? ?? const {};
  return <String, Object?>{
    'timestamp': DateTime.now().toIso8601String(),
    'displayName': id['displayName'],
    'applicationId': id['applicationId'],
    'packageSlug': id['packageSlug'],
    'configEndpointUrl': ep['configEndpointUrl'],
    'privacyUrl': ep['privacyUrl'],
    'attributionDevKey': cr['attributionDevKey'],
    'messagingProjectId': cr['messagingProjectId'],
    'codecFamily': co['family'],
    'codecStreamLen': co['streamLen'],
  };
}

void _checkCollisions(
  Map<String, Object?> recipe,
  List<Map<String, Object?>> portfolio,
) {
  if (portfolio.isEmpty) return;
  final Map<String, Object?> entry = _registryEntry(recipe);
  const List<String> mustBeUnique = <String>[
    'applicationId',
    'packageSlug',
    'configEndpointUrl',
    'privacyUrl',
    'attributionDevKey',
    'messagingProjectId',
  ];
  for (final Map<String, Object?> prev in portfolio) {
    for (final String field in mustBeUnique) {
      final Object? a = entry[field];
      final Object? b = prev[field];
      if (a == null || b == null) continue;
      if (a is String && a.isEmpty) continue;
      if (a == b) {
        _bail('COLLISION on $field: this recipe reuses "$a" from a shipped '
            'sibling (${prev['displayName']}). Rotate the value and re-run.');
      }
    }
  }
  // Codec family — the LAST shipped app should not use the same family.
  final Map<String, Object?> last = portfolio.last;
  if (last['codecFamily'] == entry['codecFamily']) {
    _log('WARNING: codec family "${entry['codecFamily']}" matches the '
        'previous shipped app. Consider switching families.');
  }
}

// ============================================================
// Recipe validation
// ============================================================

void _validateRecipe(Map<String, Object?> r) {
  const List<String> required = <String>[
    'identity',
    'endpoints',
    'credentials',
    'userAgent',
    'codec',
  ];
  for (final String key in required) {
    if (r[key] == null) _bail('recipe missing "$key"');
  }
  final Map<String, Object?> codec = r['codec'] as Map<String, Object?>;
  final Object? family = codec['family'];
  if (family is! String) _bail('codec.family must be a string');
  if (family != 'position_xor' && family != 'fnv_lcg' && family != 'rc4_ksa') {
    _bail('codec.family "$family" is not supported by this mint. '
        'Supported: position_xor, fnv_lcg, rc4_ksa');
  }
  final Object? salt = codec['salt'];
  if (salt is! List || salt.isEmpty) {
    _bail('codec.salt must be a non-empty array of integers');
  }
  if (salt.length < 12 || salt.length > 24) {
    _log('WARNING: codec.salt has ${salt.length} bytes '
        '(recommended range 12..24)');
  }
  final Object? streamLen = codec['streamLen'];
  if (streamLen is! int || streamLen < 16 || streamLen > 48) {
    _bail('codec.streamLen must be an int in [16..48]');
  }
}

// ============================================================
// Utilities
// ============================================================

void _emitSalt() {
  final Random rng = Random.secure();
  final List<int> salt =
      List<int>.generate(16 + rng.nextInt(8), (_) => rng.nextInt(256));
  final int streamLen = 16 + rng.nextInt(32);
  print('"salt": ${jsonEncode(salt)},');
  print('"streamLen": $streamLen');
}

void _writeFile(String path, String contents, {required bool dryRun}) {
  if (dryRun) {
    _log('dry-run: would rewrite $path (${contents.length} bytes)');
    return;
  }
  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
  _log('wrote: $path');
}

Map<String, String> _parseArgs(List<String> argv) {
  final Map<String, String> out = <String, String>{};
  for (int i = 0; i < argv.length; i++) {
    final String a = argv[i];
    if (!a.startsWith('--')) continue;
    final String key = a.substring(2);
    if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
      out[key] = argv[i + 1];
      i++;
    } else {
      out[key] = 'true';
    }
  }
  return out;
}

void _writeForgeLock(Map<String, Object?> recipe) {
  // Only the identifying tuple lands here — never plaintext secrets.
  // This lockfile is safe to commit; it's the audit trail for what
  // was applied to THIS project. See
  // `.cursor/rules/portfolio_registry.md` for the field list.
  final Map<String, Object?> id =
      recipe['identity'] as Map<String, Object?>? ?? const {};
  final Map<String, Object?> ep =
      recipe['endpoints'] as Map<String, Object?>? ?? const {};
  final Map<String, Object?> co =
      recipe['codec'] as Map<String, Object?>? ?? const {};
  final Map<String, Object?> ua =
      recipe['userAgent'] as Map<String, Object?>? ?? const {};
  final Map<String, Object?> st =
      recipe['storage'] as Map<String, Object?>? ?? const {};
  final Map<String, Object?> nt =
      recipe['notifications'] as Map<String, Object?>? ?? const {};

  final Map<String, Object?> lock = <String, Object?>{
    'generatedAt': DateTime.now().toIso8601String(),
    'displayName': id['displayName'],
    'applicationId': id['applicationId'],
    'packageSlug': id['packageSlug'],
    'configEndpointUrl': ep['configEndpointUrl'],
    'privacyUrl': ep['privacyUrl'],
    'codecFamily': co['family'],
    'codecStreamLen': co['streamLen'],
    'chromeVersion': ua['chromeVersion'],
    'keyPrefix': st['keyPrefix'],
    'channelId': nt['channelId'],
    'timings': recipe['timings'],
  };
  File('forge.lock')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lock));
  _log('lockfile:   forge.lock');
}

void _log(String message) => print(message);

Never _bail(String reason) {
  stderr.writeln('forge: $reason');
  exit(64);
}
