import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartException implements Exception {
  final String message;
  CartException(this.message);

  @override
  String toString() => message;
}

class CartService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw CartException('Oturum bulunamadı.');
    return _db.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> get _cart =>
      _userDoc.collection('cart');
  CollectionReference<Map<String, dynamic>> get _favorites =>
      _userDoc.collection('favorites');
  DocumentReference<Map<String, dynamic>> _productRef(int id) =>
      _db.collection('products').doc('$id');

  // Cart documents hold a snapshot of the product, so live product data
  // (stock, price, name) is merged in. Items exceeding the live stock are
  // reconciled automatically and reported through [notices].
  Stream<List<CartItem>> watchCart() {
    late final StreamController<List<CartItem>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? cartSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? productSub;
    List<Map<String, dynamic>>? cartData;
    Map<String, Map<String, dynamic>>? liveProducts;

    void emit() {
      final carts = cartData;
      final live = liveProducts;
      if (carts == null || live == null) return;
      final items = <CartItem>[];
      for (final entry in carts) {
        final id = entry['id'].toString();
        final merged = {...entry, ...?live[id]};
        final item = CartItem.fromJson(merged);
        items.add(item);
        if (live[id] == null || item.quantity > item.product.stock) {
          _reconcile(item.product.id);
        }
      }
      items.sort((a, b) => a.product.id.compareTo(b.product.id));
      controller.add(items);
    }

    controller = StreamController<List<CartItem>>(
      onListen: () {
        cartSub = _cart.snapshots().listen((s) {
          cartData = s.docs.map((d) => d.data()).toList();
          emit();
        }, onError: controller.addError);
        productSub = _db.collection('products').snapshots().listen((s) {
          liveProducts = {for (final d in s.docs) d.id: d.data()};
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await cartSub?.cancel();
        await productSub?.cancel();
      },
    );
    return controller.stream;
  }

  final Set<int> _reconciling = {};

  Future<void> _reconcile(int productId) async {
    if (!_reconciling.add(productId)) return;
    try {
      final cartRef = _cart.doc('$productId');
      final productRef = _productRef(productId);
      final notice = await _db.runTransaction<String?>((tx) async {
        final cartSnap = await tx.get(cartRef);
        final productSnap = await tx.get(productRef);
        final cartDoc = cartSnap.data();
        if (cartDoc == null) return null;
        final quantity = (cartDoc['quantity'] as int?) ?? 0;
        final stock = (productSnap.data()?['stock'] as int?) ?? 0;
        final name = cartDoc['name'];
        if (quantity <= stock) return null;
        if (stock <= 0) {
          tx.delete(cartRef);
          return '$name tükendiği için sepetinizden çıkarıldı.';
        }
        tx.update(cartRef, {'quantity': stock});
        return '$name stoğu azaldı, adet $stock olarak güncellendi.';
      });
      if (notice != null) _notices.add(notice);
    } catch (_) {
      // Retried on the next snapshot.
    } finally {
      _reconciling.remove(productId);
    }
  }

  static final StreamController<String> _notices =
      StreamController<String>.broadcast();
  static Stream<String> get notices => _notices.stream;

  Stream<Set<int>> watchFavoriteIds() {
    return _favorites
        .snapshots()
        .map((s) => s.docs.map((d) => int.parse(d.id)).toSet());
  }

  // Stock is read from the live product document so the limit cannot be bypassed with stale data.
  Future<void> changeQuantity(Product product, int delta) async {
    final cartRef = _cart.doc('${product.id}');
    final productRef = _productRef(product.id);
    await _db.runTransaction((tx) async {
      final productSnap = await tx.get(productRef);
      final cartSnap = await tx.get(cartRef);
      final data = productSnap.data();
      if (data == null) throw CartException('Ürün artık mevcut değil.');

      final stock = data['stock'] as int;
      final current = (cartSnap.data()?['quantity'] as int?) ?? 0;
      final next = current + delta;

      if (delta > 0 && next > stock) {
        throw CartException(stock == 0
            ? 'Bu ürün tükendi.'
            : 'Stok yetersiz. En fazla $stock adet eklenebilir.');
      }
      if (next <= 0) {
        tx.delete(cartRef);
      } else {
        tx.set(cartRef, {...data, 'quantity': next});
      }
    });
  }

  Future<void> removeFromCart(int productId) =>
      _cart.doc('$productId').delete();

  Future<void> setFavorite(int productId, bool favorite) {
    final ref = _favorites.doc('$productId');
    return favorite
        ? ref.set({'addedAt': FieldValue.serverTimestamp()})
        : ref.delete();
  }

  // Validates stock, decrements it, records the order and empties the cart atomically.
  Future<void> placeOrder(List<CartItem> items) async {
    if (items.isEmpty) throw CartException('Sepetiniz boş.');
    final orderRef = _userDoc.collection('orders').doc();
    await _db.runTransaction((tx) async {
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final item in items) {
        snaps.add(await tx.get(_productRef(item.product.id)));
      }

      var total = 0.0;
      final orderItems = <Map<String, dynamic>>[];
      for (var i = 0; i < items.length; i++) {
        final data = snaps[i].data();
        final item = items[i];
        if (data == null) {
          throw CartException('${item.product.name} artık mevcut değil.');
        }
        final stock = data['stock'] as int;
        if (item.quantity > stock) {
          throw CartException(
              '${item.product.name} için yeterli stok yok (kalan: $stock).');
        }
        final price = (data['price'] as num).toDouble();
        total += price * item.quantity;
        orderItems.add({
          'productId': item.product.id,
          'name': data['name'],
          'price': price,
          'quantity': item.quantity,
        });
        tx.update(_productRef(item.product.id),
            {'stock': stock - item.quantity});
        tx.delete(_cart.doc('${item.product.id}'));
      }

      tx.set(orderRef, {
        'items': orderItems,
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
