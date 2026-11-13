import 'package:cloud_firestore/cloud_firestore.dart';

enum ShippingStage { received, preparing, shipped, delivered }

class OrderItem {
  final int productId;
  final String name;
  final double price;
  final int quantity;
  final String? image;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.image,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] as int,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        quantity: map['quantity'] as int,
        image: map['image'] as String?,
      );

  double get lineTotal => price * quantity;
}

class Order {
  final String id;
  final List<OrderItem> items;
  final double total;
  final DateTime? createdAt;
  final bool cancelled;
  final String name;
  final String phone;
  final String address;
  final String carrier;
  final String trackingNo;

  const Order({
    required this.id,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.cancelled,
    required this.name,
    required this.phone,
    required this.address,
    required this.carrier,
    required this.trackingNo,
  });

  factory Order.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Order(
      id: doc.id,
      items: (data['items'] as List<dynamic>)
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      total: (data['total'] as num).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      cancelled: data['status'] == 'cancelled',
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      carrier: (data['carrier'] ?? 'HızlıKargo').toString(),
      trackingNo: (data['trackingNo'] ?? '-').toString(),
    );
  }

  // Simulated carrier: the stage is derived from the order age.
  static const preparingAfter = Duration(minutes: 1);
  static const shippedAfter = Duration(minutes: 3);
  static const deliveredAfter = Duration(minutes: 10);

  ShippingStage stageAt(DateTime now) {
    final created = createdAt;
    if (created == null) return ShippingStage.received;
    final age = now.difference(created);
    if (age >= deliveredAfter) return ShippingStage.delivered;
    if (age >= shippedAfter) return ShippingStage.shipped;
    if (age >= preparingAfter) return ShippingStage.preparing;
    return ShippingStage.received;
  }

  bool canCancel(DateTime now) {
    if (cancelled) return false;
    final stage = stageAt(now);
    return stage == ShippingStage.received || stage == ShippingStage.preparing;
  }

  bool isActive(DateTime now) =>
      !cancelled && stageAt(now) != ShippingStage.delivered;
}
