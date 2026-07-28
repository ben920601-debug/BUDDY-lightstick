import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble/lightstick_service.dart';
import 'mode_select_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _sub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _scanning = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      setState(() => _adapterState = state);
      if (state == BluetoothAdapterState.on && !_scanning) {
        _startScan();
      }
    });
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _startScan() async {
    setState(() {
      _results.clear();
      _scanning = true;
      _lastError = null;
    });

    _sub?.cancel();
    _sub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        final sorted = [...results]..sort((a, b) => b.rssi.compareTo(a.rssi));
        _results
          ..clear()
          ..addAll(sorted);
      });
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } catch (e) {
      setState(() => _lastError = '掃描失敗: $e');
    }
    setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _adapterSub?.cancel();
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
      Navigator.of(context).pop();

      if (char == null) {
        _showError('找不到可寫入的 characteristic，可能需要手動指定 UUID');
        return;
      }

      service.writeChar = char;

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ModeSelectScreen(service: service, device: device),
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
          Container(
            width: double.infinity,
            color: _adapterState == BluetoothAdapterState.on
                ? Colors.green.withOpacity(0.15)
                : Colors.red.withOpacity(0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('藍牙狀態: ${_adapterState.name}'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('共掃到 ${_results.length} 台裝置（含未知名稱）'),
          ),
          if (_lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  Text(_lastError!, style: const TextStyle(color: Colors.red)),
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
