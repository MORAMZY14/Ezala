import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/cabinet.dart';

class CabinetCard extends StatelessWidget {
  const CabinetCard({
    super.key,
    required this.cabinet,
    required this.onTap,
  });

  final Cabinet cabinet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = cabinet.isComplete;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: complete
                          ? AppColors.successSoft
                          : AppColors.mint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      complete
                          ? Icons.verified_rounded
                          : Icons.inventory_2_rounded,
                      color: complete
                          ? AppColors.success
                          : AppColors.teal,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 17,
                    color: Color(0xFF7B909A),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                cabinet.code,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 27,
                      letterSpacing: .6,
                    ),
              ),
              const SizedBox(height: 4),
              Text('${cabinet.boxCount} صندوق'),
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: cabinet.progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEAF0F2),
                  valueColor: AlwaysStoppedAnimation(
                    complete ? AppColors.success : AppColors.teal,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${cabinet.confirmedCount} مؤكد',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${cabinet.pendingCount} معلق',
                    style: const TextStyle(
                      color: AppColors.pending,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
