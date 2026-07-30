import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_streamer/audio_streamer.dart';
import 'package:fftea/fftea.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble/lightstick_service.dart';
import '../main.dart';

/// 演唱會模式 v2
///
/// 跟 v1（單純音量突增閃燈）不同，這版做了真正的頻率分析：
/// - 用 audio_streamer 拿到麥克風的原始 PCM 波形
/// - 用 fftea 做 FFT，算出當下最主要的音高頻率、以及低頻能量
/// - 「自動選色」：色相隨音高即時變化（音高用對數尺度映射到色相，
///   低音偏紅、高音偏藍紫，是自己設計的映射方式，非科學上的聲光對應）
/// - 「手動選色」：從你勾選的顏色裡，每偵測到一次節拍就換下一個顏色
/// - 節拍偵測：低頻能量的移動平均 + 可調靈敏度，比純音量門檻穩定，
///   而且靈敏度做成滑桿，可以直接在畫面上調整，不用重新建置
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
  static const int _fftSize = 1024;
  static const double _minFreqHz = 80;
  static const double _maxFreqHz = 2000;

  StreamSubscription<List<double>>? _audioSub;
  Timer? _analysisTimer;
  FFT? _fft;

  final List<double> _ringBuffer = [];
  int _sampleRate = 44100;

  bool _listening = false;
  bool _permissionDenied = false;
  bool _bleBusy = false;

  double _currentFreq = 0;
  double _currentEnergy = 0;
  double _energyAvg = 0;
  int _beatCount = 0;
  DateTime _lastBeat = DateTime.fromMillisecondsSinceEpoch(0);

  // 節拍靈敏度：目前能量要比移動平均高出這個倍數才算一次節拍。
  // 數字越小越容易觸發（可能誤判雜音）、越大越不容易觸發（可能漏拍）。
  double _sensitivity = 1.6;
  static const Duration _minBeatGap = Duration(milliseconds: 180);

  bool _autoColorMode = true;
  Color _currentColor = kScubaBlue;

  final List<Color> _paletteCandidates = const [
    kUltraViolet,
    kScubaBlue,
    kCloudDancer,
    Colors.white,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
  ];
  final List<Color> _manualPalette = [kUltraViolet, kScubaBlue];
  int _manualIndex = 0;

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) return false;
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
      _energyAvg = 0;
      _ringBuffer.clear();
    });

    try {
      AudioStreamer().sampleRate = 44100;
      _audioSub = AudioStreamer().audioStream.listen(_onAudio, onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('收音失敗: $e')));
        }
        _stop();
      });
      _sampleRate = await AudioStreamer().actualSampleRate;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('無法啟動收音: $e')));
      }
      _stop();
      return;
    }

    _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _analyze();
    });
  }

  void _stop() {
    _audioSub?.cancel();
    _audioSub = null;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    if (mounted) setState(() => _listening = false);
  }

  void _onAudio(List<double> buffer) {
    _ringBuffer.addAll(buffer);
    if (_ringBuffer.length > _fftSize) {
      _ringBuffer.removeRange(0, _ringBuffer.length - _fftSize);
    }
  }

  double _hueFromFrequency(double freq) {
    final f = freq.clamp(_minFreqHz, _maxFreqHz);
    final t = (math.log(f) - math.log(_minFreqHz)) /
        (math.log(_maxFreqHz) - math.log(_minFreqHz));
    // 紅（低音）到藍紫（高音），不繞回紅色，避免高低音顏色混淆
    return (t * 280).clamp(0, 280);
  }

  void _analyze() {
    if (_ringBuffer.length < _fftSize) return;

    final window = Float64List.fromList(_ringBuffer);
    _fft ??= FFT(_fftSize);

    final freqData = _fft!.realFft(window);
    final mags = freqData.discardConjugates().magnitudes();

    final binHz = _sampleRate / _fftSize;
    final minBin = math.max(1, (_minFreqHz / binHz).round());
    final maxBin = math.min(mags.length - 1, (_maxFreqHz / binHz).round());

    double peakMag = 0;
    int peakBin = minBin;
    double energy = 0;
    for (var i = minBin; i <= maxBin; i++) {
      energy += mags[i];
      if (mags[i] > peakMag) {
        peakMag = mags[i];
        peakBin = i;
      }
    }
    final dominantFreq = peakBin * binHz;

    _energyAvg = _energyAvg == 0 ? energy : (_energyAvg * 0.85 + energy * 0.15);

    final now = DateTime.now();
    final isBeat = energy > _energyAvg * _sensitivity &&
        peakMag > 0.001 &&
        now.difference(_lastBeat) > _minBeatGap;

    Color colorToUse = _autoColorMode
        ? HSVColor.fromAHSV(1, _hueFromFrequency(dominantFreq), 1, 1).toColor()
        : (_manualPalette.isEmpty
            ? Colors.white
            : _manualPalette[_manualIndex % _manualPalette.length]);

    setState(() {
      _currentFreq = dominantFreq;
      _currentEnergy = energy;
      _currentColor = colorToUse;
    });

    if (isBeat) {
      _lastBeat = now;
      _beatCount++;
      if (!_autoColorMode && _manualPalette.isNotEmpty) {
        _manualIndex++;
        colorToUse = _manualPalette[_manualIndex % _manualPalette.length];
        setState(() => _currentColor = colorToUse);
      }
      _flash(colorToUse);
    } else {
      _sendSolid(colorToUse);
    }
  }

  /// BLE 送出用同一個忙碌旗標擋住，避免上一次還沒送完就疊加新的送出，
  /// 造成藍牙塞車、動畫變得延遲混亂。忙碌時就跳過這一個 tick，
  /// 下一個 tick（100ms 後）再試。
  Future<void> _sendSolid(Color c) async {
    if (_bleBusy) return;
    _bleBusy = true;
    try {
      await widget.service.sendColor(c.red, c.green, c.blue);
    } catch (_) {}
    _bleBusy = false;
  }

  Future<void> _flash(Color c) async {
    if (_bleBusy) return;
    _bleBusy = true;
    try {
      await widget.service.sendColor(c.red, c.green, c.blue);
      await Future.delayed(const Duration(milliseconds: 60));
      await widget.service.turnOff();
      await Future.delayed(const Duration(milliseconds: 60));
      await widget.service.sendColor(c.red, c.green, c.blue);
    } catch (_) {}
    _bleBusy = false;
  }

  void _togglePreset(Color c) {
    setState(() {
      if (_manualPalette.any((e) => e.value == c.value)) {
        if (_manualPalette.length > 1) {
          _manualPalette.removeWhere((e) => e.value == c.value);
        }
      } else {
        _manualPalette.add(c);
      }
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('演唱會模式')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                height: 70,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _currentColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 2),
                ),
              ),
              const SizedBox(height: 16),
              if (_permissionDenied)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      const Text('沒有麥克風權限，App 才能收音分析',
                          style: TextStyle(color: Colors.red)),
                      TextButton(
                        onPressed: openAppSettings,
                        child: const Text('前往系統設定開啟權限'),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('目前音高: ${_currentFreq.toStringAsFixed(0)} Hz'),
                  Text('已觸發節拍: $_beatCount'),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (_currentEnergy / (_energyAvg == 0 ? 1 : _energyAvg * 3))
                    .clamp(0, 1),
                minHeight: 10,
              ),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('節奏靈敏度：${_sensitivity.toStringAsFixed(2)}'),
              ),
              Slider(
                value: _sensitivity,
                min: 1.1,
                max: 3.0,
                divisions: 19,
                label: _sensitivity.toStringAsFixed(2),
                onChanged: (v) => setState(() => _sensitivity = v),
              ),
              const Text(
                '數字越小越容易觸發節拍（可能誤判雜音），越大越不容易觸發（可能漏拍），可以邊放音樂邊調',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('自動選色'), icon: Icon(Icons.auto_awesome)),
                  ButtonSegment(value: false, label: Text('手動選色'), icon: Icon(Icons.palette)),
                ],
                selected: {_autoColorMode},
                onSelectionChanged: (s) => setState(() => _autoColorMode = s.first),
              ),
              const SizedBox(height: 8),
              if (_autoColorMode)
                const Text(
                  '顏色隨音高即時變化：低音偏紅、高音偏藍紫',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else ...[
                const Text(
                  '勾選要循環使用的顏色，每次節拍會切換到下一個',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _paletteCandidates.map((c) {
                    final selected = _manualPalette.any((e) => e.value == c.value);
                    return GestureDetector(
                      onTap: () => _togglePreset(c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? kUltraViolet : Colors.black26,
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child: selected
                            ? Icon(Icons.check,
                                color: c.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),

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
