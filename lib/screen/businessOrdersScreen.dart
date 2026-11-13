import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/privacy.dart';

class BusinessOrdersScreen extends StatefulWidget {
  const BusinessOrdersScreen({super.key});

  @override
  State<BusinessOrdersScreen> createState() => _BusinessOrdersScreenState();
}

class _BusinessOrdersScreenState extends State<BusinessOrdersScreen> {
  late final Stream<List<Order>> _orders = OrderService().watchAllOrders();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Siparişler')),
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
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('Henüz sipariş yok.'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ProductSummary(orders: orders),
              const SizedBox(height: 12),
              for (final order in orders) ...[
                _BusinessOrderCard(order: order),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

// Total ordered quantity per product (cancelled orders excluded).
class _ProductSummary extends StatelessWidget {
  final List<Order> orders;

  const _ProductSummary({required this.orders});

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final order in orders.where((o) => !o.cancelled)) {
      for (final item in order.items) {
        totals[item.name] = (totals[item.name] ?? 0) + item.quantity;
      }
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.bar_chart, color: AppColors.pro),
        title: const Text('Ürün bazında sipariş adetleri',
            style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aktif sipariş yok.'),
            ),
          for (final e in entries)
            ListTile(
              dense: true,
              title: Text(e.key),
              trailing: Text('${e.value} adet',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _BusinessOrderCard extends StatelessWidget {
  final Order order;

  const _BusinessOrderCard({required this.order});

  Future<void> _cancel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelReasonDialog(),
    );
    if (reason == null) return;
    try {
      await OrderService().cancelOrderAsBusiness(order, reason);
      messenger.showSnackBar(const SnackBar(
          content: Text('Sipariş iptal edildi, ürünler stoğa döndü.')));
    } on CartException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('İptal başarısız: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final stage = order.stageAt(now);
    final statusLabel = order.cancelled ? 'İptal Edildi' : stageLabels[stage]!;
    final statusColor = order.cancelled
        ? theme.colorScheme.error
        : (stage == ShippingStage.delivered
            ? Colors.green.shade700
            : AppColors.buy);

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
                      Text(formatOrderDate(order.createdAt),
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 20),
                const SizedBox(width: 8),
                Text(maskName(order.name)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(maskAddress(order.address))),
              ],
            ),
            const Divider(height: 24),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name)),
                    Text('${item.quantity} adet',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tutar'),
                Text('₺${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary)),
              ],
            ),
            if (order.cancelled && (order.cancelReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('İptal nedeni: ${order.cancelReason}',
                  style: theme.textTheme.bodySmall),
            ] else if (order.cancelled) ...[
              const SizedBox(height: 8),
              Text('Müşteri tarafından iptal edildi.',
                  style: theme.textTheme.bodySmall),
            ],
            if (order.canCancel(now)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Siparişi İptal Et'),
                  onPressed: () => _cancel(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.cancel_outlined, size: 40),
      title: const Text('Siparişi iptal et'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'İptal nedeni müşteriye gösterilecek. Ürünler stoğa geri eklenir.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'İptal nedeni',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'En az 5 karakterlik bir neden yazın'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('İptal Et'),
        ),
      ],
    );
  }
}
