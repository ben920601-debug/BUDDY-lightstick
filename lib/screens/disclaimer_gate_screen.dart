import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/lightstick_glyph.dart';
import 'scan_screen.dart';

/// 進入 App 後的第一個畫面：背景 + 一個跳出視窗，
/// 說明這是非官方、相容多款手燈的個人工具，使用者必須按確認才能繼續。
class DisclaimerGateScreen extends StatefulWidget {
  const DisclaimerGateScreen({super.key});

  @override
  State<DisclaimerGateScreen> createState() => _DisclaimerGateScreenState();
}

class _DisclaimerGateScreenState extends State<DisclaimerGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimer());
  }

  Future<void> _showDisclaimer() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LightstickGlyph(size: 64),
                const SizedBox(height: 16),
                Text(
                  '使用須知',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kUltraViolet,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '本 App 為獨立開發的個人工具，相容市面上多款藍牙應援手燈，'
                  '並非任何經紀公司、品牌或藝人推出的官方產品，亦無隸屬或合作關係。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.6),
                ),
                const Divider(height: 28),
                const Text(
                  'Notice',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This app is an independent, unofficial tool compatible with '
                  'various Bluetooth-enabled fan lightsticks. It is not produced '
                  'by, affiliated with, or endorsed by any record label, brand, '
                  'or artist.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kUltraViolet),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('我了解，繼續使用　/　I Understand'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kUltraViolet, kScubaBlue],
          ),
        ),
        child: const Center(
          child: LightstickGlyph(size: 100),
        ),
      ),
    );
  }
}
