import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/cabinet_box.dart';
import '../models/status_request.dart';
import 'status_pill.dart';

class BoxCard extends StatelessWidget {
  const BoxCard({
    super.key,
    required this.box,
    required this.updating,
    required this.pendingRequest,
    required this.onStatusChanged,
  });

  final CabinetBox box;
  final bool updating;
  final StatusRequest? pendingRequest;
  final ValueChanged<BoxStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.all_inbox_rounded,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'بوكس ${box.boxNumber}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            box.location == BoxLocation.internal
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            size: 16,
                            color: const Color(0xFF657D88),
                          ),
                          const SizedBox(width: 5),
                          Text(box.location.label),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusPill(status: box.status, compact: true),
              ],
            ),
            if (box.note != null && box.note!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pending.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.pending,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(box.note!)),
                  ],
                ),
              ),
            ],
            if (pendingRequest != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'طلب ${pendingRequest!.targetStatus.label} بواسطة '
                        '${pendingRequest!.requestedByName}، وينتظر موافقة '
                        'المسؤول.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            IgnorePointer(
              ignoring: updating || pendingRequest != null,
              child: Opacity(
                opacity: updating || pendingRequest != null ? .55 : 1,
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusChoice(
                        label: 'طلب تعليق',
                        icon: Icons.schedule_rounded,
                        selected: box.status == BoxStatus.pending,
                        selectedColor: AppColors.pending,
                        selectedBackground: AppColors.pendingSoft,
                        onTap: () => onStatusChanged(BoxStatus.pending),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatusChoice(
                        label: 'طلب تأكيد',
                        icon: Icons.check_circle_rounded,
                        selected: box.status == BoxStatus.confirmed,
                        selectedColor: AppColors.success,
                        selectedBackground: AppColors.successSoft,
                        onTap: () => onStatusChanged(BoxStatus.confirmed),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (updating) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.selectedBackground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color selectedBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? selectedBackground
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? selectedColor
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? selectedColor : const Color(0xFF657D88),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? selectedColor
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
