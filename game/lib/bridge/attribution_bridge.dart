import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../env/facade.dart';
import '../env/secure_strings.dart';
import 'ua_forge.dart';

// ============================================================
// ATTRIBUTION BRIDGE — AppsFlyer install attribution + deep links
// ============================================================
// Collects the install conversion payload, deep-link click event and
// app-open attribution, then folds them into the gate request body.
//
// Organic false-positive guard: AppsFlyer occasionally reports
// af_status == "Organic" on the first conversion callback for genuinely
// paid installs. When that happens we wait a few seconds and re-query the
// GCD endpoint to obtain the real attribution.
//
// When no dev key is configured yet, the bridge short-circuits: the
// install-data future completes immediately with an empty map so the
// shell does not stall for 30s before falling back to the game.
// ============================================================

class AttributionBridge {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installData;
  Map<String, dynamic>? _deepLinkData;
  Map<String, dynamic>? _appOpenData;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _ignited = false;

  /// Initializes the SDK and wires callbacks. Safe to call once.
  Future<void> ignite() async {
    if (_ignited) return;
    _ignited = true;

    final String devKey = TowerFacade.attributionKey;
    if (devKey.isEmpty) {
      // No key yet — don't block the flow waiting for attribution.
      _completeInstall(<String, dynamic>{});
      _completeDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: TowerFacade.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic res) async {
      final Map<String, dynamic> payload = _unwrap(res);
      final String? status = payload['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: TowerFacade.organicRecheckDelay),
        );
        final Map<String, dynamic>? recheck = await _gcdRecheck();
        _installData = recheck ?? payload;
      } else {
        _installData = payload;
      }
      _completeInstall(_installData ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic res) {
      _appOpenData = _unwrap(res);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkData = Map<String, dynamic>.from(click);
      }
      _completeDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _completeInstall(<String, dynamic>{});
      _completeDeepLink();
    }
  }

  /// Waits up to [seconds] for the install conversion payload.
  Future<Map<String, dynamic>> awaitInstallData({int seconds = 30}) {
    return _installReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  /// Waits up to 5s for the deep-link callback.
  Future<void> awaitDeepLink() {
    return _deepLinkReady.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<String?> uid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Builds the merged gate (config) request body.
  Future<Map<String, dynamic>> assembleGateBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installData != null) body.addAll(_installData!);
    _deepLinkData?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpenData?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await uid() ?? '';
    body['bundle_id'] = TowerFacade.packageId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = TowerFacade.marketId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = TowerFacade.messagingProject;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    if (kDebugMode) {
      debugPrint('[AttributionBridge] gate body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRecheck() async {
    try {
      final String? deviceId = await uid();
      if (deviceId == null) return null;
      final String appId =
          Platform.isIOS ? TowerFacade.storeNumericId : TowerFacade.packageId;
      final String url = unlockGcdUrl(appId, deviceId);
      if (url.isEmpty) return null;

      final dynamic response = await towerHttp.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${TowerFacade.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _completeInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _completeDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _unwrap(dynamic res) {
    if (res is! Map) return <String, dynamic>{};
    final dynamic inner = res['payload'] ?? res['data'] ?? res;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) => MapEntry<String, dynamic>(
            k.toString(),
            v,
          ));
    }
    return <String, dynamic>{};
  }
}
