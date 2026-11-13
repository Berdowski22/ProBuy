import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../widgets/product_grid.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final Stream<List<Product>> _products =
      ProductService().watchProducts();
  late final Stream<Set<int>> _favorites =
      CartService().watchFavoriteIds();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoriler')),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, productSnap) {
          if (productSnap.hasError) {
            return Center(
                child: Text('Ürünler yüklenemedi: ${productSnap.error}'));
          }
          if (!productSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<Set<int>>(
            stream: _favorites,
            builder: (context, favSnap) {
              if (!favSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final ids = favSnap.data!;
              final favorites =
                  productSnap.data!.where((p) => ids.contains(p.id)).toList();
              if (favorites.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border, size: 64),
                      SizedBox(height: 12),
                      Text('Henüz favori ürününüz yok.'),
                    ],
                  ),
                );
              }
              return ProductGrid(products: favorites, favoriteIds: ids);
            },
          );
        },
      ),
    );
  }
}
