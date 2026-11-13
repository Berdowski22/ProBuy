import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> items;
  final double total;

  const PaymentScreen({super.key, required this.items, required this.total});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;
  String? _address;

  @override
  void initState() {
    super.initState();
    AuthService().getProfile().then((profile) {
      if (mounted) setState(() => _address = (profile['address'] ?? '').toString());
    }).catchError((_) {});
  }

  Future<void> _pay() async {
    setState(() => _processing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await CartService().placeOrder(widget.items);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Siparişiniz alındı'),
          content: const Text('Bu bir simülasyondur, gerçek ödeme alınmadı.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      navigator.pop();
    } on CartException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ödeme başarısız: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ödeme')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Sipariş Özeti', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final item in widget.items)
                  ListTile(
                    title: Text(item.product.name),
                    subtitle: Text(
                        '${item.quantity} x ₺${item.product.price.toStringAsFixed(2)}'),
                    trailing: Text('₺${item.lineTotal.toStringAsFixed(2)}'),
                  ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Toplam',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    '₺${widget.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Teslimat Adresi', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(
                (_address == null || _address!.isEmpty)
                    ? 'Adres eklenmemiş. Profil sekmesinden ekleyebilirsiniz.'
                    : _address!,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bu uygulama eğitim amaçlıdır; gerçek ödeme alınmaz.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _processing ? null : _pay,
            child: _processing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Ödemeyi Tamamla  ₺${widget.total.toStringAsFixed(2)}'),
          ),
        ),
      ),
    );
  }
}
