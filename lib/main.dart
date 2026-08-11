import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/disclaimer_gate_screen.dart';

void main() {
  runApp(const LightstickApp());
}

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
      title: '手燈控制 App',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: kCloudDancer,
        textTheme: GoogleFonts.notoSansTcTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: kUltraViolet,
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.baloo2(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
      home: const DisclaimerGateScreen(),
    );
  }
}
