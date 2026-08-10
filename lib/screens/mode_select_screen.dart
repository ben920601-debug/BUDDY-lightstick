import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ble/lightstick_service.dart';
import '../services/api_service.dart';
import '../widgets/lightstick_glyph.dart';
import 'scan_screen.dart';
import 'custom_mode_screen.dart';
import 'group_mode_screen.dart';
import 'concert_mode_screen.dart';
import 'privacy_screen.dart';
import 'studio_screen.dart';
import 'board_screen.dart';
import 'maintenance_screen.dart';

/// 首頁：進入 App 不需要先連線手燈。
/// 只有點到「自訂模式」「演唱會模式」這類真的需要藍牙的功能時，
/// 才會跳出裝置選擇畫面要求連線；其他功能（隱私權說明、留言板等）不需要連線就能用。
class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  LightstickService? _service;
  BluetoothDevice? _device;

  AppConfig _config = AppConfig.fallback();
  Timer? _pollTimer;

  static const _needsBle = {'custom_mode', 'concert_mode'};

  @override
  void initState() {
    super.initState();
    _loadConfig();
    // 每 15 秒自動重新拿一次遠端設定，管理後台關閉功能後，
    // 使用者不用重開 App 也能在短時間內看到「維護中」狀態
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadConfig());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await ApiService.fetchConfig();
    if (mounted && config != null) {
      setState(() => _config = config);
    }
  }

  /// 需要藍牙的模式：先確認有沒有連線，沒有就先跳出裝置選擇畫面
  Future<void> _ensureConnected() async {
    if (_device != null) return;
    final result = await Navigator.of(context).push<ConnectedLightstick>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _service = result.service;
        _device = result.device;
      });
    }
  }

  Future<void> _openMode(String featureKey, String title, Widget Function() builder) async {
    if (!_config.isEnabled(featureKey)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaintenanceScreen(
            title: title,
            message: _config.maintenanceMessage(featureKey),
          ),
        ),
      );
      return;
    }

    if (_needsBle.contains(featureKey)) {
      await _ensureConnected();
      if (_device == null) return; // 使用者取消了連線流程
    }

    if (!mounted) return;

    final isBleMode = _needsBle.contains(featureKey);
    if (isBleMode) {
      // 進入自訂模式/演唱會模式時，暫停背景輪詢設定的計時器，
      // 避免它在背景持續發網路請求，跟藍牙寫入搶資源
      _pollTimer?.cancel();
    }

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => builder()));

    if (isBleMode && mounted) {
      // 從模式畫面返回後，恢復背景輪詢
      _loadConfig();
      _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadConfig());
    }
  }

  Widget _modeCard({
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
      body: RefreshIndicator(
        onRefresh: _loadConfig,
        child: CustomScrollView(
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
                            Text(_device != null ? '已連線' : '尚未連線',
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11, color: Colors.white70, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                              _device?.platformName.isNotEmpty == true
                                  ? _device!.platformName
                                  : (_device != null ? '手燈裝置' : '點選下方模式即可連線'),
                              style: GoogleFonts.baloo2(
                                  fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
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
                    title: '自訂模式',
                    subtitle: '圓盤調色 + 閃爍開關',
                    icon: Icons.palette,
                    color: const Color(0xFFE05A8C),
                    onTap: () => _openMode(
                      'custom_mode',
                      '自訂模式',
                      () => CustomModeScreen(service: _service!, device: _device!),
                    ),
                  ),
                  _modeCard(
                    title: '團體模式',
                    subtitle: '開發中',
                    icon: Icons.groups,
                    color: const Color(0xFF6B7280),
                    onTap: () => _openMode('group_mode', '團體模式', () => const GroupModeScreen()),
                  ),
                  _modeCard(
                    title: '演唱會模式',
                    subtitle: '麥克風收音，音樂律動同步',
                    icon: Icons.music_note,
                    color: const Color(0xFF5F4B8B),
                    onTap: () => _openMode(
                      'concert_mode',
                      '演唱會模式',
                      () => ConcertModeScreen(service: _service!, device: _device!),
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
                    title: '隱私權說明',
                    subtitle: '我們如何使用你的權限',
                    icon: Icons.shield_outlined,
                    color: const Color(0xFF00ABC0),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                  ),
                  _modeCard(
                    title: '工作室介紹',
                    subtitle: '這個專案是怎麼來的',
                    icon: Icons.info_outline,
                    color: const Color(0xFFC9A86A),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const StudioScreen())),
                  ),
                  _modeCard(
                    title: '粉絲留言板',
                    subtitle: '公開留言，開發者會回覆',
                    icon: Icons.forum_outlined,
                    color: const Color(0xFFE05A8C),
                    onTap: () => _openMode('chat', '粉絲留言板', () => const BoardScreen()),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
