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

  Stream<List<Order>> watchOrders() {
    return _orders.snapshots().map((s) {
      final orders = s.docs.map(Order.fromDoc).toList();
      orders.sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));
      return orders;
    });
  }

  // Cancels the order and returns the ordered quantities to stock atomically.
  Future<void> cancelOrder(String orderId) async {
    final orderRef = _orders.doc(orderId);
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
      });
    });
  }
}
