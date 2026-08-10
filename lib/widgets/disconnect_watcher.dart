import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/lightstick_service.dart';
import '../main.dart';

/// 監聽藍牙連線狀態，斷線時跳出提示，讓使用者選擇重新連接或返回。
/// 用法：在需要用到手燈的畫面（例如自訂模式、演唱會模式）的
/// initState 呼叫 `attach(context)`，dispose 呼叫 `detach()`。
class DisconnectWatcher {
  final BluetoothDevice device;
  final LightstickService service;
  final VoidCallback onGoBack;

  BluetoothConnectionState? _lastState;
  bool _dialogShowing = false;
  late final Stream<BluetoothConnectionState> _stream;
  StreamSubscription<BluetoothConnectionState>? _sub;

  DisconnectWatcher({
    required this.device,
    required this.service,
    required this.onGoBack,
  }) {
    _stream = device.connectionState.asBroadcastStream();
  }

  void attach(BuildContext context) {
    _sub = _stream.listen((state) {
      // ignore: avoid_print
      print('[BLE] ${DateTime.now().toIso8601String()} 連線狀態變化: $_lastState -> $state');
      // 剛連線成功的第一次狀態變化不用管，只在「原本是連上的，變成斷線」才處理
      if (_lastState == BluetoothConnectionState.connected &&
          state == BluetoothConnectionState.disconnected &&
          !_dialogShowing) {
        _showReconnectDialog(context);
      }
      _lastState = state;
    });
  }

  Future<void> _showReconnectDialog(BuildContext context) async {
    _dialogShowing = true;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('手燈已斷線'),
        content: const Text('跟手燈的藍牙連線中斷了，要重新連接嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'back'), child: const Text('返回選單')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kUltraViolet),
            onPressed: () => Navigator.pop(context, 'reconnect'),
            child: const Text('重新連接'),
          ),
        ],
      ),
    );

    _dialogShowing = false;

    if (choice == 'reconnect') {
      final ok = await _attemptReconnect(context);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重新連接失敗，請返回選單再試一次')),
        );
      }
    } else {
      onGoBack();
    }
  }

  Future<bool> _attemptReconnect(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('重新連接中...'),
          ],
        ),
      ),
    );
    final ok = await service.reconnect();
    if (context.mounted) Navigator.of(context).pop(); // 關掉 loading dialog
    return ok;
  }

  void detach() {
    _sub?.cancel();
  }
}