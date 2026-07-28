import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../ble/lightstick_service.dart';

class CustomModeScreen extends StatefulWidget {
  final LightstickService service;
  final BluetoothDevice device;

  const CustomModeScreen({
    super.key,
    required this.service,
    required this.device,
  });

  @override
  State<CustomModeScreen> createState() => _CustomModeScreenState();
}

class _CustomModeScreenState extends State<CustomModeScreen> {
  Color _color = Colors.red;
  bool _blinkEnabled = false;
  bool _sending = false;
  Timer? _debounce;
  Timer? _blinkTimer;

  // 從實測封包分析出來的：官方 App 的閃爍其實就是用已知的換色指令，
  // 在「設定顏色」跟「熄燈（RGB 000000）」之間快速交替，沒有專屬的閃爍指令。
  // 實測間隔大約 120~200ms，這裡取中間值。
  static const Duration _blinkInterval = Duration(milliseconds: 160);

  void _onColorChanged(Color c) {
    setState(() => _color = c);
    if (_blinkEnabled) {
      // 閃爍計時器會在下一次「亮燈」的 tick 自動用上最新的 _color，
      // 這裡不用額外送出，避免跟閃爍節奏互相打架造成畫面卡頓
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 30), _send);
  }

  void _toggleBlink(bool enabled) {
    setState(() => _blinkEnabled = enabled);
    if (enabled) {
      _startBlink();
    } else {
      _stopBlink();
      _send(); // 關閉閃爍後，把手燈恢復成目前選的顏色（常亮）
    }
  }

  void _startBlink() {
    _blinkTimer?.cancel();
    bool lightOn = true;
    _blinkTimer = Timer.periodic(_blinkInterval, (_) async {
      try {
        if (lightOn) {
          await widget.service.sendColor(_color.red, _color.green, _color.blue);
        } else {
          await widget.service.turnOff();
        }
        lightOn = !lightOn;
      } catch (_) {
        // 單次送出失敗先忽略，下一個 tick 再試，避免閃爍中斷
      }
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.service.sendColor(_color.red, _color.green, _color.blue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('送出失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自訂模式')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${_color.red.toRadixString(16).padLeft(2, '0')}'
                  '${_color.green.toRadixString(16).padLeft(2, '0')}'
                  '${_color.blue.toRadixString(16).padLeft(2, '0')}'
                      .toUpperCase(),
                  style: TextStyle(
                    color: _color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 圓盤調色，帶漸層感，拖動即時更新
              HueRingPicker(
                pickerColor: _color,
                onColorChanged: _onColorChanged,
                displayThumbColor: true,
                enableAlpha: false,
              ),
              const SizedBox(height: 12),
              if (_sending) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: const Text('閃爍模式'),
                  subtitle: const Text(
                    '交替送出「亮燈色」與「熄燈」封包做出閃爍效果，'
                    '跟官方 App 的實作方式相同',
                  ),
                  value: _blinkEnabled,
                  onChanged: _toggleBlink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}