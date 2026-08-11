import 'dart:async';
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
          .get(
            Uri.parse('$baseUrl/api/config'),
            headers: {'Cache-Control': 'no-cache'},
          )
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

  static Future<List<BoardPost>> fetchBoard() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/board'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      return (data['posts'] as List).map((p) => BoardPost.fromJson(p)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 回傳 null 代表成功；有內容代表失敗原因（給使用者看的友善訊息）
  static Future<String?> postBoard(String userId, String nickname, String message) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/board'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId, 'nickname': nickname, 'message': message}),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) return null;
      if (res.statusCode == 403) return '你目前無法在留言板發言';
      if (res.statusCode == 400) return '暱稱或內容格式有誤（可能太長），請修改後再試';
      return '伺服器暫時無法處理（錯誤碼 ${res.statusCode}），請稍後再試';
    } on TimeoutException {
      return '連線逾時，請確認網路狀況後再試';
    } catch (_) {
      return '連線失敗，請確認網路狀況後再試';
    }
  }

  static Future<void> reportBoardPost(int postId) async {
    await http.post(Uri.parse('$baseUrl/api/board/$postId/report'));
  }
}

class BoardPost {
  final int id;
  final String nickname;
  final String message;
  final String? adminReply;
  final String createdAt;

  BoardPost({
    required this.id,
    required this.nickname,
    required this.message,
    required this.adminReply,
    required this.createdAt,
  });

  factory BoardPost.fromJson(Map<String, dynamic> json) => BoardPost(
        id: json['id'],
        nickname: json['nickname'],
        message: json['message'],
        adminReply: json['admin_reply'],
        createdAt: json['created_at'] ?? '',
      );
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