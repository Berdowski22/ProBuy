import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../screen/productDetailScreen.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Set<int> favoriteIds;

  const ProductGrid({
    super.key,
    required this.products,
    required this.favoriteIds,
  });

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String successMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 1),
        ));
    } on CartException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isFavorite = favoriteIds.contains(product.id);
        return ProductCard(
          product: product,
          isFavorite: isFavorite,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProductDetailScreen(),
              settings: RouteSettings(arguments: product),
            ),
          ),
          onToggleFavorite: () => _run(
            context,
            () => cart.setFavorite(product.id, !isFavorite),
            isFavorite ? 'Favorilerden çıkarıldı' : 'Favorilere eklendi',
          ),
          onAddToCart: () => _run(
            context,
            () => cart.changeQuantity(product, 1),
            '${product.name} sepete eklendi',
          ),
        );
      },
    );
  }
}
