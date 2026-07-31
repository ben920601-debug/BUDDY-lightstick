import 'package:flutter/material.dart';

import 'screens/intro_video_screen.dart';

void main() {
  runApp(const LightstickApp());
}

// GFRIEND 應援色主題
// Pantone 18-3838 Ultra Violet（紫）/ 16-4725 Scuba Blue（青藍）/ 11-4201 Cloud Dancer（米白）
const kUltraViolet = Color(0xFF5F4B8B);
const kScubaBlue = Color(0xFF00ABC0);
const kCloudDancer = Color(0xFFF0EEE9);

class LightstickApp extends StatelessWidget {
  const LightstickApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kUltraViolet,
      primary: kUltraViolet,
      secondary: kScubaBlue,
      surface: kCloudDancer,
    );

    return MaterialApp(
      title: '手燈控制 MVP',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: kCloudDancer,
        appBarTheme: AppBarTheme(
          backgroundColor: kUltraViolet,
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(backgroundColor: kUltraViolet),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? kScubaBlue : null,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? kScubaBlue.withOpacity(0.5)
                : null,
          ),
        ),
      ),
      home: const IntroVideoScreen(),
    );
  }
}
