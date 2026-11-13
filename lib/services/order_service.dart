import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import 'cart_service.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw CartException('Oturum bulunamadı.');
    return _db.collection('users').doc(user.uid).collection('orders');
  }

  Stream<List<Order>> watchOrders() => _toOrders(_orders.snapshots());

  // Business view: every customer's orders (the buyer uid is the parent document id).
  Stream<List<Order>> watchAllOrders() =>
      _toOrders(_db.collectionGroup('orders').snapshots());

  Stream<List<Order>> _toOrders(
      Stream<QuerySnapshot<Map<String, dynamic>>> source) {
    return source.map((s) {
      final orders = s.docs.map(Order.fromDoc).toList();
      orders.sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));
      return orders;
    });
  }

  Future<void> cancelOrder(String orderId) =>
      _cancel(_orders.doc(orderId), byBusiness: false);

  Future<void> cancelOrderAsBusiness(Order order, String reason) {
    final ref = _db
        .collection('users')
        .doc(order.buyerUid)
        .collection('orders')
        .doc(order.id);
    return _cancel(ref, byBusiness: true, reason: reason.trim());
  }

  // Cancels the order and returns the ordered quantities to stock atomically.
  Future<void> _cancel(
    DocumentReference<Map<String, dynamic>> orderRef, {
    required bool byBusiness,
    String? reason,
  }) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw CartException('Sipariş bulunamadı.');
      final order = Order.fromDoc(snap);
      if (order.cancelled) throw CartException('Sipariş zaten iptal edilmiş.');
      if (!order.canCancel(DateTime.now())) {
        throw CartException('Kargoya verilen sipariş iptal edilemez.');
      }

      final productRefs = [
        for (final item in order.items)
          _db.collection('products').doc('${item.productId}'),
      ];
      final productSnaps = [for (final r in productRefs) await tx.get(r)];

      for (var i = 0; i < order.items.length; i++) {
        if (!productSnaps[i].exists) continue;
        tx.update(productRefs[i],
            {'stock': FieldValue.increment(order.items[i].quantity)});
      }
      tx.update(orderRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': byBusiness ? 'business' : 'customer',
        if (byBusiness) 'cancelReason': reason,
      });
    });
  }
}
