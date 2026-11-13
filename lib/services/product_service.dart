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

  // Seeds Firestore from the bundled JSON when the collection is empty.
  Future<void> seedIfEmpty() async {
    final existing = await _collection.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final raw = await rootBundle.loadString('assets/data/product.json');
    final items = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    final batch = FirebaseFirestore.instance.batch();
    for (final item in items) {
      batch.set(_collection.doc(item['id'].toString()), item);
    }
    await batch.commit();
  }
}
