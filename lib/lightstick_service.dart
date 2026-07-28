import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE 核心邏輯：連線後自動找出可寫入的 characteristic、組封包、送出。
///
/// 已確認協定（透過 PacketLogger 逆向）：
///   換色：01 01 0b 00 00 [R] [G] [B] 00 00 7e
///
/// 尚未確認協定：
///   閃爍模式 —— 需要再抓一次官方 App 按下閃爍按鈕時的封包才能補上。
///   在補上之前，「軟體閃爍」（用換色協定快速在顏色/熄燈間切換）
///   是目前唯一能用的替代方案，見 concert_mode_screen.dart。
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
}
