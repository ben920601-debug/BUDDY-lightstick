import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/lightstick_glyph.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  List<BoardPost> _posts = [];
  bool _loading = true;
  bool _posting = false;
  String? _userId;

  final _nicknameController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await ApiService.getAnonymousUserId();
    final prefs = await SharedPreferences.getInstance();
    _nicknameController.text = prefs.getString('board_nickname') ?? '';
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final posts = await ApiService.fetchBoard();
      if (mounted) setState(() => _posts = posts);
    } catch (_) {
      // 連不上就維持原本畫面，下拉重新整理時再試
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    final message = _messageController.text.trim();
    if (nickname.isEmpty || message.isEmpty || _userId == null || _posting) return;

    setState(() => _posting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('board_nickname', nickname);

    final ok = await ApiService.postBoard(_userId!, nickname, message);
    if (ok) {
      _messageController.clear();
      await _refresh();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('送出失敗，請稍後再試')));
    }
    if (mounted) setState(() => _posting = false);
  }

  Future<void> _report(int postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('檢舉這則留言'),
        content: const Text('檢舉後，開發者會收到通知並檢視這則內容。確定要送出嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定檢舉')),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.reportBoardPost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已送出檢舉')));
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: '粉絲留言板'),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: kCloudDancer,
            padding: const EdgeInsets.all(12),
            child: const Text(
              '歡迎進入粉絲留言版，此留言版為公開版，所有留言皆可見，留言前請務必三思且友善，謝謝您。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _loading && _posts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(child: LightstickGlyph(size: 64)),
                            SizedBox(height: 16),
                            Center(child: Text('還沒有留言，來寫下第一則吧', style: TextStyle(color: Colors.grey))),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _posts.length,
                          itemBuilder: (context, i) {
                            final p = _posts[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: kUltraViolet.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(p.nickname,
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: kUltraViolet)),
                                      ),
                                      InkWell(
                                        onTap: () => _report(p.id),
                                        child: const Icon(Icons.flag_outlined, size: 18, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(p.message, style: const TextStyle(fontSize: 14, height: 1.5)),
                                  if (p.adminReply != null && p.adminReply!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: kCloudDancer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('作者回覆',
                                              style: TextStyle(fontSize: 11, color: kScubaBlue, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(p.adminReply!, style: const TextStyle(fontSize: 13, height: 1.5)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      hintText: '暱稱',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: '想說的話...',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _posting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                        color: kUltraViolet,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
