import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/cabinet.dart';
import '../../models/cabinet_box.dart';
import '../../models/status_request.dart';
import '../../services/cabinet_repository.dart';
import '../../services/status_request_repository.dart';
import '../../widgets/box_card.dart';

enum _BoxFilter { all, pending, confirmed, internal, external }

class CabinetDetailsScreen extends StatefulWidget {
  const CabinetDetailsScreen({super.key, required this.cabinet});

  final Cabinet cabinet;

  @override
  State<CabinetDetailsScreen> createState() =>
      _CabinetDetailsScreenState();
}

class _CabinetDetailsScreenState extends State<CabinetDetailsScreen> {
  final _repository = CabinetRepository();
  final _statusRepository = StatusRequestRepository();
  final _searchController = TextEditingController();
  final _updating = <String>{};

  String _query = '';
  _BoxFilter _filter = _BoxFilter.all;
  bool _addingBox = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CabinetBox> _visibleBoxes(List<CabinetBox> boxes) {
    final query = _query.trim().toLowerCase();
    return boxes.where((box) {
      final matchesQuery = query.isEmpty ||
          box.displayName.toLowerCase().contains(query) ||
          box.boxNumber.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _BoxFilter.all => true,
        _BoxFilter.pending => box.status == BoxStatus.pending,
        _BoxFilter.confirmed => box.status == BoxStatus.confirmed,
        _BoxFilter.internal => box.location == BoxLocation.internal,
        _BoxFilter.external => box.location == BoxLocation.external,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _changeStatus(
    CabinetBox box,
    BoxStatus newStatus,
  ) async {
    if (box.status == newStatus || _updating.contains(box.id)) return;
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          newStatus == BoxStatus.confirmed
              ? Icons.check_circle_outline_rounded
              : Icons.schedule_rounded,
        ),
        title: const Text('إرسال طلب تغيير الحالة'),
        content: Text(
          'هل تريد طلب تحويل بوكس ${box.boxNumber} إلى '
          '${newStatus.label}؟ لن تتغير الحالة قبل موافقة المسؤول.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
    if (shouldSubmit != true || !mounted) return;

    setState(() => _updating.add(box.id));
    try {
      await _statusRepository.submitRequest(
        cabinet: widget.cabinet,
        box: box,
        targetStatus: newStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الطلب وينتظر موافقة المسؤول.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الطلب: $error')),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(box.id));
    }
  }

  Future<void> _changeLocation(
    CabinetBox box,
    BoxLocation newLocation,
  ) async {
    if (box.location == newLocation || _updating.contains(box.id)) return;
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          newLocation == BoxLocation.external
              ? Icons.logout_rounded
              : Icons.login_rounded,
        ),
        title: const Text('إرسال طلب تغيير النوع'),
        content: Text(
          'هل تريد طلب تحويل بوكس ${box.boxNumber} من '
          '${box.location.label} إلى ${newLocation.label}؟ لن يتغير النوع '
          'قبل موافقة المسؤول.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
    if (shouldSubmit != true || !mounted) return;

    setState(() => _updating.add(box.id));
    try {
      await _statusRepository.submitLocationRequest(
        cabinet: widget.cabinet,
        box: box,
        targetLocation: newLocation,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب التحويل وينتظر موافقة المسؤول.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الطلب: $error')),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(box.id));
    }
  }

  Future<void> _addBox() async {
    if (_addingBox) return;
    final draft = await showDialog<_NewBoxDraft>(
      context: context,
      builder: (_) => const _AddBoxDialog(),
    );
    if (draft == null || !mounted) return;

    setState(() => _addingBox = true);
    try {
      await _statusRepository.submitAddBoxRequest(
        cabinet: widget.cabinet,
        boxNumber: draft.boxNumber,
        displayName: draft.displayName,
        location: draft.location,
        note: draft.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب إضافة البوكس وينتظر موافقة المسؤول.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال طلب الإضافة: $error')),
      );
    } finally {
      if (mounted) setState(() => _addingBox = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: TextDirection.ltr,
          child: Text('كابينة ${widget.cabinet.code}'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addingBox ? null : _addBox,
        icon: _addingBox
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_box_rounded),
        label: const Text('إضافة بوكس'),
      ),
      body: StreamBuilder<List<CabinetBox>>(
        stream: _repository.watchBoxes(widget.cabinet.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل البوكسات: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final boxes = snapshot.data!;
          final visible = _visibleBoxes(boxes);
          final confirmed =
              boxes.where((box) => box.status == BoxStatus.confirmed).length;
          final pending = boxes.length - confirmed;

          return StreamBuilder<List<StatusRequest>>(
            stream: _statusRepository.watchRequestsForCabinet(
              widget.cabinet.id,
            ),
            builder: (context, requestSnapshot) {
              final requests =
                  requestSnapshot.data ?? const <StatusRequest>[];
              final pendingStatusByBox = <String, StatusRequest>{
                for (final request in requests)
                  if (request.isPending && request.isStatusChange)
                    request.boxId: request,
              };
              final pendingLocationByBox = <String, StatusRequest>{
                for (final request in requests)
                  if (request.isPending && request.isLocationChange)
                    request.boxId: request,
              };
              final pendingAdditions = requests
                  .where((request) => request.isPending && request.isAddBox)
                  .length;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CabinetHeader(
                            code: widget.cabinet.code,
                            total: boxes.length,
                            confirmed: confirmed,
                            pending: pending,
                          ),
                          if (pendingAdditions > 0) ...[
                            const SizedBox(height: 12),
                            _PendingAdditionsBanner(count: pendingAdditions),
                          ],
                          const SizedBox(height: 18),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              hintText: 'ابحث برقم البوكس...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _BoxFilterChip(
                                  label: 'الكل',
                                  selected: _filter == _BoxFilter.all,
                                  onTap: () => setState(
                                    () => _filter = _BoxFilter.all,
                                  ),
                                ),
                                _BoxFilterChip(
                                  label: 'قيد الانتظار',
                                  selected: _filter == _BoxFilter.pending,
                                  onTap: () => setState(
                                    () => _filter = _BoxFilter.pending,
                                  ),
                                ),
                                _BoxFilterChip(
                                  label: 'مؤكد',
                                  selected: _filter == _BoxFilter.confirmed,
                                  onTap: () => setState(
                                    () => _filter = _BoxFilter.confirmed,
                                  ),
                                ),
                                _BoxFilterChip(
                                  label: 'داخلي',
                                  selected: _filter == _BoxFilter.internal,
                                  onTap: () => setState(
                                    () => _filter = _BoxFilter.internal,
                                  ),
                                ),
                                _BoxFilterChip(
                                  label: 'خارجي',
                                  selected: _filter == _BoxFilter.external,
                                  onTap: () => setState(
                                    () => _filter = _BoxFilter.external,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (boxes.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('لا توجد بوكسات في هذه الكابينة.'),
                      ),
                    )
                  else if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('لا توجد نتائج مطابقة.'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      sliver: SliverList.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final box = visible[index];
                          return BoxCard(
                            key: ValueKey(box.id),
                            box: box,
                            updating: _updating.contains(box.id),
                            pendingStatusRequest:
                                pendingStatusByBox[box.id],
                            pendingLocationRequest:
                                pendingLocationByBox[box.id],
                            onStatusChanged: (status) =>
                                _changeStatus(box, status),
                            onLocationChanged: (location) =>
                                _changeLocation(box, location),
                          );
                        },
                      ),
                    ),
                ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CabinetHeader extends StatelessWidget {
  const _CabinetHeader({
    required this.code,
    required this.total,
    required this.confirmed,
    required this.pending,
  });

  final String code;
  final int total;
  final int confirmed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : confirmed / total;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF5EEAD4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الكابينة',
                      style: TextStyle(color: Color(0xFFC8DDE1)),
                    ),
                    Text(
                      code,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}٪',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .12),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF5EEAD4)),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Text(
                '$total بوكس',
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              Text(
                '$confirmed مؤكد',
                style: const TextStyle(
                  color: Color(0xFF86EFAC),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$pending معلق',
                style: const TextStyle(
                  color: Color(0xFFFCD34D),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoxFilterChip extends StatelessWidget {
  const _BoxFilterChip({
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
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}

class _PendingAdditionsBanner extends StatelessWidget {
  const _PendingAdditionsBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pending_actions_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$count طلب إضافة بوكس ينتظر موافقة المسؤول.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewBoxDraft {
  const _NewBoxDraft({
    required this.boxNumber,
    required this.displayName,
    required this.location,
    required this.note,
  });

  final String boxNumber;
  final String displayName;
  final BoxLocation location;
  final String note;
}

class _AddBoxDialog extends StatefulWidget {
  const _AddBoxDialog();

  @override
  State<_AddBoxDialog> createState() => _AddBoxDialogState();
}

class _AddBoxDialogState extends State<_AddBoxDialog> {
  final _formKey = GlobalKey<FormState>();
  final _boxNumberController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _noteController = TextEditingController();
  BoxLocation _location = BoxLocation.internal;

  @override
  void dispose() {
    _boxNumberController.dispose();
    _displayNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      _NewBoxDraft(
        boxNumber: _boxNumberController.text.trim(),
        displayName: _displayNameController.text.trim(),
        location: _location,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.add_box_rounded),
      title: const Text('طلب إضافة بوكس'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'لن يظهر البوكس داخل الكابينة إلا بعد موافقة المسؤول.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _boxNumberController,
                  autofocus: true,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم البوكس *',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'أدخل رقم البوكس.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _displayNameController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'اسم البوكس (اختياري)',
                    hintText: 'BOX 12',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'نوع البوكس',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<BoxLocation>(
                  segments: const [
                    ButtonSegment(
                      value: BoxLocation.internal,
                      label: Text('داخلي'),
                      icon: Icon(Icons.login_rounded),
                    ),
                    ButtonSegment(
                      value: BoxLocation.external,
                      label: Text('خارجي'),
                      icon: Icon(Icons.logout_rounded),
                    ),
                  ],
                  selected: {_location},
                  onSelectionChanged: (selection) {
                    setState(() => _location = selection.first);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_rounded),
          label: const Text('إرسال للموافقة'),
        ),
      ],
    );
  }
}
