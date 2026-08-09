import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config/relay_config.dart';
import '../wire/alert_channel.dart';
import '../wire/beacon_keystore.dart';
import '../wire/device_signature.dart';
import '../wire/pulse_probe.dart';
import '../wire/web_scripts.dart';
import 'offline_stage.dart';

// ============================================================
// PORTAL STAGE — the WebView shell (gray content)
// ============================================================
// Hosts the destination URL with:
//   • forged device UA (identical to the HTTP client's UA)
//   • both orientations, immersive system UI
//   • external-scheme hand-off (tel:, mailto:, intent://)
//   • redirect-loop recovery (main-frame -1007 / -9 with a
//     bounded retry)
//   • live connectivity guard (debounced)
//   • warm push URL delivery via [AlertChannel.onIncomingUrl]
//   • native file chooser via MethodChannel (no file_picker dep)
//   • JS behaviours composed by `WebScripts.installAll`
//
// NOTE: There is NO client-side classification of the partner
// site (no deposit/cashier/register/login regex, no funnel event
// emission). Any funnel needed by the business must live server
// side; the client is a dumb shell.
// ============================================================

class PortalStage extends StatefulWidget {
  const PortalStage({
    super.key,
    required this.url,
    required this.keystore,
    required this.alerts,
  });

  final String url;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _offlineShown = false;
  String? _lastMainFrame;
  int _retryCounter = 0;
  Timer? _dropDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // [FORGE] Rotate the MethodChannel name per project. Keep in
  // sync with MainActivity.kt → `channelName`.
  static const MethodChannel _uploadChannel = MethodChannel('relay/upload');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _buildController();

    widget.alerts.onIncomingUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    // Debounce connectivity drops — a VPN reconnect or a brief cell
    // switch produces a burst of `none` events that must not fire
    // the offline stage. Only sustained drops route out.
    _connSub = PulseProbe().statusStream.listen((List<ConnectivityResult> r) {
      final bool allNone =
          r.isNotEmpty && r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _dropDebounce?.cancel();
        return;
      }
      _dropDebounce?.cancel();
      _dropDebounce = Timer(
        Duration(milliseconds: RelayConfig.reachDropDebounceMs),
        _showOffline,
      );
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  void _buildController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(DeviceSignature.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _retryCounter = 0;
          WebScripts.installAll(_web);
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _configureAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final String desc = err.description.toLowerCase();
    final bool isLoop = desc.contains('too_many_redirects') ||
        desc.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;

    if (isLoop &&
        _lastMainFrame != null &&
        _retryCounter < RelayConfig.redirectLoopRetries) {
      _retryCounter++;
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }

    // Cover the WebView's native error page immediately so the
    // Android chrome robot never leaks visually.
    if (mounted) setState(() => _spinner = true);

    final bool isConnectivity = desc.contains('name_not_resolved') ||
        desc.contains('address_unreachable') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (isConnectivity) {
      _showOffline();
    } else {
      _guardOffline();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inApp = <String>{
      'http',
      'https',
      'about',
      'data',
      'blob',
    };
    if (inApp.contains(uri.scheme)) {
      if (req.isMainFrame) _lastMainFrame = req.url;
      return NavigationDecision.navigate;
    }
    _openExternally(uri);
    return NavigationDecision.prevent;
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController controller =
        _web.platform as AndroidWebViewController;

    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    controller.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _uploadChannel
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guardOffline() async {
    if (_offlineShown) return;
    final bool online = await PulseProbe().canDialOut();
    if (online) return;
    _showOffline();
  }

  void _showOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final String current = _lastMainFrame ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineStage(
          onRetryBuild: (_) => PortalStage(
            url: current,
            keystore: widget.keystore,
            alerts: widget.alerts,
          ),
        ),
      ),
    );
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropDebounce?.cancel();
    _connSub?.cancel();
    widget.alerts.onIncomingUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: MediaQuery.viewPaddingOf(context),
              child: WebViewWidget(controller: _web),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF63BEF8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
