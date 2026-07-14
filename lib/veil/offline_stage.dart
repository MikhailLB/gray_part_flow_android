import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../bridge/insight.dart';
import 'glass_button.dart';

/// Shown when the device has no connection. Uses the project's dedicated
/// no-wifi artwork (orientation-aware) with a Retry pill overlaid at the
/// bottom. Retry rebuilds whatever screen the caller supplies.
class OfflineStage extends StatefulWidget {
  const OfflineStage({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<OfflineStage> createState() => _OfflineStageState();
}

class _OfflineStageState extends State<OfflineStage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Insight.screen('offline');
  }

  Future<void> _retry() async {
    if (_busy) return;
    Insight.event('offline_retry');
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.horizontalNoWifi
        : AppAssets.verticalNoWifi;
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0E2238),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover, width: size.width, height: size.height),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.08 : 0.09),
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF63BEF8)),
                      ),
                    )
                  : SkyPillButton(
                      label: 'Retry',
                      width: landscape ? size.width * 0.3 : size.width * 0.55,
                      onTap: _retry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
