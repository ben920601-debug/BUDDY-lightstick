import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/lightstick_glyph.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工作室介紹')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: LightstickGlyph(size: 84)),
            const SizedBox(height: 24),
            Text('關於這個專案',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: kUltraViolet)),
            const SizedBox(height: 12),
            const Text(
              '這是利用閒暇時間開發的個人小專案，起點是想讓手上的應援手燈多一些'
              '官方 App 沒有的操控方式——像是更直覺的調色圓盤、跟著現場音樂律動的燈效。',
              style: TextStyle(fontSize: 14, height: 1.8),
            ),
            const SizedBox(height: 20),
            _principleRow(Icons.build_outlined, '個人開發',
                '從硬體逆向、協定拆解到 App 開發，都是獨立完成的個人專案。'),
            _principleRow(Icons.lock_outline, '隱私優先',
                '不蒐集個人資料、不使用第三方分析或廣告工具，權限僅用於當下功能。'),
            _principleRow(Icons.favorite_border, '非官方粉絲專案',
                '與任何經紀公司、藝人或手燈製造商皆無隸屬或合作關係，純粹是基於熱愛做出來的工具。'),
          ],
        ),
      ),
    );
  }

  Widget _principleRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kScubaBlue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
