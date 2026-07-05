import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'ua_forge.dart';
import 'vault.dart';

// ============================================================
// PUSH HUB — Firebase Messaging + local notification display
// ============================================================
// Cold-start taps (app was killed) save the link so the shell opens it
// on next boot. Warm taps (background/foreground) deliver the link live
// via [onLink] without persisting it (push links are one-time).
//
// The Android notification channel id must match the manifest meta-data
// `default_notification_channel_id`. The small icon is a dedicated
// monochrome flame drawable, never the launcher icon.
// ============================================================

// [FINGERPRINT] Rename BOTH constants per project.
//   • kChannelId must EXACTLY match the value of
//     `com.google.firebase.messaging.default_notification_channel_id`
//     meta-data in android/app/src/main/AndroidManifest.xml — keep the
//     rename atomic.
//   • kChannelName is the user-visible name in Android system settings
//     ("Notifications for <app>") — should read like a normal app
//     channel, not "template".
//   • _smallIcon references res/drawable/ic_notification.xml — that
//     drawable itself is fingerprinted (see .cursor/rules/custom_screens.md
//     → "Notification Icon"). Replace the vector artwork per project.
const String kChannelId = 'app_alerts'; // [TODO] rename per project
const String kChannelName = 'Notifications'; // [TODO] rename per project
const String _smallIcon = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // The OS renders background notifications; the tap is processed on
  // resume (warm) or boot (cold) — nothing to do in this isolate.
}

class PushHub {
  PushHub(this._vault);

  final Vault _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  bool _ready = false;

  /// Live (warm) push link delivery → loaded straight into the WebView.
  void Function(String link)? onLink;

  /// Fired when FCM rotates the token → re-post to the gate.
  void Function(String token)? onTokenRotated;

  String? get token => _token;

  Future<void> boot() async {
    if (_ready) return;
    try {
      // main() already initializes the default app; only initialize here if it
      // somehow didn't, to avoid a [core/duplicate-app] throw that would leave
      // messaging uninitialized (and silently break permission + push).
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      await _setupLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _ready = true;
    } catch (_) {
      // Firebase not configured yet — push stays dormant, app continues.
    }
  }

  Future<void> _setupLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? link = data['url'] as String?;
          if (link != null && link.isNotEmpty) onLink?.call(link);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          kChannelName,
          description: 'Updates and offers',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Asks for notification permission (Android 13+ system dialog).
  /// Records an OS-denied flag so the invite screen never loops.
  Future<bool> askPermission() async {
    if (_fm == null) return false;
    final NotificationSettings settings = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    await _vault.markPushAllowed(granted);
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushBlockedByOs();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _fetchImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kChannelId,
          kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kChannelId,
      kChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
    );

    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    if (link != null && link.isNotEmpty) {
      _vault.stashPendingLink(link);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    if (link != null && link.isNotEmpty) {
      onLink?.call(link);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final dynamic res = await towerHttp
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
