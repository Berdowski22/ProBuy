import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Demo gate: business accounts need this code at registration.
  static const businessCode = 'PROBUY2026';

  Future<void> register({
    required String name,
    required String email,
    required String password,
    bool business = false,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(name.trim());
      await _db.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'email': user.email,
        'role': business ? 'business' : 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  Future<void> logout() => _auth.signOut();

  Future<bool> isBusiness() async {
    final profile = await getProfile();
    return profile['role'] == 'business';
  }

  Future<Map<String, dynamic>> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) return {};
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data() ?? {};
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Oturum bulunamadı.');
    try {
      await user.updateDisplayName(name.trim());
      await _db.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException('Profil güncellenemedi: ${e.code}');
    }
  }

  Future<void> sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email == null) throw AuthException('Oturum bulunamadı.');
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta ile zaten bir hesap var.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'weak-password':
        return 'Şifre çok zayıf (en az 6 karakter).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      case 'operation-not-allowed':
        return 'E-posta/şifre girişi Firebase konsolunda etkin değil.';
      default:
        return 'Giriş hatası: ${e.code}';
    }
  }
}
