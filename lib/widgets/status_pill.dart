import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/cabinet_box.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.compact = false});

  final BoxStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final confirmed = status == BoxStatus.confirmed;
    final color = confirmed ? AppColors.success : AppColors.pending;
    final background =
        confirmed ? AppColors.successSoft : AppColors.pendingSoft;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmed
                ? Icons.check_circle_rounded
                : Icons.schedule_rounded,
            color: color,
            size: compact ? 15 : 17,
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
