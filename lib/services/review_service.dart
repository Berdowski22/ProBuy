import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/privacy.dart';
import 'cart_service.dart';

class Review {
  final String userName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const Review({
    required this.userName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> m) => Review(
        userName: (m['userName'] ?? '').toString(),
        rating: (m['rating'] as num).toInt(),
        comment: (m['comment'] ?? '').toString(),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}

class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Review>> watchReviews(int productId) {
    return _db
        .collection('products')
        .doc('$productId')
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Review.fromMap(d.data())).toList());
  }

  // One review per buyer and product. The order is flagged as reviewed and the
  // product's average is recalculated in the same transaction.
  Future<void> submitReview({
    required String orderId,
    required int productId,
    required int rating,
    required String comment,
    required String buyerName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw CartException('Oturum bulunamadı.');
    final productRef = _db.collection('products').doc('$productId');
    final reviewRef = productRef.collection('reviews').doc(user.uid);
    final orderRef =
        _db.collection('users').doc(user.uid).collection('orders').doc(orderId);

    await _db.runTransaction((tx) async {
      final product = await tx.get(productRef);
      final existing = await tx.get(reviewRef);
      if (existing.exists) {
        throw CartException('Bu ürünü zaten değerlendirdiniz.');
      }
      final data = product.data();
      if (data != null) {
        final count = (data['ratingCount'] as num?)?.toInt() ?? 0;
        final avg = (data['rating'] as num?)?.toDouble() ?? 0;
        final newAvg = count == 0 ? rating.toDouble() : (avg * count + rating) / (count + 1);
        tx.update(productRef, {
          'rating': double.parse(newAvg.toStringAsFixed(2)),
          'ratingCount': count + 1,
        });
      }
      tx.set(reviewRef, {
        'userName': maskName(buyerName),
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(orderRef, {'reviewed.$productId': true});
    });
  }
}
