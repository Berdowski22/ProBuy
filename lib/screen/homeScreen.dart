import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_grid.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _productService = ProductService();
  final _cartService = CartService();
  late final Stream<List<Product>> _products;
  late final Stream<Set<int>> _favorites;

  @override
  void initState() {
    super.initState();
    _productService.seedIfEmpty().catchError((e) {
      debugPrint('Seed error: $e');
    });
    _products = _productService.watchProducts();
    _favorites = _cartService.watchFavoriteIds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandName(fontSize: 22, proColor: Colors.white)),
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
          final products = productSnap.data!;
          if (products.isEmpty) {
            return const Center(child: Text('Henüz ürün yok.'));
          }
          return StreamBuilder<Set<int>>(
            stream: _favorites,
            builder: (context, favSnap) => ProductGrid(
              products: products,
              favoriteIds: favSnap.data ?? const {},
            ),
          );
        },
      ),
    );
  }
}
