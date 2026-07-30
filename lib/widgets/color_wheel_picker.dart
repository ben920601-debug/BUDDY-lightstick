import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 圓盤調色元件：角度＝色相（Hue），距離中心的遠近＝飽和度（Saturation）。
/// 中心是白色，往外漸層到飽和的彩色，跟參考圖樣式一致。
class ColorWheelPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;
  final double size;

  const ColorWheelPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
    this.size = 280,
  });

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  late double _hue;
  late double _saturation;

  static const _wheelColors = [
    Color(0xFFFF0000), // 0°   紅
    Color(0xFFFFFF00), // 60°  黃
    Color(0xFF00FF00), // 120° 綠
    Color(0xFF00FFFF), // 180° 青
    Color(0xFF0000FF), // 240° 藍
    Color(0xFFFF00FF), // 300° 洋紅
    Color(0xFFFF0000), // 360° 回到紅
  ];

  @override
  void initState() {
    super.initState();
    _syncFromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant ColorWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部改變顏色時（例如點了常用色色塊），同步更新指示點位置
    if (oldWidget.color.value != widget.color.value) {
      _syncFromColor(widget.color);
    }
  }

  void _syncFromColor(Color c) {
    final hsv = HSVColor.fromColor(c);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
  }

  void _handleGesture(Offset localPosition) {
    final radius = widget.size / 2;
    final center = Offset(radius, radius);
    final vector = localPosition - center;
    final distance = vector.distance;

    // atan2(dy, dx) 的角度定義（順時針、0 度在 3 點鐘方向）
    // 跟 Flutter SweepGradient 的預設角度定義一致，兩者顏色才會對得上
    var hue = vector.direction * 180 / math.pi;
    if (hue < 0) hue += 360;

    setState(() {
      _hue = hue;
      _saturation = (distance / radius).clamp(0.0, 1.0);
    });

    widget.onColorChanged(
      HSVColor.fromAHSV(1, _hue, _saturation, 1.0).toColor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size / 2;
    final angleRad = _hue * math.pi / 180;
    final thumbCenter = Offset(
      radius + _saturation * radius * math.cos(angleRad),
      radius + _saturation * radius * math.sin(angleRad),
    );

    return GestureDetector(
      onPanStart: (d) => _handleGesture(d.localPosition),
      onPanUpdate: (d) => _handleGesture(d.localPosition),
      onTapDown: (d) => _handleGesture(d.localPosition),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: Stack(
                children: [
                  // 外圈彩虹色相（角度 = 色相）
                  Container(
                    decoration: const BoxDecoration(
                      gradient: SweepGradient(colors: _wheelColors),
                    ),
                  ),
                  // 中心白、往外淡出，疊在色相上做出「中心白 → 邊緣飽和彩色」的效果
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0)],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: thumbCenter.dx - 13,
              top: thumbCenter.dy - 13,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HSVColor.fromAHSV(1, _hue, _saturation, 1.0).toColor(),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
