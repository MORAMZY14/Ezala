import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  final String uid;
  final String name;
  final String email;
  final String role;

  bool get isAdmin => role == 'admin';

  factory AppUserProfile.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    User fallback,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final fallbackName = fallback.displayName?.trim().isNotEmpty == true
        ? fallback.displayName!.trim()
        : fallback.email?.split('@').first ?? 'المستخدم';
    return AppUserProfile(
      uid: fallback.uid,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : fallbackName,
      email: (data['email'] as String?) ?? fallback.email ?? '',
      role: (data['role'] as String?) == 'admin' ? 'admin' : 'operator',
    );
  }
}
