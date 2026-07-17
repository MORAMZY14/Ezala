import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/startup_error.dart';

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = error is FirebaseSetupRequired;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.cloud_sync_rounded,
                          color: AppColors.teal,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        isPlaceholder
                            ? 'اربط التطبيق بـ Firebase'
                            : 'تعذر تشغيل Firebase',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'المشروع جاهز، لكنه يحتاج بيانات مشروع Firebase الخاص بك '
                        'قبل تسجيل الدخول ورفع ملف Excel.',
                      ),
                      const SizedBox(height: 24),
                      const _SetupStep(
                        number: '1',
                        title: 'أنشئ مشروع Firebase',
                        body:
                            'فعّل Email/Password وCloud Firestore وCloud Storage.',
                      ),
                      const _SetupStep(
                        number: '2',
                        title: 'أنشئ ملفات المنصات',
                        body:
                            'شغّل flutter create . ثم flutterfire configure من مجلد المشروع.',
                      ),
                      const _SetupStep(
                        number: '3',
                        title: 'انشر قواعد الحماية',
                        body:
                            'شغّل firebase deploy --only firestore:rules,storage.',
                      ),
                      if (!isPlaceholder) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.pendingSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(
                            error.toString(),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
