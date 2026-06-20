import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_assets.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

enum _Status { checking, offline, loading, ready, error }

/// Opens [url] in an in-app WebView. Shows the no-wifi artwork when the device
/// is offline or a page fails to load, with a Retry action.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  _Status _status = _Status.checking;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _status = _Status.checking);

    final List<ConnectivityResult> result =
        await Connectivity().checkConnectivity();
    final bool online = result.any((ConnectivityResult r) =>
        r != ConnectivityResult.none);

    if (!online) {
      if (mounted) setState(() => _status = _Status.offline);
      return;
    }

    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.sky)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _status = _Status.loading);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _status = _Status.ready);
          },
          onWebResourceError: (WebResourceError error) {
            // Only surface main-frame failures as a full error screen.
            if (error.isForMainFrame ?? true) {
              if (mounted) setState(() => _status = _Status.error);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    if (mounted) {
      setState(() {
        _controller = controller;
        _status = _Status.loading;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sky,
      appBar: AppBar(
        backgroundColor: AppColors.skyDeep,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.checking:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case _Status.offline:
      case _Status.error:
        return _OfflineView(onRetry: _init);
      case _Status.loading:
      case _Status.ready:
        return Stack(
          children: <Widget>[
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (_status == _Status.loading)
              LinearProgressIndicator(
                value: _progress == 0 ? null : _progress / 100,
                backgroundColor: Colors.transparent,
                color: AppColors.sunset,
              ),
          ],
        );
    }
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(AppAssets.verticalNoWifi, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.transparent, Color(0x99000000)],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  'No internet connection',
                  style: AppTheme.titleStyle(size: 20),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  width: 200,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
