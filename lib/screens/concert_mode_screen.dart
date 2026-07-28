import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble/lightstick_service.dart';

/// 演唱會模式（測試版原型）
///
/// 做法說明：
/// - iOS 不允許讀取其他 App（例如 YouTube）正在播放的音訊，這是系統層級的
///   沙盒限制，沒有繞過的方法。這裡改用「手機麥克風收現場聲音」的標準做法
///   ——跟市面上手燈同步 App 的原理一致，不需要知道音樂從哪個 App 播放。
/// - 目前是「音量突增偵測」的簡化版節奏同步：不是真的音高辨識 AI，而是
///   用麥克風分貝值的移動平均，偵測到明顯的音量跳動（節拍/鼓點）時觸發閃燈。
///   這是可以馬上動起來的 MVP，之後如果要做更精準的音高/節奏辨識，
///   可以在這個基礎上換成更進階的訊號處理或串接你規劃的 Python 分析後端。
/// - 閃爍效果目前是用已知的「換色協定」快速切換顏色/熄燈做出來的「軟體閃爍」，
///   不依賴尚未抓取的專屬閃爍指令。
class ConcertModeScreen extends StatefulWidget {
  final LightstickService service;
  final BluetoothDevice device;

  const ConcertModeScreen({
    super.key,
    required this.service,
    required this.device,
  });

  @override
  State<ConcertModeScreen> createState() => _ConcertModeScreenState();
}

class _ConcertModeScreenState extends State<ConcertModeScreen> {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSub;
  bool _listening = false;
  bool _permissionDenied = false;

  double _currentDb = 0;
  double _rollingAvgDb = 0;
  int _beatCount = 0;
  DateTime _lastFlash = DateTime.fromMillisecondsSinceEpoch(0);

  // 觸發閃燈的門檻：目前分貝比移動平均高出這個數值，視為一次節拍
  static const double _beatThresholdDb = 6.0;
  // 兩次閃燈之間至少間隔多久，避免同一個節拍觸發太多次
  static const Duration _minFlashGap = Duration(milliseconds: 180);

  Color _flashColor = Colors.pinkAccent;

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _start() async {
    final granted = await _ensureMicPermission();
    if (!granted) {
      setState(() => _permissionDenied = true);
      return;
    }
    setState(() {
      _permissionDenied = false;
      _listening = true;
      _beatCount = 0;
      _rollingAvgDb = 0;
    });

    _noiseMeter = NoiseMeter();
    _noiseSub = _noiseMeter!.noise.listen(_onNoiseReading, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('收音失敗: $e')));
      }
      _stop();
    });
  }

  void _stop() {
    _noiseSub?.cancel();
    _noiseSub = null;
    setState(() => _listening = false);
  }

  void _onNoiseReading(NoiseReading reading) {
    final db = reading.meanDecibel;
    if (!db.isFinite) return;

    setState(() {
      _currentDb = db;
      // 簡單的移動平均，當作背景音量基準線
      _rollingAvgDb = _rollingAvgDb == 0 ? db : (_rollingAvgDb * 0.9 + db * 0.1);
    });

    final now = DateTime.now();
    final isBeat = db - _rollingAvgDb > _beatThresholdDb;
    final gapOk = now.difference(_lastFlash) > _minFlashGap;

    if (isBeat && gapOk) {
      _lastFlash = now;
      setState(() => _beatCount++);
      _flash();
    }
  }

  Future<void> _flash() async {
    try {
      await widget.service
          .sendColor(_flashColor.red, _flashColor.green, _flashColor.blue);
      // 短暫延遲後熄燈，做出「閃」的效果（軟體閃爍，靠換色協定實現）
      await Future.delayed(const Duration(milliseconds: 80));
      await widget.service.turnOff();
    } catch (_) {
      // 演唱會現場藍牙訊號可能不穩，單次送出失敗先忽略，等下一個節拍再試
    }
  }

  @override
  void dispose() {
    _noiseSub?.cancel();
    super.dispose();
  }

  final List<Color> _presets = const [
    Colors.pinkAccent,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.blue,
    Colors.purple,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('演唱會模式（測試版）')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                color: Colors.deepPurple.withOpacity(0.08),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '目前是「音量突增觸發閃燈」的測試版原型，用手機麥克風收現場聲音，'
                    '偵測到明顯節拍就閃一下，還不是真正的音高辨識。',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_permissionDenied)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '沒有麥克風權限，請到「設定 → 隱私權 → 麥克風」開啟後再試一次',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              Text('目前音量: ${_currentDb.toStringAsFixed(1)} dB',
                  style: const TextStyle(fontSize: 18)),
              Text('背景基準: ${_rollingAvgDb.toStringAsFixed(1)} dB',
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Text('已觸發節拍次數: $_beatCount',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: (_currentDb / 100).clamp(0, 1),
                minHeight: 12,
              ),
              const SizedBox(height: 24),
              const Text('閃燈顏色'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: _presets.map((c) {
                  final selected = c.value == _flashColor.value;
                  return GestureDetector(
                    onTap: () => setState(() => _flashColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.black26,
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Text(_listening ? '停止收音' : '開始收音同步'),
                  onPressed: _listening ? _stop : _start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
