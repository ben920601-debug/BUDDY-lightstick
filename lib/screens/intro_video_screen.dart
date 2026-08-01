import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import 'scan_screen.dart';

class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  late final VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/video/intro.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.setVolume(0); // 靜音播放，不用重新處理影片檔案
        _controller.play();
      });
    _controller.addListener(_onTick);
  }

  void _onTick() {
    final value = _controller.value;
    // 影片播完（且不是因為使用者拖動進度條回到中間）就自動跳轉
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration &&
        value.duration > Duration.zero) {
      _goNext();
    }
  }

  void _goNext() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kUltraViolet,
      body: Stack(
        children: [
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          Positioned(
            right: 16,
            top: 48,
            child: SafeArea(
              child: TextButton(
                onPressed: _goNext,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black26,
                ),
                child: const Text('跳過'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
