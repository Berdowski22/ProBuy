import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../widgets/product_card.dart';
import 'paymentScreen.dart';
import 'productDetailScreen.dart';

class CartScreen extends StatelessWidget {
  final VoidCallback? onGoToProfile;

  const CartScreen({super.key, this.onGoToProfile});

  Future<void> _change(BuildContext context, CartItem item, int delta) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CartService().changeQuantity(item.product, delta);
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
    final cartService = CartService();
    return Scaffold(
      appBar: AppBar(title: const Text('Sepetim')),
      body: StreamBuilder<List<CartItem>>(
        stream: cartService.watchCart(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Sepet yüklenemedi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 72),
                  SizedBox(height: 12),
                  Text('Sepetiniz boş.'),
                ],
              ),
            );
          }
          final total = items.fold<double>(0, (sum, i) => sum + i.lineTotal);

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _CartTile(
                        item: items[index],
                        onChange: (delta) => _change(context, items[index], delta),
                        onRemove: () => cartService
                            .removeFromCart(items[index].product.id),
                      ),
                ),
              ),
              _CheckoutBar(
                total: total,
                items: items,
                onGoToProfile: onGoToProfile,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onChange;
  final VoidCallback onRemove;

  const _CartTile({
    required this.item,
    required this.onChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final colorScheme = Theme.of(context).colorScheme;
    final atLimit = item.quantity >= product.stock;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProductDetailScreen(),
            settings: RouteSettings(arguments: product),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: ProductImage(path: product.image),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text('Satıcı: ${product.sellerName}',
                      style: Theme.of(context).textTheme.bodySmall),
                  Row(
                    children: [
                      Text('₺${product.price.toStringAsFixed(2)} / adet'),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₺${product.oldPrice!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '%${product.discountPercent} indirim',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () => onChange(-1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: atLimit ? null : () => onChange(1),
                      ),
                    ],
                  ),
                  if (atLimit)
                    Text(
                      'Stok sınırına ulaşıldı (${product.stock})',
                      style: TextStyle(fontSize: 12, color: colorScheme.error),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Sepetten çıkar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
                Text(
                  '₺${item.lineTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final double total;
  final List<CartItem> items;

  final VoidCallback? onGoToProfile;

  const _CheckoutBar({
    required this.total,
    required this.items,
    this.onGoToProfile,
  });

  Future<void> _checkout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String address;
    try {
      final profile = await AuthService().getProfile();
      address = (profile['address'] ?? '').toString().trim();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Profil okunamadı: $e')));
      return;
    }
    if (address.isNotEmpty) {
      navigator.push(MaterialPageRoute(
        builder: (_) => PaymentScreen(items: items, total: total),
      ));
      return;
    }
    if (!context.mounted) return;
    final goProfile = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined, size: 40),
        title: const Text('Adres gerekli'),
        content: const Text(
            'Ödemeye geçmek için profilinize teslimat adresi eklemelisiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Adres Ekle'),
          ),
        ],
      ),
    );
    if (goProfile == true) onGoToProfile?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Toplam'),
                    Text(
                      '₺${total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.payment),
                label: const Text('Ödemeye Geç'),
                onPressed: () => _checkout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
