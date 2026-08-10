import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE 核心邏輯：連線後自動找出可寫入的 characteristic、組封包、送出。
///
/// 已確認協定（透過 PacketLogger 逆向）：
///   換色：01 01 0b 00 00 [R] [G] [B] 00 00 7e
///   閃爍：沒有專屬指令，是快速交替送出「換色」與「熄燈（RGB 000000）」
///        兩個封包做出來的效果，實測官方 App 間隔約 120~200ms。
///        見 custom_mode_screen.dart 的 _blinkTimer 實作。
class LightstickService {
  BluetoothDevice? device;
  BluetoothCharacteristic? writeChar;

  Uint8List buildColorPacket(int r, int g, int b) {
    return Uint8List.fromList([
      0x01, 0x01, 0x0b, 0x00, 0x00,
      r & 0xFF, g & 0xFF, b & 0xFF,
      0x00, 0x00, 0x7e,
    ]);
  }

  Future<BluetoothCharacteristic?> discoverWritableCharacteristic(
      BluetoothDevice d) async {
    final services = await d.discoverServices();
    BluetoothCharacteristic? candidate;

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.writeWithoutResponse) {
          return c;
        }
        if (c.properties.write) {
          candidate ??= c;
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
    await c.write(packet, withoutResponse: true);
  }

  Future<void> turnOff() async {
    await sendColor(0, 0, 0);
  }

  /// 斷線後重新連接：重新建立連線、重新找一次可寫入的 characteristic。
  /// 成功回傳 true，失敗回傳 false（呼叫端可以顯示錯誤訊息）。
  Future<bool> reconnect() async {
    final d = device;
    if (d == null) return false;
    try {
      await d.connect(timeout: const Duration(seconds: 10));
      final c = await discoverWritableCharacteristic(d);
      if (c == null) return false;
      writeChar = c;
      return true;
    } catch (_) {
      return false;
    }
  }
}
