import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:fftea/fftea.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../ble/lightstick_service.dart';
import '../main.dart';

/// 演唱會模式 v3
///
/// 跟 v2 的差異：
/// - 錄音引擎從 audio_streamer 換成 record，跟 audio_session 搭配更穩定，
///   解決錄音時手機喇叭外放音樂被降級成通話音質的問題
/// - FFT 視窗從 1024 加大到 2048（頻率解析度更細），且套用 Hann 窗函數
///   減少頻譜洩漏，音高判斷更準
/// - 用諧波乘積頻譜（Harmonic Product Spectrum）取代單純抓最大峰值，
///   避免常見的「抓到泛音、不是真正基音」的誤判
/// - 手動模式也會隨音量連續調整亮度，不再只有節拍那一瞬間才有反應
/// - 新增「高潮偵測」：能量持續明顯高於這首歌的長期平均一段時間，
///   判定進入高潮，改成連續閃爍；能量降回正常水準才切回原本的模式
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
  static const int _fftSize = 2048;
  static const double _minFreqHz = 80;
  static const double _maxFreqHz = 2000;
  static const int _sampleRate = 44100;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  Timer? _analysisTimer;
  FFT? _fft;
  final List<double> _hannWindow = Window.hanning(_fftSize);

  final List<double> _ringBuffer = [];

  bool _listening = false;
  bool _permissionDenied = false;
  bool _bleBusy = false;

  double _currentFreq = 0;
  double _currentEnergy = 0;
  double _energyAvg = 0; // 短期移動平均：抓單次節拍用
  double _longEnergyAvg = 0; // 長期移動平均：這首歌大概多大聲的基準，判斷高潮用
  int _beatCount = 0;
  DateTime _lastBeat = DateTime.fromMillisecondsSinceEpoch(0);

  double _sensitivity = 1.6;
  static const Duration _minBeatGap = Duration(milliseconds: 180);

  // 高潮偵測：能量要「持續」比長期平均高出這個倍數一段時間才算數
  double _climaxRatio = 1.8;
  static const Duration _climaxSustain = Duration(milliseconds: 700);
  static const double _climaxExitRatio = 1.2; // 降到這個倍數以下才判定離開高潮
  DateTime? _climaxCandidateStart;
  bool _climaxActive = false;

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

  /// 明確設定音訊工作階段，讓錄音時手機喇叭外放不被降級成通話音質：
  /// 輸出優先走喇叭、不打斷其他 App 播放、用 measurement 模式減少
  /// 系統自動的降噪／回音消除（這些是給通話設計的，會扭曲我們要分析的波形）
  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
          AVAudioSessionCategoryOptions.mixWithOthers |
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.measurement,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    ));
    await session.setActive(true);
  }

  Future<void> _start() async {
    final granted = await _ensureMicPermission();
    if (!granted) {
      setState(() => _permissionDenied = true);
      return;
    }
    if (!await _recorder.hasPermission()) {
      setState(() => _permissionDenied = true);
      return;
    }

    setState(() {
      _permissionDenied = false;
      _listening = true;
      _beatCount = 0;
      _energyAvg = 0;
      _longEnergyAvg = 0;
      _climaxActive = false;
      _climaxCandidateStart = null;
      _ringBuffer.clear();
    });

    try {
      // 順序很重要：先設定好 audio session，再啟動錄音串流，
      // 這樣「輸出走喇叭」的設定才不會被錄音套件自己的初始化蓋掉
      await _configureAudioSession();

      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        echoCancel: false,
        noiseSuppress: false,
        autoGain: false,
      ));
      _audioSub = stream.listen(_onAudio, onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('收音失敗: $e')));
        }
        _stop();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('無法啟動收音: $e')));
      }
      _stop();
      return;
    }

    _analysisTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) => _analyze());
  }

  void _stop() {
    _audioSub?.cancel();
    _audioSub = null;
    _recorder.stop();
    _analysisTimer?.cancel();
    _analysisTimer = null;
    AudioSession.instance.then((s) => s.setActive(
          false,
          avAudioSessionSetActiveOptions:
              AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        ));
    if (mounted) setState(() => _listening = false);
  }

  void _onAudio(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final sample = data.getInt16(i * 2, Endian.little);
      _ringBuffer.add(sample / 32768.0);
    }
    if (_ringBuffer.length > _fftSize) {
      _ringBuffer.removeRange(0, _ringBuffer.length - _fftSize);
    }
  }

  double _hueFromFrequency(double freq) {
    final f = freq.clamp(_minFreqHz, _maxFreqHz);
    final t = (math.log(f) - math.log(_minFreqHz)) /
        (math.log(_maxFreqHz) - math.log(_minFreqHz));
    return (t * 280).clamp(0, 280);
  }

  void _analyze() {
    if (_ringBuffer.length < _fftSize) return;

    final window = Float64List(_fftSize);
    for (var i = 0; i < _fftSize; i++) {
      window[i] = _ringBuffer[i] * _hannWindow[i];
    }

    _fft ??= FFT(_fftSize);
    final freqData = _fft!.realFft(window);
    final mags = freqData.discardConjugates().magnitudes();

    final binHz = _sampleRate / _fftSize;
    final minBin = math.max(1, (_minFreqHz / binHz).round());
    final maxBin = math.min(mags.length - 1, (_maxFreqHz / binHz).round());

    // 諧波乘積頻譜：頻譜降採樣 2~4 倍後相乘，避免抓到泛音當作基音
    final hps = List<double>.filled(maxBin + 1, 0);
    for (var i = minBin; i <= maxBin; i++) {
      var v = mags[i];
      for (final factor in [2, 3, 4]) {
        final idx = i * factor;
        if (idx < mags.length) v *= mags[idx];
      }
      hps[i] = v;
    }

    double peakScore = 0;
    int peakBin = minBin;
    double energy = 0;
    for (var i = minBin; i <= maxBin; i++) {
      energy += mags[i];
      if (hps[i] > peakScore) {
        peakScore = hps[i];
        peakBin = i;
      }
    }
    final dominantFreq = peakBin * binHz;

    _energyAvg = _energyAvg == 0 ? energy : (_energyAvg * 0.85 + energy * 0.15);
    _longEnergyAvg =
        _longEnergyAvg == 0 ? energy : (_longEnergyAvg * 0.97 + energy * 0.03);

    final now = DateTime.now();
    final isBeat = energy > _energyAvg * _sensitivity &&
        peakScore > 1e-9 &&
        now.difference(_lastBeat) > _minBeatGap;

    // 高潮偵測：要「持續」比長期平均高出 _climaxRatio 倍撐過 _climaxSustain
    // 才算數，避免單一個大聲鼓點就誤判
    final aboveClimax = _longEnergyAvg > 0 && energy > _longEnergyAvg * _climaxRatio;
    if (aboveClimax) {
      _climaxCandidateStart ??= now;
      if (!_climaxActive &&
          now.difference(_climaxCandidateStart!) > _climaxSustain) {
        _climaxActive = true;
      }
    } else {
      _climaxCandidateStart = null;
      if (_climaxActive && energy < _longEnergyAvg * _climaxExitRatio) {
        _climaxActive = false;
      }
    }

    final autoColor =
        HSVColor.fromAHSV(1, _hueFromFrequency(dominantFreq), 1, 1).toColor();

    // 手動模式也讓亮度隨音量連續變化，不是只有節拍那一瞬間才有反應
    final energyRatio = _longEnergyAvg == 0
        ? 1.0
        : (energy / (_longEnergyAvg * 2)).clamp(0.35, 1.0);
    Color manualColorAt(Color base) =>
        HSVColor.fromColor(base).withValue(energyRatio).toColor();

    Color colorToUse = _autoColorMode
        ? autoColor
        : manualColorAt(
            _manualPalette.isEmpty ? Colors.white : _manualPalette[_manualIndex % _manualPalette.length]);

    setState(() {
      _currentFreq = dominantFreq;
      _currentEnergy = energy;
      _currentColor = colorToUse;
    });

    if (_climaxActive) {
      // 高潮中：不管平常邏輯，直接用目前顏色連續閃爍
      _flash(colorToUse);
      return;
    }

    if (isBeat) {
      _lastBeat = now;
      _beatCount++;
      if (!_autoColorMode && _manualPalette.isNotEmpty) {
        _manualIndex++;
        colorToUse =
            manualColorAt(_manualPalette[_manualIndex % _manualPalette.length]);
        setState(() => _currentColor = colorToUse);
      }
      _flash(colorToUse);
    } else {
      _sendSolid(colorToUse);
    }
  }

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
                  border: Border.all(
                    color: _climaxActive ? Colors.red : Colors.black12,
                    width: _climaxActive ? 3 : 2,
                  ),
                ),
                alignment: Alignment.center,
                child: _climaxActive
                    ? const Text('🔥 高潮模式',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black45)]))
                    : null,
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('高潮靈敏度：${_climaxRatio.toStringAsFixed(2)}'),
              ),
              Slider(
                value: _climaxRatio,
                min: 1.3,
                max: 3.0,
                divisions: 17,
                label: _climaxRatio.toStringAsFixed(2),
                onChanged: (v) => setState(() => _climaxRatio = v),
              ),
              const Text(
                '數字越小越容易進入高潮模式（可能太敏感），越大越難觸發（需要更明顯的高潮段落），可以邊放音樂邊調',
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
                  '勾選要循環使用的顏色，每次節拍會切換到下一個，亮度也會隨音量變化',
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
