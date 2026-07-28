import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// ============================================================
/// BLE 核心邏輯：掃描、連線、自動找出可寫入的 characteristic、送封包
/// ============================================================
class LightstickService {
  BluetoothDevice? device;
  BluetoothCharacteristic? writeChar;

  /// 依照抓到的協定組封包：
  /// 01 01 0b 00 00 [R] [G] [B] 00 00 7e
  Uint8List buildColorPacket(int r, int g, int b) {
    return Uint8List.fromList([
      0x01, 0x01, 0x0b, 0x00, 0x00,
      r & 0xFF, g & 0xFF, b & 0xFF,
      0x00, 0x00, 0x7e,
    ]);
  }

  /// 連線後掃描所有 service / characteristic，
  /// 自動挑出支援 writeWithoutResponse 的那一個（對應我們抓到的 Write Command 0x52）。
  /// 如果之後發現抓錯，可以把這段改成用固定的 Service/Characteristic UUID 比對。
  Future<BluetoothCharacteristic?> discoverWritableCharacteristic(
      BluetoothDevice d) async {
    final services = await d.discoverServices();
    BluetoothCharacteristic? candidate;

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.writeWithoutResponse) {
          // 優先選 writeWithoutResponse，跟我們抓到的封包型態一致
          return c;
        }
        if (c.properties.write) {
          candidate ??= c; // 備用：如果找不到 writeWithoutResponse，退而求其次
        }
      }
    }
    return candidate;
  }

  Future<void> sendColor(int r, int g, int b) async {
    final c = writeChar;
    if (c == null) {
      throw Exception('尚未找到可寫入的 characteristic，請先連線裝置');
    }
    final packet = buildColorPacket(r, g, b);
    // withoutResponse: true 對應 ATT Write Command（跟原廠 App 行為一致）
    await c.write(packet, withoutResponse: true);
  }
}

/// ============================================================
/// 掃描畫面
/// ============================================================
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _sub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _results.clear();
      _scanning = true;
    });

    _sub?.cancel();
    _sub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        // 不再過濾掉沒有廣播名稱的裝置——很多手燈在連線前
        // 廣播封包裡不帶名稱，過濾掉會導致掃不到它們。
        // 改成依訊號強度排序，方便找到離手機最近（通常訊號最強）的裝置。
        final sorted = [...results]..sort((a, b) => b.rssi.compareTo(a.rssi));
        _results
          ..clear()
          ..addAll(sorted);
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _connect(BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('連線中...'),
          ],
        ),
      ),
    );

    try {
      await FlutterBluePlus.stopScan();
      await device.connect(timeout: const Duration(seconds: 10));

      final service = LightstickService();
      service.device = device;
      final char = await service.discoverWritableCharacteristic(device);

      if (!mounted) return;
      Navigator.of(context).pop(); // 關掉 loading dialog

      if (char == null) {
        _showError('找不到可寫入的 characteristic，可能需要手動指定 UUID');
        return;
      }

      service.writeChar = char;

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ColorControlScreen(service: service, device: device),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showError('連線失敗: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇手燈裝置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_scanning) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('共掃到 ${_results.length} 台裝置（含未知名稱）'),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(_scanning ? '掃描中...' : '沒有找到裝置，點右上角重新掃描'),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final r = _results[i];
                      final name = r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : '(未知名稱裝置)';
                      final serviceUuids = r.advertisementData.serviceUuids
                          .map((u) => u.toString())
                          .join(', ');
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(name),
                        subtitle: Text(
                          '${r.device.remoteId.str}'
                          '${serviceUuids.isNotEmpty ? '\nUUID: $serviceUuids' : ''}',
                        ),
                        isThreeLine: serviceUuids.isNotEmpty,
                        trailing: Text('${r.rssi} dBm'),
                        onTap: () => _connect(r.device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// 調色盤控制畫面
/// ============================================================
class ColorControlScreen extends StatefulWidget {
  final LightstickService service;
  final BluetoothDevice device;

  const ColorControlScreen({
    super.key,
    required this.service,
    required this.device,
  });

  @override
  State<ColorControlScreen> createState() => _ColorControlScreenState();
}

class _ColorControlScreenState extends State<ColorControlScreen> {
  int r = 255, g = 0, b = 0;
  bool _sending = false;
  Timer? _debounce;

  Color get currentColor => Color.fromARGB(255, r, g, b);

  // 滑桿拖動時做 debounce，避免狂送封包造成手燈延遲或掉包
  void _onColorChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 60), _send);
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.service.sendColor(r, g, b);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('送出失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _slider(String label, int value, ValueChanged<int> onChanged, Color trackColor) {
    return Row(
      children: [
        SizedBox(width: 24, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: trackColor,
            onChanged: (v) {
              onChanged(v.round());
              _onColorChanged();
            },
          ),
        ),
        SizedBox(width: 36, child: Text('$value')),
      ],
    );
  }

  final List<Color> _presets = const [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.blue,
    Colors.purple,
    Colors.pink,
    Colors.white,
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('已連線：${widget.device.platformName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${r.toRadixString(16).padLeft(2, '0')}'
                '${g.toRadixString(16).padLeft(2, '0')}'
                '${b.toRadixString(16).padLeft(2, '0')}'
                    .toUpperCase(),
                style: TextStyle(
                  color: (r + g + b) > 380 ? Colors.black : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _slider('R', r, (v) => setState(() => r = v), Colors.red),
            _slider('G', g, (v) => setState(() => g = v), Colors.green),
            _slider('B', b, (v) => setState(() => b = v), Colors.blue),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _presets.map((c) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      r = c.red;
                      g = c.green;
                      b = c.blue;
                    });
                    _send();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            if (_sending) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}