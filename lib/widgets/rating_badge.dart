import 'package:flutter/material.dart';

// 4.5-5 dark green, fading through light green / amber / orange to red.
Color ratingColor(double rating) {
  const stops = <(double, Color)>[
    (1.0, Color(0xFFC62828)),
    (2.0, Color(0xFFE65100)),
    (3.0, Color(0xFFF9A825)),
    (4.0, Color(0xFF7CB342)),
    (4.5, Color(0xFF1B5E20)),
  ];
  if (rating <= stops.first.$1) return stops.first.$2;
  if (rating >= stops.last.$1) return stops.last.$2;
  for (var i = 1; i < stops.length; i++) {
    if (rating <= stops[i].$1) {
      final (a, ca) = stops[i - 1];
      final (b, cb) = stops[i];
      return Color.lerp(ca, cb, (rating - a) / (b - a))!;
    }
  }
  return stops.last.$2;
}

class RatingBadge extends StatelessWidget {
  final double rating;
  final int count;
  final bool showCount;

  const RatingBadge({
    super.key,
    required this.rating,
    this.count = 0,
    this.showCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = ratingColor(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1) + (showCount ? ' ($count)' : ''),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
