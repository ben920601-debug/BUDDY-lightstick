import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ble/lightstick_service.dart';
import '../widgets/lightstick_glyph.dart';
import 'custom_mode_screen.dart';
import 'group_mode_screen.dart';
import 'concert_mode_screen.dart';
import 'privacy_screen.dart';
import 'studio_screen.dart';
import 'fan_message_screen.dart';

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.baloo2(
                              fontWeight: FontWeight.w600, fontSize: 16, color: const Color(0xFF2A2340))),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
            fontSize: 11, letterSpacing: 1.2, color: Colors.grey, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF5F4B8B),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5F4B8B), Color(0xFF00ABC0)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      top: 30,
                      child: Opacity(
                        opacity: 0.9,
                        child: LightstickGlyph(size: 90, glowColors: [
                          Colors.white,
                          Colors.white.withOpacity(0.7),
                          const Color(0xFF00ABC0),
                        ]),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 60,
                      right: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('已連線',
                              style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11, color: Colors.white70, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(
                            device.platformName.isNotEmpty ? device.platformName : '手燈裝置',
                            style: GoogleFonts.baloo2(
                                fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _sectionLabel('控制模式')),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _modeCard(
                  context: context,
                  title: '自訂模式',
                  subtitle: '圓盤調色 + 閃爍開關',
                  icon: Icons.palette,
                  color: const Color(0xFFE05A8C),
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
                  color: const Color(0xFF6B7280),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GroupModeScreen()),
                  ),
                ),
                _modeCard(
                  context: context,
                  title: '演唱會模式',
                  subtitle: '麥克風收音，音樂律動同步',
                  icon: Icons.music_note,
                  color: const Color(0xFF5F4B8B),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ConcertModeScreen(service: service, device: device),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(child: _sectionLabel('關於')),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _modeCard(
                  context: context,
                  title: '隱私權說明',
                  subtitle: '我們如何使用你的權限',
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF00ABC0),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                _modeCard(
                  context: context,
                  title: '工作室介紹',
                  subtitle: '這個專案是怎麼來的',
                  icon: Icons.info_outline,
                  color: const Color(0xFFC9A86A),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StudioScreen()),
                  ),
                ),
                _modeCard(
                  context: context,
                  title: '粉絲想說',
                  subtitle: '給開發者的話',
                  icon: Icons.favorite_border,
                  color: const Color(0xFFE05A8C),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FanMessageScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
