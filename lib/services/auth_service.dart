import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_user_profile.dart';

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

  Stream<AppUserProfile> watchCurrentProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(StateError('Authentication required'));
    }
    return _firestore.collection('users').doc(user.uid).snapshots().map(
          (snapshot) => AppUserProfile.fromDoc(snapshot, user),
        );
  }

  Future<AppUserProfile> currentProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication required');
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    return AppUserProfile.fromDoc(snapshot, user);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    await _ensureUserProfile(credential.user!);
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

  Future<void> _ensureUserProfile(User user) async {
    final reference = _firestore.collection('users').doc(user.uid);
    final snapshot = await reference.get();
    final fallbackName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? 'المستخدم';

    if (snapshot.exists) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      if ((data['name'] as String?)?.trim().isNotEmpty == true) return;
      await reference.set({
        'name': fallbackName,
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await reference.set({
      'name': fallbackName,
      'email': user.email ?? '',
      'role': 'operator',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'ليست لديك صلاحية تنفيذ هذه العملية. تأكد من نشر قواعد Firebase.',
        'unavailable' => 'خدمة Firebase غير متاحة حاليًا. حاول مرة أخرى.',
        _ => error.message ?? 'حدث خطأ في Firebase.',
      };
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }
}
