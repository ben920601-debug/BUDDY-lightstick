import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../widgets/lightstick_glyph.dart';

class FanMessageScreen extends StatelessWidget {
  const FanMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('粉絲想說')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: LightstickGlyph(size: 84)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kCloudDancer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kUltraViolet.withOpacity(0.2)),
              ),
              child: const Text(
                '謝謝你願意把手燈交給這個小小的 App 操控 🩷\n\n'
                '這個專案是因為喜歡，才動手做出來的，如果用起來有任何不順手、'
                '想要的新功能，或單純想say hi，都歡迎跟我說。',
                style: TextStyle(fontSize: 14, height: 1.9),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '目前 App 沒有連接任何伺服器（這也是刻意的設計，確保隱私），'
              '所以還沒有站內留言板功能，想留言的話麻煩透過信箱聯絡我：',
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.7),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kUltraViolet),
                onPressed: () => launchUrl(
                  Uri.parse('mailto:your-email@example.com?subject=給BuddyLightstick的話'),
                ),
                icon: const Icon(Icons.mail_outline),
                label: const Text('寫封信給我'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
