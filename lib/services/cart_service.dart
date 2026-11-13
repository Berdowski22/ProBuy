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

  Stream<List<CartItem>> watchCart() {
    return _cart.snapshots().map((snapshot) {
      final items =
          snapshot.docs.map((d) => CartItem.fromJson(d.data())).toList();
      items.sort((a, b) => a.product.id.compareTo(b.product.id));
      return items;
    });
  }

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
