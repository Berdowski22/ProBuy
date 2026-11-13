import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../widgets/rating_badge.dart';

// Images uploaded by businesses are stored as "data:" URIs in Firestore.
final Map<String, Uint8List> _decoded = {};

class ProductImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const ProductImage({super.key, required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext c, Object _, StackTrace? _) => Container(
          color: Theme.of(c).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.image_not_supported, size: 32)),
        );
    if (path.startsWith('data:')) {
      final bytes = _decoded.putIfAbsent(
          path, () => base64Decode(path.substring(path.indexOf(',') + 1)));
      return Image.memory(bytes,
          fit: fit, gaplessPlayback: true, errorBuilder: error);
    }
    return Image.asset(path, fit: fit, errorBuilder: error);
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCart;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToCart,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outOfStock = product.stock <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(path: product.image),
                  if (outOfStock)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const Text(
                        'Tükendi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (product.hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '%${product.discountPercent} İNDİRİM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: isFavorite
                          ? 'Favorilerden çıkar'
                          : 'Favorilere ekle',
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                      ),
                      onPressed: onToggleFavorite,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      RatingBadge(rating: product.rating),
                      const SizedBox(width: 6),
                    ],
                  ),
                  Text(
                    'Satıcı: ${product.sellerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Text(
                                '₺${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: product.hasDiscount
                                      ? Colors.red.shade700
                                      : colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (product.hasDiscount) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₺${product.oldPrice!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Sepete ekle',
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                        onPressed: outOfStock ? null : onAddToCart,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
