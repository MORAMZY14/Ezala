import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/app_user_profile.dart';
import '../../models/cabinet.dart';
import '../../services/auth_service.dart';
import '../../services/cabinet_repository.dart';
import '../../services/status_request_repository.dart';
import '../../widgets/cabinet_card.dart';
import '../../widgets/theme_toggle_button.dart';
import '../activity/activity_screen.dart';
import '../import/import_screen.dart';
import 'cabinet_details_screen.dart';

enum _CabinetFilter { all, pending, complete }

class CabinetsScreen extends StatefulWidget {
  const CabinetsScreen({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<CabinetsScreen> createState() => _CabinetsScreenState();
}

class _CabinetsScreenState extends State<CabinetsScreen> {
  final _repository = CabinetRepository();
  final _statusRepository = StatusRequestRepository();
  final _auth = AuthService();
  final _searchController = TextEditingController();

  _CabinetFilter _filter = _CabinetFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openImport() async {
    if (!widget.profile.isAdmin) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ImportScreen()),
    );
  }

  Future<void> _openActivity() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityScreen(isAdmin: widget.profile.isAdmin),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _auth.signOut();
  }

  List<Cabinet> _filterCabinets(List<Cabinet> cabinets) {
    final query = _query.trim().toLowerCase();
    return cabinets.where((cabinet) {
      final matchesQuery =
          query.isEmpty || cabinet.code.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _CabinetFilter.all => true,
        _CabinetFilter.pending => cabinet.pendingCount > 0,
        _CabinetFilter.complete => cabinet.isComplete,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.profile.name;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ezla Project'),
                Text(
                  widget.profile.isAdmin
                      ? 'لوحة المسؤول'
                      : 'لوحة متابعة الاستلام',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          _ActivityButton(
            stream: _statusRepository.watchPendingRequestCount(),
            onPressed: _openActivity,
          ),
          PopupMenuButton<String>(
            tooltip: 'الحساب',
            onSelected: (value) {
              if (value == 'activity') _openActivity();
              if (value == 'import') _openImport();
              if (value == 'logout') _signOut();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'activity',
                child: ListTile(
                  leading: Icon(Icons.bolt_rounded),
                  title: Text('النشاط المباشر'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (widget.profile.isAdmin)
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.upload_file_rounded),
                    title: Text('استيراد Excel'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('تسجيل الخروج'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CircleAvatar(
                backgroundColor: AppColors.mint,
                foregroundColor: AppColors.tealDark,
                child: Text(
                  userName.characters.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<List<Cabinet>>(
        stream: _repository.watchCabinets(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cabinets = snapshot.data!;
          final visible = _filterCabinets(cabinets);
          final totalBoxes =
              cabinets.fold(0, (sum, item) => sum + item.boxCount);
          final confirmed =
              cabinets.fold(0, (sum, item) => sum + item.confirmedCount);
          final pending =
              cabinets.fold(0, (sum, item) => sum + item.pendingCount);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                children: [
                  Text(
                    'أهلًا، $userName',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'اختر كابينة لمراجعة البوكسات وإرسال طلبات تحديث الحالة.',
                  ),
                  const SizedBox(height: 22),
                  _SummaryPanel(
                    cabinetCount: cabinets.length,
                    totalBoxes: totalBoxes,
                    confirmed: confirmed,
                    pending: pending,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن A-1 أو B-2...',
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
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'الكل',
                          selected: _filter == _CabinetFilter.all,
                          onSelected: () => setState(
                            () => _filter = _CabinetFilter.all,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'بها معلق',
                          selected: _filter == _CabinetFilter.pending,
                          onSelected: () => setState(
                            () => _filter = _CabinetFilter.pending,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'مكتملة',
                          selected: _filter == _CabinetFilter.complete,
                          onSelected: () => setState(
                            () => _filter = _CabinetFilter.complete,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (cabinets.isEmpty)
                    _EmptyCabinets(
                      onImport: widget.profile.isAdmin ? _openImport : null,
                    )
                  else if (visible.isEmpty)
                    const _NoSearchResults()
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 1080
                            ? 4
                            : width >= 720
                                ? 3
                                : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visible.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: width < 500 ? .76 : .9,
                          ),
                          itemBuilder: (context, index) {
                            final cabinet = visible[index];
                            return CabinetCard(
                              cabinet: cabinet,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CabinetDetailsScreen(
                                    cabinet: cabinet,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
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

class _ActivityButton extends StatelessWidget {
  const _ActivityButton({
    required this.stream,
    required this.onPressed,
  });

  final Stream<int> stream;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'النشاط المباشر',
              onPressed: onPressed,
              icon: const Icon(Icons.bolt_rounded),
            ),
            if (count > 0)
              PositionedDirectional(
                top: 2,
                end: 1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.cabinetCount,
    required this.totalBoxes,
    required this.confirmed,
    required this.pending,
  });

  final int cabinetCount;
  final int totalBoxes;
  final int confirmed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final progress = totalBoxes == 0 ? 0.0 : confirmed / totalBoxes;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.ink, Color(0xFF155E63)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26102A3A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'نسبة الاستلام الإجمالية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}٪',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: .14),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF5EEAD4)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryValue(label: 'الكبائن', value: cabinetCount),
              _SummaryDivider(),
              _SummaryValue(label: 'البوكسات', value: totalBoxes),
              _SummaryDivider(),
              _SummaryValue(label: 'مؤكد', value: confirmed),
              _SummaryDivider(),
              _SummaryValue(label: 'معلق', value: pending),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC8DDE1),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: .14),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

class _EmptyCabinets extends StatelessWidget {
  const _EmptyCabinets({required this.onImport});

  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.teal,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد كبائن بعد',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              onImport == null
                  ? 'اطلب من المسؤول استيراد ملف Excel لبدء العمل.'
                  : 'استورد ملف Excel المرفق لبدء العمل.',
            ),
            if (onImport != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('استيراد البيانات'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: Text('لا توجد كبائن تطابق البحث.')),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            const Text('تعذر تحميل الكبائن.'),
            const SizedBox(height: 8),
            SelectableText(
              error,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
