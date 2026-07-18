import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/app_user_profile.dart';
import '../../services/auth_service.dart';
import '../home/cabinets_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoading();
        }
        if (snapshot.data == null) return const LoginScreen();
        return StreamBuilder<AppUserProfile>(
          stream: AuthService().watchCurrentProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.danger,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'تعذر تحميل بيانات الحساب. تأكد من نشر قواعد '
                          'Firestore الجديدة.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: AuthService().signOut,
                          child: const Text('تسجيل الخروج'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!profileSnapshot.hasData) return const _AuthLoading();
            return CabinetsScreen(profile: profileSnapshot.data!);
          },
        );
      },
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              color: AppColors.teal,
              size: 52,
            ),
            SizedBox(height: 18),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
