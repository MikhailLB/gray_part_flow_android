import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_assets.dart';
import '../state/progress_store.dart';
import '../theme/app_theme.dart';
import 'menu_screen.dart';

/// First screen: shows the loading artwork, a progress bar that fills while
/// assets are precached and the progress store initializes, plus an animated
/// "Loading..." caption.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  late final AnimationController _dotsController;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precaching needs a valid context, so kick it off here exactly once.
    if (!_started) {
      _started = true;
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    final ProgressStore store = await ProgressStore.create();

    final List<String> images = AppAssets.all;
    final int total = images.length;
    int loaded = 0;

    // Minimum visible time so the bar animation reads well even on fast devices.
    final Stopwatch sw = Stopwatch()..start();

    for (final String path in images) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {
        // Ignore a single missing/broken asset; keep loading the rest.
      }
      loaded++;
      if (!mounted) return;
      setState(() => _progress = loaded / total);
      // Small pace so the progress bar is perceptible.
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    final int elapsed = sw.elapsedMilliseconds;
    if (elapsed < 1400) {
      await Future<void>.delayed(Duration(milliseconds: 1400 - elapsed));
    }
    if (!mounted) return;
    setState(() => _progress = 1);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    // The game itself is portrait-only; lock orientation before leaving.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MenuScreen(store: store),
      ),
    );
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = isLandscape
        ? AppAssets.horizontalLoading
        : AppAssets.verticalLoading;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover),
          // Darken the bottom for legible progress UI over any artwork.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x88000000)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _LoadingCaption(controller: _dotsController),
                  const SizedBox(height: 14),
                  _ProgressBar(value: _progress),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: AppTheme.titleStyle(size: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCaption extends StatelessWidget {
  const _LoadingCaption({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final int dots = (controller.value * 4).floor() % 4;
        return Text(
          'Loading${'.' * dots}',
          style: AppTheme.titleStyle(size: 26),
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        return Container(
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
          ),
          child: Stack(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: width * value.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.sunset, Color(0xFFFFD27D)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
