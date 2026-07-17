import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/cabinet.dart';
import '../../models/cabinet_box.dart';
import '../../services/cabinet_repository.dart';
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
  final _searchController = TextEditingController();
  final _updating = <String>{};

  String _query = '';
  _BoxFilter _filter = _BoxFilter.all;

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
    setState(() => _updating.add(box.id));
    try {
      await _repository.updateStatus(
        cabinet: widget.cabinet,
        box: box,
        newStatus: newStatus,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الحالة: $error')),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(box.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Cabinet ${widget.cabinet.code}'),
        ),
      ),
      body: StreamBuilder<List<CabinetBox>>(
        stream: _repository.watchBoxes(widget.cabinet.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل الصناديق: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final boxes = snapshot.data!;
          final visible = _visibleBoxes(boxes);
          final confirmed =
              boxes.where((box) => box.status == BoxStatus.confirmed).length;
          final pending = boxes.length - confirmed;

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
                          const SizedBox(height: 18),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              hintText: 'ابحث برقم الصندوق...',
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
                        child: Text('لا توجد صناديق في هذه الخزانة.'),
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
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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
                            onStatusChanged: (status) =>
                                _changeStatus(box, status),
                          );
                        },
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
                      'الخزانة',
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
                '$total صندوق',
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
