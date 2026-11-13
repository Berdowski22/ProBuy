import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/product_card.dart';
import 'productDetailScreen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _service = OrderService();
  late final Stream<List<Order>> _orders = _service.watchOrders();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Shipping stages depend on elapsed time, so refresh periodically.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Siparişlerim'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.buy,
            tabs: [Tab(text: 'Aktif'), Tab(text: 'Geçmiş')],
          ),
        ),
        body: StreamBuilder<List<Order>>(
          stream: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text('Siparişler yüklenemedi: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final now = DateTime.now();
            final all = snapshot.data!;
            final active = all.where((o) => o.isActive(now)).toList();
            final past = all.where((o) => !o.isActive(now)).toList();
            return TabBarView(
              children: [
                _OrderList(
                    orders: active, emptyText: 'Aktif siparişiniz yok.'),
                _OrderList(
                    orders: past, emptyText: 'Geçmiş siparişiniz yok.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  final String emptyText;

  const _OrderList({required this.orders, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64),
            const SizedBox(height: 12),
            Text(emptyText),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _OrderCard(order: orders[i]),
    );
  }
}

String _formatDate(DateTime? d) {
  if (d == null) return '-';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

const _stageLabels = {
  ShippingStage.received: 'Sipariş Alındı',
  ShippingStage.preparing: 'Hazırlanıyor',
  ShippingStage.shipped: 'Kargoya Verildi',
  ShippingStage.delivered: 'Teslim Edildi',
};

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  Future<void> _openProduct(BuildContext context, OrderItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final product = await ProductService().watchProduct(item.productId).first;
      if (product == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Bu ürün artık mevcut değil.')));
        return;
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => const ProductDetailScreen(),
        settings: RouteSettings(arguments: product),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ürün açılamadı: $e')));
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Siparişi iptal et',
      message:
          'Siparişi iptal etmek istediğinizden emin misiniz? Ürünler stoğa geri eklenecek.',
      confirmText: 'İptal Et',
      icon: Icons.cancel_outlined,
    );
    if (!ok) return;
    try {
      await OrderService().cancelOrder(order.id);
      messenger.showSnackBar(
          const SnackBar(content: Text('Siparişiniz iptal edildi.')));
    } on CartException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('İptal başarısız: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stage = order.stageAt(now);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sipariş #${order.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(_formatDate(order.createdAt),
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _StatusChip(order: order, stage: stage),
              ],
            ),
            const Divider(height: 24),
            for (final item in order.items)
              InkWell(
                onTap: () => _openProduct(context, item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: ProductImage(path: item.image ?? ''),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(
                              '${item.quantity} x ₺${item.price.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text('₺${item.lineTotal.toStringAsFixed(2)}'),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            const Divider(height: 24),
            if (order.cancelled)
              Row(
                children: [
                  Icon(Icons.cancel, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Sipariş iptal edildi, ürünler stoğa döndü.')),
                ],
              )
            else
              _TrackingBar(order: order, stage: stage),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ödeme Tutarı'),
                Text(
                  '₺${order.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [order.name, order.phone, order.address]
                        .where((s) => s.isNotEmpty)
                        .join('\n'),
                  ),
                ),
              ],
            ),
            if (order.canCancel(now)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Siparişi İptal Et'),
                  onPressed: () => _cancel(context),
                ),
              ),
            ] else if (!order.cancelled &&
                stage == ShippingStage.shipped) ...[
              const SizedBox(height: 8),
              Text('Kargoya verilen sipariş iptal edilemez.',
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Order order;
  final ShippingStage stage;

  const _StatusChip({required this.order, required this.stage});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (order.cancelled) {
      label = 'İptal Edildi';
      color = Theme.of(context).colorScheme.error;
    } else {
      label = _stageLabels[stage]!;
      color = stage == ShippingStage.delivered
          ? Colors.green.shade700
          : AppColors.buy;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

// Mock third-party carrier tracking widget.
class _TrackingBar extends StatelessWidget {
  final Order order;
  final ShippingStage stage;

  const _TrackingBar({required this.order, required this.stage});

  @override
  Widget build(BuildContext context) {
    final steps = ShippingStage.values;
    final shipped = stage.index >= ShippingStage.shipped.index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_shipping, color: AppColors.buy),
            const SizedBox(width: 8),
            Text(
              shipped
                  ? '${order.carrier} • Takip No: ${order.trackingNo}'
                  : 'Kargo henüz yola çıkmadı',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (stage.index + 1) / steps.length,
            minHeight: 8,
            color: AppColors.buy,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final s in steps)
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      s.index <= stage.index
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: s.index <= stage.index
                          ? AppColors.pro
                          : Colors.grey,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _stageLabels[s]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            s == stage ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
