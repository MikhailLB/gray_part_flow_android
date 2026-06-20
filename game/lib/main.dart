import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow all orientations so the loading screen can show its landscape art.
  // The loading screen locks the app back to portrait before the game starts.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  runApp(const SkywardTowersApp());
}

class SkywardTowersApp extends StatelessWidget {
  const SkywardTowersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skyward Towers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const LoadingScreen(),
    );
  }
}
