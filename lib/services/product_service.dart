import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/product.dart';

class ProductService {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('products');

  Stream<List<Product>> watchProducts() {
    return _collection.orderBy('id').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((d) => Product.fromJson(d.data())).toList(),
        );
  }

  Stream<Product?> watchProduct(int id) {
    return _collection
        .doc(id.toString())
        .snapshots()
        .map((d) => d.exists ? Product.fromJson(d.data()!) : null);
  }

  // Seeds missing products from the bundled JSON and adds features/specs to
  // existing products that lack them, without touching stock or price.
  Future<void> seedIfEmpty() async {
    final raw = await rootBundle.loadString('assets/data/product.json');
    final items = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    final existing = await _collection.get();
    final byId = {for (final d in existing.docs) d.id: d.data()};

    final batch = FirebaseFirestore.instance.batch();
    var writes = 0;
    for (final item in items) {
      final key = item['id'].toString();
      final current = byId[key];
      if (current == null) {
        batch.set(_collection.doc(key), item);
        writes++;
      } else if (!current.containsKey('specs')) {
        batch.update(_collection.doc(key), {
          'features': item['features'],
          'specs': item['specs'],
        });
        writes++;
      }
    }
    if (writes > 0) await batch.commit();
  }
}
