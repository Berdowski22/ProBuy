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

enum _Sort { none, priceAsc, priceDesc, rating }

class _HomeState extends State<Home> {
  final _productService = ProductService();
  final _cartService = CartService();
  late final Stream<List<Product>> _products;
  late final Stream<Set<int>> _favorites;

  String _query = '';
  String? _category;
  _Sort _sort = _Sort.none;
  bool _onlyDiscounted = false;
  bool _onlyInStock = false;

  bool get _filtersActive =>
      _category != null ||
      _sort != _Sort.none ||
      _onlyDiscounted ||
      _onlyInStock;

  @override
  void initState() {
    super.initState();
    _productService.seedIfEmpty().catchError((e) {
      debugPrint('Seed error: $e');
    });
    _products = _productService.watchProducts();
    _favorites = _cartService.watchFavoriteIds();
  }

  List<Product> _apply(List<Product> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((p) {
      if (q.isNotEmpty &&
          !('${p.name} ${p.category} ${p.sellerName}'
              .toLowerCase()
              .contains(q))) {
        return false;
      }
      if (_category != null && p.category != _category) return false;
      if (_onlyDiscounted && !p.hasDiscount) return false;
      if (_onlyInStock && p.stock <= 0) return false;
      return true;
    }).toList();
    switch (_sort) {
      case _Sort.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
      case _Sort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case _Sort.none:
        break;
    }
    return list;
  }

  void _clearFilters() => setState(() {
        _category = null;
        _sort = _Sort.none;
        _onlyDiscounted = false;
        _onlyInStock = false;
      });

  Future<void> _openFilters(List<String> categories) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Filtrele ve sırala',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () => update(_clearFilters),
                        child: const Text('Temizle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Kategori',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tümü'),
                        selected: _category == null,
                        onSelected: (_) => update(() => _category = null),
                      ),
                      for (final c in categories)
                        ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => update(() => _category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Sıralama',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (s, label) in const [
                        (_Sort.none, 'Varsayılan'),
                        (_Sort.priceAsc, 'Fiyat: Artan'),
                        (_Sort.priceDesc, 'Fiyat: Azalan'),
                        (_Sort.rating, 'En yüksek puan'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _sort == s,
                          onSelected: (_) => update(() => _sort = s),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sadece indirimli ürünler'),
                    value: _onlyDiscounted,
                    onChanged: (v) => update(() => _onlyDiscounted = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sadece stokta olanlar'),
                    value: _onlyInStock,
                    onChanged: (v) => update(() => _onlyInStock = v),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Uygula'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
          final categories = ({for (final p in products) p.category}).toList()
            ..sort();
          final filtered = _apply(products);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Ürün, kategori veya satıcı ara',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _filtersActive,
                      smallSize: 10,
                      child: IconButton.filledTonal(
                        tooltip: 'Filtrele',
                        icon: const Icon(Icons.tune),
                        onPressed: () => _openFilters(categories),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 64),
                            const SizedBox(height: 8),
                            const Text('Aramanızla eşleşen ürün yok.'),
                            if (_filtersActive)
                              TextButton(
                                onPressed: _clearFilters,
                                child: const Text('Filtreleri temizle'),
                              ),
                          ],
                        ),
                      )
                    : StreamBuilder<Set<int>>(
                        stream: _favorites,
                        builder: (context, favSnap) => ProductGrid(
                          products: filtered,
                          favoriteIds: favSnap.data ?? const {},
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
