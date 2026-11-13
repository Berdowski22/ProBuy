import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/product_card.dart';

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
  String? _newImage;

  bool get _isEdit => widget.product != null;

  String get _currentImage => _newImage ?? widget.product?.image ?? '';

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      // Downscaled so the encoded image stays well below Firestore's 1 MB limit.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(
          () => _newImage = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fotoğraf alınamadı: $e')));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _category, _description, _price, _stock, _features]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentImage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen ürün fotoğrafı ekleyin.')));
      return;
    }
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
          image: _newImage,
        );
      } else {
        await service.addProduct(
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: price,
          category: _category.text.trim(),
          stock: stock,
          features: features,
          image: _currentImage,
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
              InkWell(
                onTap: _saving ? null : _pickImage,
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _currentImage.isEmpty
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40),
                              SizedBox(height: 8),
                              Text('Ürün fotoğrafı ekle'),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ProductImage(path: _currentImage),
                              const Positioned(
                                right: 8,
                                bottom: 8,
                                child: CircleAvatar(
                                  child: Icon(Icons.edit),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
