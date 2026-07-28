import 'package:flutter/material.dart';

import 'screens/scan_screen.dart';

void main() {
  runApp(const LightstickApp());
}

class LightstickApp extends StatelessWidget {
  const LightstickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '手燈控制 MVP',
      theme: ThemeData(
        colorSchemeSeed: Colors.pinkAccent,
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}