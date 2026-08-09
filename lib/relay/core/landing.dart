// ============================================================
// LANDING — verdict + routing outcome (sealed types)
// ============================================================
// The routing pipeline outputs ONE of three sealed subtypes.
// The boot screen destructures the result via a `switch` and
// only then decides which screen to push. This pattern replaces
// the older scattered `_toWeb/_toOffline/_goNative` void methods
// where each branch could push a different route.
//
// Sealed dispatch has a stable machine-code footprint that is
// deliberately different from an `enum` + `if/else` chain, so
// the compiled binary reads differently from sibling apps that
// use the enum pattern.
// ============================================================

/// Persisted routing memory across launches.
///
/// The wire values are stored in the keystore under a project-scoped
/// key. Do NOT rename the wire strings — legacy installs still hold
/// the old value.
enum RouteMemory {
  undecided,
  portal,
  native;

  String get wireValue => switch (this) {
        RouteMemory.undecided => 'undecided',
        RouteMemory.portal => 'portal',
        RouteMemory.native => 'native',
      };

  static RouteMemory parse(String? raw) => switch (raw) {
        'portal' || 'web' => RouteMemory.portal,
        'native' || 'game' => RouteMemory.native,
        _ => RouteMemory.undecided,
      };
}

/// Parsed response from the verdict endpoint.
///
/// Wire keys are `{ok, url, expires, message}` — mapped verbatim,
/// no key renaming. The backend contract preserves those exact
/// spellings.
class Verdict {
  const Verdict({
    required this.approved,
    this.url,
    this.expiresAt,
    this.note,
  });

  factory Verdict.fromJson(Map<String, dynamic> json) {
    final dynamic rawExpiry = json['expires'];
    return Verdict(
      approved: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      note: json['message']?.toString(),
    );
  }

  factory Verdict.rejected(String note) =>
      Verdict(approved: false, note: note);

  final bool approved;
  final String? url;
  final int? expiresAt;
  final String? note;

  bool get hasDestination =>
      approved && url != null && url!.isNotEmpty;
}

/// Sealed outcome of the boot pipeline. The boot screen destructures
/// via `switch` and cannot forget a branch — new subtypes force new
/// case labels at every dispatch site.
sealed class Landing {
  const Landing();
}

/// Show the native game.
final class GameLanding extends Landing {
  const GameLanding();
}

/// Show the WebView portal at [url].
///
/// [coldTap] is true only when the launch was triggered by a cold-boot
/// push notification tap — the URL comes from the intent payload, not
/// from the verdict cache, and the boot animation should be shortened.
final class PortalLanding extends Landing {
  const PortalLanding(this.url, {this.coldTap = false});

  final String url;
  final bool coldTap;
}

/// Show the no-connection screen. Retry rebuilds the boot pipeline.
///
/// [returnsToGame] is true when the user was previously in native
/// mode — the retry after Wi-Fi returns can immediately show the
/// game rather than reruning the whole verdict pipeline.
final class OfflineLanding extends Landing {
  const OfflineLanding({required this.returnsToGame});

  final bool returnsToGame;
}
