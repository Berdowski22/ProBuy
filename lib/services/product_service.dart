import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/product.dart';

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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

  Future<int> _nextId() async {
    final last = await _collection.orderBy('id', descending: true).limit(1).get();
    if (last.docs.isEmpty) return 1;
    return (last.docs.first.data()['id'] as int) + 1;
  }

  Future<void> addProduct({
    required String name,
    required String description,
    required double price,
    required String category,
    required int stock,
    required List<String> features,
  }) async {
    final id = await _nextId();
    final user = FirebaseAuth.instance.currentUser;
    var sellerName = Product.defaultSeller;
    if (user != null) {
      final profile = await _db.collection('users').doc(user.uid).get();
      final name = (profile.data()?['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) sellerName = name;
    }
    await _collection.doc('$id').set({
      'sellerName': sellerName,
      'sellerId': user?.uid,
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'image': '',
      'rating': 0.0,
      'stock': stock,
      'features': features,
      'specs': <String, String>{},
    });
  }

  Future<void> updateProduct(
    int id, {
    required String name,
    required String description,
    required double price,
    required String category,
    required int stock,
    required List<String> features,
  }) async {
    final ref = _collection.doc('$id');
    final current = (await ref.get()).data();
    final currentPrice = (current?['price'] as num?)?.toDouble() ?? price;
    final currentOld = (current?['oldPrice'] as num?)?.toDouble();

    // Price drop -> show discount against the original price.
    // Price rise -> discount is cleared, nothing else happens.
    Object? oldPrice;
    if (price < currentPrice) {
      oldPrice = (currentOld != null && currentOld > currentPrice)
          ? currentOld
          : currentPrice;
    } else if (price > currentPrice) {
      oldPrice = FieldValue.delete();
    }

    await ref.update({
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'stock': stock,
      'features': features,
      if (oldPrice != null) 'oldPrice': oldPrice,
    });
  }

  Future<void> deleteProduct(int id) => _collection.doc('$id').delete();

  // Seeds the bundled JSON once. A marker document prevents products deleted
  // by a business from being re-created on the next app start.
  Future<void> seedIfEmpty() async {
    final marker = _db.collection('meta').doc('seed');
    if ((await marker.get()).exists) return;

    final existing = await _collection.get();
    final raw = await rootBundle.loadString('assets/data/product.json');
    final items = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    final byId = {for (final d in existing.docs) d.id: d.data()};

    final batch = _db.batch();
    for (final item in items) {
      final key = item['id'].toString();
      final current = byId[key];
      if (current == null) {
        if (existing.docs.isEmpty) batch.set(_collection.doc(key), item);
      } else if (!current.containsKey('specs')) {
        batch.update(_collection.doc(key), {
          'features': item['features'],
          'specs': item['specs'],
        });
      }
    }
    batch.set(marker, {'seededAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }
}
