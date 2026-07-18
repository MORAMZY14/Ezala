import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/status_activity.dart';
import '../../models/status_request.dart';
import '../../services/status_request_repository.dart';

enum _ActivityFilter { all, requests, approved, rejected }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _repository = StatusRequestRepository();
  final _processing = <String>{};
  _ActivityFilter _filter = _ActivityFilter.all;

  List<StatusActivity> _visibleActivities(List<StatusActivity> activities) {
    return activities.where((activity) {
      return switch (_filter) {
        _ActivityFilter.all => true,
        _ActivityFilter.requests =>
          activity.type == StatusActivityType.requestCreated,
        _ActivityFilter.approved =>
          activity.type == StatusActivityType.requestApproved,
        _ActivityFilter.rejected =>
          activity.type == StatusActivityType.requestRejected,
      };
    }).toList();
  }

  Future<void> _review(
    StatusRequest request, {
    required bool approve,
  }) async {
    if (_processing.contains(request.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          approve
              ? Icons.verified_user_rounded
              : Icons.cancel_outlined,
          color: approve ? AppColors.success : AppColors.danger,
        ),
        title: Text(approve ? 'اعتماد الطلب' : 'رفض الطلب'),
        content: Text(
          approve
              ? 'سيتم تحويل ${request.boxLabel} في كابينة '
                  '${request.cabinetCode} إلى ${request.targetStatus.label}. '
                  'هل تريد المتابعة؟'
              : 'هل تريد رفض طلب ${request.requestedByName} لتغيير '
                  '${request.boxLabel} إلى ${request.targetStatus.label}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: approve
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'موافقة وتنفيذ' : 'رفض الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing.add(request.id));
    try {
      if (approve) {
        await _repository.approveRequest(request);
      } else {
        await _repository.rejectRequest(request);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'تم اعتماد الطلب وتحديث البوكس.' : 'تم رفض الطلب.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر مراجعة الطلب: $error')),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النشاط المباشر')),
      body: StreamBuilder<List<StatusActivity>>(
        stream: _repository.watchActivities(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('تعذر تحميل النشاط: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = _visibleActivities(snapshot.data!);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  _ActivityHeader(isAdmin: widget.isAdmin),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 18),
                    StreamBuilder<List<StatusRequest>>(
                      stream: _repository.watchPendingRequests(),
                      builder: (context, requestSnapshot) {
                        final requests = requestSnapshot.data ??
                            const <StatusRequest>[];
                        return _PendingApprovals(
                          requests: requests,
                          processing: _processing,
                          onApprove: (request) =>
                              _review(request, approve: true),
                          onReject: (request) =>
                              _review(request, approve: false),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'سجل النشاط',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'الكل',
                          selected: _filter == _ActivityFilter.all,
                          onTap: () => setState(
                            () => _filter = _ActivityFilter.all,
                          ),
                        ),
                        _FilterChip(
                          label: 'الطلبات',
                          selected: _filter == _ActivityFilter.requests,
                          onTap: () => setState(
                            () => _filter = _ActivityFilter.requests,
                          ),
                        ),
                        _FilterChip(
                          label: 'الموافقات',
                          selected: _filter == _ActivityFilter.approved,
                          onTap: () => setState(
                            () => _filter = _ActivityFilter.approved,
                          ),
                        ),
                        _FilterChip(
                          label: 'المرفوضة',
                          selected: _filter == _ActivityFilter.rejected,
                          onTap: () => setState(
                            () => _filter = _ActivityFilter.rejected,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (activities.isEmpty)
                    const _EmptyActivity()
                  else
                    ...activities.map(
                      (activity) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActivityCard(activity: activity),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.ink, Color(0xFF155E63)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFF5EEAD4),
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تحديثات لحظية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'راجع الطلبات وشاهد من طلب ومن وافق.'
                      : 'تابع طلبات الفريق وقرارات المسؤولين مباشرة.',
                  style: const TextStyle(
                    color: Color(0xFFD2E7EA),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingApprovals extends StatelessWidget {
  const _PendingApprovals({
    required this.requests,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final List<StatusRequest> requests;
  final Set<String> processing;
  final ValueChanged<StatusRequest> onApprove;
  final ValueChanged<StatusRequest> onReject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'طلبات تنتظر الموافقة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Badge(
              label: Text('${requests.length}'),
              backgroundColor: AppColors.pending,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (requests.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.task_alt_rounded, color: AppColors.success),
                SizedBox(width: 9),
                Text('لا توجد طلبات معلقة الآن.'),
              ],
            ),
          )
        else
          ...requests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ApprovalCard(
                request: request,
                busy: processing.contains(request.id),
                onApprove: () => onApprove(request),
                onReject: () => onReject(request),
              ),
            ),
          ),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final StatusRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.pending.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: AppColors.pending,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.boxLabel} • كابينة '
                        '${request.cabinetCode}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${request.requestedByName} طلب التحويل من '
                        '${request.previousStatus.label} إلى '
                        '${request.targetStatus.label}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('موافقة'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final StatusActivity activity;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = switch (activity.type) {
      StatusActivityType.requestCreated => (
          Icons.outbox_rounded,
          AppColors.pending,
          'تم إرسال طلب',
        ),
      StatusActivityType.requestApproved => (
          Icons.verified_rounded,
          AppColors.success,
          'تم اعتماد التغيير',
        ),
      StatusActivityType.requestRejected => (
          Icons.cancel_rounded,
          AppColors.danger,
          'تم رفض الطلب',
        ),
    };

    final description = switch (activity.type) {
      StatusActivityType.requestCreated =>
        '${activity.actorName} طلب تحويل ${activity.boxLabel} في كابينة '
            '${activity.cabinetCode} إلى ${activity.targetStatus.label}.',
      StatusActivityType.requestApproved =>
        '${activity.actorName} وافق على طلب ${activity.requestedByName}، '
            'وتم تحويل ${activity.boxLabel} إلى '
            '${activity.targetStatus.label}.',
      StatusActivityType.requestRejected =>
        '${activity.actorName} رفض طلب ${activity.requestedByName} لتحويل '
            '${activity.boxLabel} إلى ${activity.targetStatus.label}.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        _formatTime(activity.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(description),
                  const SizedBox(height: 6),
                  Text(
                    '${activity.boxLabel} • كابينة ${activity.cabinetCode}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            const Text('لا يوجد نشاط مطابق حتى الآن.'),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime? value) {
  if (value == null) return 'الآن';
  final difference = DateTime.now().difference(value);
  if (difference.inSeconds < 60) return 'الآن';
  if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} د';
  if (difference.inHours < 24) return 'منذ ${difference.inHours} س';
  if (difference.inDays < 7) return 'منذ ${difference.inDays} يوم';
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} '
      '${value.hour}:$minute';
}
