// ============================================================
// AppAssets — centralized asset paths
// ============================================================
// Every asset path in the app must go through a constant here — never
// hardcode `Image.asset('assets/…')` calls at the widget layer. This
// makes the fingerprint rename below a one-file change.
//
// [FINGERPRINT] MANDATORY per-project change:
//   1. Rename `_extra` to a fresh short folder name unique to this
//      project. See .cursor/rules/custom_screens.md → [FINGERPRINT]
//      block. Two projects sharing the same asset folder segment is
//      an instant cross-submission tell for store scanners.
//   2. Update `pubspec.yaml` `flutter.assets` to declare the new
//      folder.
//   3. Physically rename the folder on disk before running
//      `flutter pub get`.
//   4. `_gameplay` may also be renamed but it's less critical (game
//      art is game-specific and the folder is usually unique already).
// ============================================================

/// Centralized asset paths so the rest of the app never hardcodes strings.
class AppAssets {
  AppAssets._();

  // [FINGERPRINT] Rename per project — see header block above.
  static const String _gameplay = 'assets/gameplay_assets';
  static const String _extra = 'assets/SkywardTowers_additional_assets_webp';

  // Background / branding
  static const String bgCity = '$_gameplay/bg_city.webp';
  static const String gameName = '$_extra/Game_name.webp';
  static const String icon = '$_extra/icon.webp';

  // Loading / status screens
  static const String verticalLoading = '$_extra/Vertical_Loading_Screen.webp';
  static const String horizontalLoading =
      '$_extra/Horizontal_Loading_Screen.webp';
  static const String verticalNoWifi = '$_extra/Vertical_Nowifi_Screen.webp';
  static const String horizontalNoWifi =
      '$_extra/Horizontal_Nowifi_Screen.webp';
  static const String verticalNotifications =
      '$_extra/Vertical_Notifications_Screen.webp';
  static const String horizontalNotifications =
      '$_extra/Horizontal_Notifications_Screen.webp';

  /// Block art indexed by building level (1-based). Higher levels reuse the
  /// tallest building art and are visually distinguished by an overlay badge.
  static const List<String> blocks = <String>[
    '$_gameplay/block_asset_01.webp',
    '$_gameplay/block_asset_02.webp',
    '$_gameplay/block_asset_03.webp',
    '$_gameplay/block_asset_04.webp',
    '$_gameplay/block_asset_05.webp',
  ];

  /// All images that should be precached on the loading screen.
  static const List<String> all = <String>[
    bgCity,
    gameName,
    icon,
    verticalLoading,
    horizontalLoading,
    verticalNoWifi,
    horizontalNoWifi,
    verticalNotifications,
    horizontalNotifications,
    ...blocks,
  ];

  /// Returns the art path for a given building [level] (1-based), clamped to
  /// the available block art.
  static String blockForLevel(int level) {
    final int index = (level - 1).clamp(0, blocks.length - 1);
    return blocks[index];
  }
}
