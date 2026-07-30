import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/lightstick_service.dart';
import '../main.dart';
import '../widgets/color_wheel_picker.dart';

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
  Color _color = kScubaBlue;
  bool _blinkEnabled = false;
  bool _sending = false;
  Color? _pendingColor;

  Timer? _blinkTimer;
  // 從實測封包分析出來的：官方 App 的閃爍是快速交替送出
  // 「設定顏色」跟「熄燈（RGB 000000）」封包，沒有專屬指令。
  // 實測間隔大約 120~200ms，這裡取中間值。
  static const Duration _blinkInterval = Duration(milliseconds: 160);

  final List<Color> _presets = const [
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

  void _onColorChanged(Color c) {
    setState(() => _color = c);
    if (_blinkEnabled) {
      // 連續閃爍計時器會在下一次「亮燈」的 tick 自動用上最新的 _color
      return;
    }
    _sendLatestImmediately();
  }

  /// 不用 debounce，滑動當下馬上送出；如果上一次還在傳輸中，
  /// 就記住最新顏色，等上一次傳完立刻接著送，確保手燈跟畫面幾乎同步。
  Future<void> _sendLatestImmediately() async {
    _pendingColor = _color;
    if (_sending) return;
    _sending = true;
    while (_pendingColor != null) {
      final toSend = _pendingColor!;
      _pendingColor = null;
      try {
        await widget.service.sendColor(toSend.red, toSend.green, toSend.blue);
      } catch (_) {
        // 單次失敗先忽略，拖動還在繼續的話下一個顏色會馬上補上
      }
    }
    _sending = false;
  }

  Future<void> _pickPreset(Color c) async {
    setState(() => _color = c);
    if (!_blinkEnabled) {
      await _sendLatestImmediately();
    }
  }

  Future<void> _singleFlash() async {
    if (_blinkEnabled) return; // 連續閃爍中不重複觸發單次閃爍
    try {
      await widget.service.sendColor(_color.red, _color.green, _color.blue);
      await Future.delayed(const Duration(milliseconds: 120));
      await widget.service.turnOff();
      await Future.delayed(const Duration(milliseconds: 120));
      await widget.service.sendColor(_color.red, _color.green, _color.blue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('閃爍失敗: $e')));
      }
    }
  }

  void _toggleContinuousBlink(bool enabled) {
    setState(() => _blinkEnabled = enabled);
    if (enabled) {
      _startBlink();
    } else {
      _stopBlink();
      _sendLatestImmediately(); // 關閉後恢復常亮
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
      } catch (_) {}
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  @override
  void dispose() {
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
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 2),
                ),
              ),
              const SizedBox(height: 20),
              // 圓盤調色，拖動即時同步（見 _onColorChanged）
              Center(
                child: ColorWheelPicker(
                  color: _color,
                  onColorChanged: _onColorChanged,
                  size: 280,
                ),
              ),
              const SizedBox(height: 12),
              if (_sending) const LinearProgressIndicator(),
              const SizedBox(height: 16),

              // 單次閃爍 + 連續閃爍開關
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _blinkEnabled ? null : _singleFlash,
                      icon: const Icon(Icons.flash_on),
                      label: const Text('單次閃爍'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: SwitchListTile(
                        dense: true,
                        title: const Text('連續閃爍'),
                        value: _blinkEnabled,
                        onChanged: _toggleContinuousBlink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('常用顏色',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presets.map((c) {
                  final selected = c.value == _color.value;
                  return GestureDetector(
                    onTap: () => _pickPreset(c),
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
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
