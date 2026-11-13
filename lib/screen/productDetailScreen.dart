import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../services/review_service.dart';
import '../widgets/product_card.dart';
import '../widgets/rating_badge.dart';

// Receives the Product through RouteSettings.arguments.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _cartService = CartService();
  Stream<Product?>? _product;
  Stream<Set<int>>? _favorites;
  Product? _initial;
  int _quantity = 1;
  bool _adding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initial != null) return;
    _initial = ModalRoute.of(context)!.settings.arguments as Product;
    _product = ProductService().watchProduct(_initial!.id);
    _favorites = _cartService.watchFavoriteIds();
  }

  Future<void> _addToCart(Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      await _cartService.changeQuantity(product, _quantity);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('$_quantity adet ${product.name} sepete eklendi'),
        ));
    } on CartException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleFavorite(Product product, bool isFavorite) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _cartService.setFavorite(product.id, !isFavorite);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Product?>(
      stream: _product,
      initialData: _initial,
      builder: (context, snapshot) {
        final product = snapshot.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Bu ürün artık mevcut değil.')),
          );
        }
        final maxQty = product.stock < 10 ? product.stock : 10;
        if (_quantity > maxQty && maxQty > 0) _quantity = maxQty;

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              StreamBuilder<Set<int>>(
                stream: _favorites,
                builder: (context, favSnap) {
                  final isFavorite = (favSnap.data ?? const {}).contains(product.id);
                  return IconButton(
                    tooltip:
                        isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: () => _toggleFavorite(product, isFavorite),
                  );
                },
              ),
            ],
          ),
          body: _Body(product: product),
          bottomNavigationBar: _BottomBar(
            product: product,
            quantity: _quantity,
            maxQuantity: maxQty,
            adding: _adding,
            onQuantityChanged: (q) => setState(() => _quantity = q),
            onAdd: () => _addToCart(product),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  final Product product;

  const _Body({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      children: [
        AspectRatio(
          aspectRatio: 1.3,
          child: ProductImage(path: product.image),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip(
                label: Text(product.category),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _RatingRow(rating: product.rating, count: product.ratingCount),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₺${product.price.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: product.hasDiscount
                          ? Colors.red.shade700
                          : colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (product.hasDiscount) ...[
                    const SizedBox(width: 10),
                    Text(
                      '₺${product.oldPrice!.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('%${product.discountPercent} İNDİRİM'),
                      backgroundColor: Colors.red.shade700,
                      labelStyle: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text('Satıcı: ${product.sellerName}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              _StockInfo(stock: product.stock),
              const SizedBox(height: 20),
              Text('Ürün Açıklaması', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(product.description),
              if (product.features.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Öne Çıkan Özellikler',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                for (final feature in product.features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(feature)),
                      ],
                    ),
                  ),
              ],
              if (product.specs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Teknik Özellikler', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final entry in product.specs.entries.indexed)
                        Container(
                          color: entry.$1.isEven
                              ? colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5)
                              : null,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry.$2.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(flex: 3, child: Text(entry.$2.value)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(
                      child: _InfoTile(
                          icon: Icons.local_shipping_outlined,
                          text: 'Ücretsiz kargo')),
                  Expanded(
                      child: _InfoTile(
                          icon: Icons.assignment_return_outlined,
                          text: '14 gün iade')),
                  Expanded(
                      child: _InfoTile(
                          icon: Icons.verified_user_outlined,
                          text: 'Resmi garanti')),
                ],
              ),
              const SizedBox(height: 20),
              _ReviewsSection(productId: product.id),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double rating;
  final int count;

  const _RatingRow({required this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = ratingColor(rating);
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star
                : (rating >= i - 0.5 ? Icons.star_half : Icons.star_border),
            color: color,
            size: 22,
          ),
        const SizedBox(width: 8),
        RatingBadge(rating: rating),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Text('$count değerlendirme'),
        ],
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final int productId;

  const _ReviewsSection({required this.productId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Review>>(
      stream: ReviewService().watchReviews(productId),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <Review>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yorumlar (${reviews.length})',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            if (reviews.isEmpty)
              const Text('Henüz yorum yapılmamış.')
            else
              for (final r in reviews)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(r.userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                            RatingBadge(rating: r.rating.toDouble()),
                          ],
                        ),
                        if (r.comment.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(r.comment),
                        ],
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _StockInfo extends StatelessWidget {
  final int stock;

  const _StockInfo({required this.stock});

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (stock <= 0) {
      text = 'Tükendi';
      color = Theme.of(context).colorScheme.error;
    } else if (stock <= 5) {
      text = 'Son $stock ürün kaldı!';
      color = Colors.orange.shade800;
    } else {
      text = 'Stokta var ($stock adet)';
      color = Colors.green.shade700;
    }
    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, size: 18, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Product product;
  final int quantity;
  final int maxQuantity;
  final bool adding;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAdd;

  const _BottomBar({
    required this.product,
    required this.quantity,
    required this.maxQuantity,
    required this.adding,
    required this.onQuantityChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stock <= 0;
    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (!outOfStock) ...[
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  onPressed:
                      quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  onPressed: quantity < maxQuantity
                      ? () => onQuantityChanged(quantity + 1)
                      : null,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(outOfStock
                      ? 'Tükendi'
                      : 'Sepete Ekle  ₺${(product.price * quantity).toStringAsFixed(2)}'),
                  onPressed: outOfStock || adding ? null : onAdd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
