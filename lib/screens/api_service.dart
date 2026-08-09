import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 跟後端溝通的服務。
/// baseUrl 部署完成後要換成你自己 VPS 的網址，例如：
/// https://api.yourdomain.com
class ApiService {
  static const String baseUrl = 'https://buddyapi.ricecook.org';

  static Future<String> getAnonymousUserId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('anon_user_id');
    if (id == null) {
      id = DateTime.now().microsecondsSinceEpoch.toString() +
          '-' +
          (1000 + DateTime.now().millisecond).toString();
      await prefs.setString('anon_user_id', id);
    }
    return id;
  }

  static Future<AppConfig?> fetchConfig() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/config'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      return AppConfig.fromJson(jsonDecode(res.body));
    } catch (_) {
      return null; // 連不上就當作沒有遠端設定，App 端要有合理的預設值
    }
  }

  static Future<List<ChatMessage>> fetchChat(String userId, {int since = 0}) async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/chat?user_id=$userId&since=$since'))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return (data['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList();
  }

  static Future<bool> sendChat(String userId, String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'message': message}),
    );
    return res.statusCode == 200;
  }

  static Future<void> reportChat(String userId) async {
    await http.post(
      Uri.parse('$baseUrl/api/chat/report'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
  }
}

class AppConfig {
  final String marqueeText;
  final String marqueeColor;
  final int marqueeSpeed;
  final Map<String, FeatureFlag> features;

  AppConfig({
    required this.marqueeText,
    required this.marqueeColor,
    required this.marqueeSpeed,
    required this.features,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final featuresJson = json['features'] as Map<String, dynamic>? ?? {};
    return AppConfig(
      marqueeText: json['marquee']?['text'] ?? '',
      marqueeColor: json['marquee']?['color'] ?? '#5F4B8B',
      marqueeSpeed: json['marquee']?['speed'] ?? 50,
      features: featuresJson.map(
        (k, v) => MapEntry(k, FeatureFlag(enabled: v['enabled'] ?? true, message: v['message'] ?? '')),
      ),
    );
  }

  /// 連不上伺服器時的預設值：所有功能照常開放，不顯示跑馬燈
  factory AppConfig.fallback() => AppConfig(
        marqueeText: '',
        marqueeColor: '#5F4B8B',
        marqueeSpeed: 50,
        features: const {},
      );

  bool isEnabled(String key) => features[key]?.enabled ?? true;
  String maintenanceMessage(String key) => features[key]?.message ?? '此功能維護中，敬請期待';
}

class FeatureFlag {
  final bool enabled;
  final String message;
  FeatureFlag({required this.enabled, required this.message});
}

class ChatMessage {
  final int id;
  final String sender; // 'fan' or 'admin'
  final String message;
  final int ts;

  ChatMessage({required this.id, required this.sender, required this.message, required this.ts});

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        sender: json['sender'],
        message: json['message'],
        ts: json['ts'],
      );
}
