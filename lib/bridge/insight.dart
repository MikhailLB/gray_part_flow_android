import 'package:clarity_flutter/clarity_flutter.dart';

import '../env/insight_env.dart';

// ============================================================
// Insight — crash-safe facade over Microsoft Clarity
// ============================================================
// Clarity records the NATIVE Flutter surface (loading screen, push
// invite, native game, and the WebView container). The DOM INSIDE the
// WebView is invisible to replay — the offer-site funnel (register,
// login, deposit) is only visible if we emit custom events from the JS
// probe wired in WebStage.
//
// Every call is guarded so a Clarity failure can NEVER bubble into the
// gray flow and break routing. Do not call the Clarity SDK directly —
// always route through this facade. See .cursor/rules/clarity_analytics.mdc.
// ============================================================

class Insight {
  const Insight._();

  static ClarityConfig get config => ClarityConfig(
        projectId: kClarityProjectId,
        // Verbose while wiring a NEW project (checks HTTP 204 in logs),
        // LogLevel.None for release builds.
        logLevel: LogLevel.Verbose,
      );

  /// Groups the session by AppsFlyer id + attaches attribution tags.
  /// No-op on empty id so a missing af_id never wipes a good user id.
  static void identify(String? aid, {Map<String, String> tags = const {}}) {
    if (aid != null && aid.isNotEmpty) {
      _guard(() => Clarity.setCustomUserId(_clip(aid, 255)));
      tag('aid', aid);
    }
    tags.forEach(tag);
  }

  /// Native screen: sets the label AND emits a stable per-screen event.
  static void screen(String name) {
    screenName(name);
    event('screen_$name');
  }

  /// Sets the current screen label + mirrors it into the persistent
  /// `last_screen` tag (Clarity keeps the LAST tag value per session, so
  /// filtering by last_screen instantly shows the drop-off screen).
  static void screenName(String name) => _guard(() {
        Clarity.setCurrentScreenName(_clip(name, 255));
        Clarity.setCustomTag('last_screen', _clip(name, 255));
      });

  static void event(String name) =>
      _guard(() => Clarity.sendCustomEvent(_clip(name, 254)));

  static void tag(String key, String value) {
    if (value.isEmpty) return;
    _guard(() => Clarity.setCustomTag(key, _clip(value, 255)));
  }

  static String _clip(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);

  static void _guard(void Function() body) {
    try {
      body();
    } catch (_) {}
  }
}
