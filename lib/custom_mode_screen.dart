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

  void _onColorChanged(Color c) {
    setState(() => _color = c);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 60), _send);
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
                    '尚未支援：閃爍指令的封包還沒抓取，'
                    '需要再用 PacketLogger 抓一次官方 App 按下閃爍時的封包才能開放',
                  ),
                  value: _blinkEnabled,
                  onChanged: null, // 停用，等協定補齊後再開放
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
