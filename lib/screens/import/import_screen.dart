import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../services/excel_import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _service = ExcelImportService();

  bool _busy = false;
  double _progress = 0;
  String _message = '';

  Future<void> _importBundled() async {
    try {
      final source = await rootBundle.loadString(
        'assets/data/mmr_cabinets.json',
      );
      final preview = _service.parseSeedJson(source);
      if (!mounted || !await _confirm(preview)) return;
      await _execute(preview: preview);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _pickExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final Uint8List bytes = file.bytes ?? await file.xFile.readAsBytes();
      final preview = _service.parseExcel(bytes, file.name);
      if (!mounted || !await _confirm(preview)) return;
      await _execute(
        preview: preview,
        rawBytes: bytes,
        rawFileName: file.name,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _confirm(ImportPreview preview) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تأكيد الاستيراد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  preview.sourceName,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _PreviewRow(label: 'الخزائن', value: preview.cabinetCount),
                _PreviewRow(label: 'الصناديق', value: preview.boxCount),
                _PreviewRow(label: 'مؤكد', value: preview.confirmedCount),
                _PreviewRow(label: 'قيد الانتظار', value: preview.pendingCount),
                const SizedBox(height: 14),
                const Text(
                  'سيتم تحديث البيانات المطابقة وحذف الصناديق القديمة غير '
                  'الموجودة في الملف داخل الخزائن المستوردة.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('بدء الاستيراد'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _execute({
    required ImportPreview preview,
    Uint8List? rawBytes,
    String? rawFileName,
  }) async {
    setState(() {
      _busy = true;
      _progress = 0;
      _message = 'جاري بدء الاستيراد...';
    });
    try {
      final result = await _service.importPreview(
        preview: preview,
        rawFileBytes: rawBytes,
        rawFileName: rawFileName,
        onProgress: (progress, message) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _message = message;
          });
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 46,
          ),
          title: const Text('تم الاستيراد بنجاح'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تم رفع ${result.cabinetCount} خزانة و'
                '${result.boxCount} صندوق.',
              ),
              if (result.storageWarning != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pendingSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.storageWarning!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تم'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = 0;
          _message = '';
        });
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is FormatException
        ? error.message.toString()
        : 'تعذر استيراد الملف: $error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد البيانات')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.ink, Color(0xFF155E63)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.table_view_rounded,
                        color: Color(0xFF5EEAD4),
                        size: 42,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Excel → Firebase',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'يحفظ التطبيق نسخة الملف في Storage ثم يحول '
                              'الخزائن والصناديق إلى بيانات حية في Firestore.',
                              style: TextStyle(
                                color: Color(0xFFD2E7EA),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _ImportOption(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.teal,
                  title: 'استيراد البيانات المرفقة',
                  subtitle:
                      '17 خزانة • 1,046 صندوق • جاهزة من الملف الذي أرسلته',
                  buttonLabel: 'تحميل بيانات البداية',
                  onPressed: _busy ? null : _importBundled,
                ),
                const SizedBox(height: 12),
                _ImportOption(
                  icon: Icons.upload_file_rounded,
                  iconColor: AppColors.pending,
                  title: 'اختيار ملف Excel جديد',
                  subtitle:
                      'كل Sheet يمثل خزانة، والأعمدة الثلاثة هي رقم الصندوق '
                      'والموقع وحالة الاستلام.',
                  buttonLabel: 'اختيار ملف .xlsx',
                  onPressed: _busy ? null : _pickExcel,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.pendingSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.pending,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'الخلايا الفارغة تعتبر قيد الانتظار. القيمة الخاصة '
                          'Cast 7-9 في A-3 / BOX 13 محفوظة كملاحظة.',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_message)),
                              Text('${(_progress * 100).round()}٪'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LinearProgressIndicator(value: _progress),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
