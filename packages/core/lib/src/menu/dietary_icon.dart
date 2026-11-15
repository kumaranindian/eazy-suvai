import 'package:flutter/material.dart';

import 'menu_models.dart';

/// Symbol for a dietary label or tag, drawn from its `icon` key.
///
/// The India veg / non-veg marks are a square outline with a dot or a
/// triangle (FR-023). Every symbol sits on a white tile so its colour keeps
/// enough contrast in light and dark themes (WCAG 1.4.11). The symbol is
/// decorative: always show the label's name next to it ([MenuLabelBadge]).
class MenuLabelIcon extends StatelessWidget {
  const MenuLabelIcon({super.key, required this.label, this.size = 18});

  final MenuLabel label;
  final double size;

  static const _fallback = {
    'veg': Color(0xFF2E7D32),
    'nonVeg': Color(0xFF8B4513),
    'vegan': Color(0xFF3B7A20),
    'egg': Color(0xFFB26A00),
  };

  static IconData? iconFor(String key) => switch (key) {
    'vegan' => Icons.eco,
    'egg' => Icons.egg,
    'spicy' => Icons.local_fire_department,
    'bestseller' => Icons.star,
    'chefsSpecial' => Icons.restaurant,
    'new' => Icons.fiber_new,
    'veg' || 'nonVeg' => null,
    _ => Icons.sell_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = label.color != null
        ? Color(label.color!)
        : (_fallback[label.icon] ?? const Color(0xFF2B2B2B));
    final Widget symbol = switch (label.icon) {
      'veg' || 'nonVeg' => CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(color: color, triangle: label.icon == 'nonVeg'),
      ),
      _ => Icon(iconFor(label.icon), size: size * 0.8, color: color),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.15),
        ),
        child: symbol,
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.color, required this.triangle});

  final Color color;
  final bool triangle;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.1;
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawRect(
      Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke),
      border,
    );
    final fill = Paint()..color = color;
    final c = Offset(s / 2, s / 2);
    if (triangle) {
      final r = s * 0.28;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy + r * 0.8)
          ..lineTo(c.dx - r, c.dy + r * 0.8)
          ..close(),
        fill,
      );
    } else {
      canvas.drawCircle(c, s * 0.24, fill);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.triangle != triangle;
}

/// Icon plus name of a dietary label or tag: the meaning never depends on
/// colour or symbol alone (FR-023, AC-006).
class MenuLabelBadge extends StatelessWidget {
  const MenuLabelBadge({
    super.key,
    required this.label,
    this.iconSize = 16,
    this.style,
  });

  final MenuLabel label;
  final double iconSize;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A Wrap, not a Row: in a very narrow space (200 % text) the name moves
    // under the icon instead of overflowing (M13).
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        MenuLabelIcon(label: label, size: iconSize),
        Text(
          label.name,
          overflow: TextOverflow.ellipsis,
          style:
              style ??
              theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
