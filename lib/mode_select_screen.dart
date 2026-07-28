import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/lightstick_service.dart';
import 'custom_mode_screen.dart';
import 'group_mode_screen.dart';
import 'concert_mode_screen.dart';

class ModeSelectScreen extends StatelessWidget {
  final LightstickService service;
  final BluetoothDevice device;

  const ModeSelectScreen({
    super.key,
    required this.service,
    required this.device,
  });

  Widget _modeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('已連線：${device.platformName}'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('選擇模式', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            _modeCard(
              context: context,
              title: '自訂模式',
              subtitle: '圓盤調色 + 閃爍開關',
              icon: Icons.palette,
              color: Colors.pinkAccent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CustomModeScreen(service: service, device: device),
                ),
              ),
            ),
            _modeCard(
              context: context,
              title: '團體模式',
              subtitle: '開發中',
              icon: Icons.groups,
              color: Colors.blueGrey,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GroupModeScreen()),
              ),
            ),
            _modeCard(
              context: context,
              title: '演唱會模式',
              subtitle: '麥克風收音，音樂律動同步（測試版）',
              icon: Icons.music_note,
              color: Colors.deepPurple,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConcertModeScreen(service: service, device: device),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
