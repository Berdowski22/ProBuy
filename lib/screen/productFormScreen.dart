import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/confirm_dialog.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _category = TextEditingController(text: widget.product?.category);
  late final _description =
      TextEditingController(text: widget.product?.description);
  late final _price = TextEditingController(
      text: widget.product == null ? '' : widget.product!.price.toString());
  late final _stock = TextEditingController(
      text: widget.product == null ? '' : widget.product!.stock.toString());
  late final _features = TextEditingController(
      text: widget.product?.features.join('\n') ?? '');
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    for (final c in [_name, _category, _description, _price, _stock, _features]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await confirmAction(
      context,
      title: _isEdit ? 'Ürünü güncelle' : 'Ürünü ekle',
      message: _isEdit
          ? 'Değişiklikleri kaydetmek istediğinizden emin misiniz?'
          : 'Yeni ürünü eklemek istediğinizden emin misiniz?',
      confirmText: 'Kaydet',
      icon: Icons.save_outlined,
    );
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final price = double.parse(_price.text.trim().replaceAll(',', '.'));
    final stock = int.parse(_stock.text.trim());
    final features = _features.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    try {
      final service = ProductService();
      if (_isEdit) {
        await service.updateProduct(
          widget.product!.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: price,
          category: _category.text.trim(),
          stock: stock,
          features: features,
        );
      } else {
        await service.addProduct(
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: price,
          category: _category.text.trim(),
          stock: stock,
          features: features,
        );
      }
      messenger.showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Ürün güncellendi.' : 'Ürün eklendi.')));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label gerekli' : null;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder();
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ürünü Düzenle' : 'Yeni Ürün')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'Ürün adı', border: border),
                validator: (v) => _required(v, 'Ürün adı'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _category,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'Kategori', border: border),
                validator: (v) => _required(v, 'Kategori'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Fiyat (₺)', border: border),
                      validator: (v) {
                        final value =
                            double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                        if (value == null || value <= 0) {
                          return 'Geçerli fiyat girin';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Stok', border: border),
                      validator: (v) {
                        final value = int.tryParse((v ?? '').trim());
                        if (value == null || value < 0) {
                          return 'Geçerli stok girin';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration:
                    const InputDecoration(labelText: 'Açıklama', border: border),
                validator: (v) => _required(v, 'Açıklama'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _features,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Öne çıkan özellikler (her satıra bir tane)',
                  alignLabelWithHint: true,
                  border: border,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Kaydet'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
