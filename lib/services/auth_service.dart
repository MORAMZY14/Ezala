import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get userChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(name.trim());
    await _firestore.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'role': 'operator',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  Future<void> signOut() => _auth.signOut();

  static String arabicError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'البريد الإلكتروني غير صحيح.',
        'user-disabled' => 'تم تعطيل هذا الحساب.',
        'user-not-found' => 'لا يوجد حساب بهذا البريد الإلكتروني.',
        'wrong-password' || 'invalid-credential' =>
          'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
        'email-already-in-use' => 'هذا البريد مستخدم بالفعل.',
        'weak-password' => 'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل.',
        'too-many-requests' => 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
        'network-request-failed' => 'تعذر الاتصال بالإنترنت.',
        _ => error.message ?? 'حدث خطأ في تسجيل الدخول.',
      };
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }
}
