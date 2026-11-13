import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/product_card.dart';
import '../widgets/rating_badge.dart';
import 'productFormScreen.dart';

class BusinessProductsScreen extends StatefulWidget {
  const BusinessProductsScreen({super.key});

  @override
  State<BusinessProductsScreen> createState() => _BusinessProductsScreenState();
}

class _BusinessProductsScreenState extends State<BusinessProductsScreen> {
  final _service = ProductService();
  late final Stream<List<Product>> _products = _service.watchProducts();

  Future<void> _delete(Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Ürünü kaldır',
      message:
          '"${product.name}" ürününü kaldırmak istediğinizden emin misiniz? Müşterilerin sepetlerinden de çıkarılır.',
      confirmText: 'Kaldır',
      icon: Icons.delete_outline,
    );
    if (!ok) return;
    try {
      await _service.deleteProduct(product.id);
      messenger.showSnackBar(const SnackBar(content: Text('Ürün kaldırıldı.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kaldırılamadı: $e')));
    }
  }

  void _openForm([Product? product]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ürün Yönetimi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Ürün Ekle'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ürünler yüklenemedi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Center(child: Text('Henüz ürün yok.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = products[i];
              final outOfStock = p.stock <= 0;
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => _openForm(p),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: ProductImage(path: p.image),
                    ),
                  ),
                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₺${p.price.toStringAsFixed(2)}  •  ${outOfStock ? 'Tükendi' : 'Stok: ${p.stock}'}',
                        style: TextStyle(
                          color: outOfStock ? Theme.of(context).colorScheme.error : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RatingBadge(rating: p.rating),
                          const SizedBox(width: 6),
                          Text(p.ratingCount > 0
                              ? '${p.ratingCount} değerlendirme'
                              : 'Henüz değerlendirme yok'),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Düzenle',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openForm(p),
                      ),
                      IconButton(
                        tooltip: 'Kaldır',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(p),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
