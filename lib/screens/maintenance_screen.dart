import 'package:flutter/material.dart';

import '../widgets/gradient_app_bar.dart';
import '../widgets/lightstick_glyph.dart';

class MaintenanceScreen extends StatelessWidget {
  final String title;
  final String message;

  const MaintenanceScreen({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LightstickGlyph(size: 72),
              const SizedBox(height: 24),
              const Text('維護中', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
