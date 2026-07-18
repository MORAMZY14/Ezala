import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'source_normalizer.dart';

typedef ImportProgressCallback = void Function(
  double progress,
  String message,
);

class ImportBoxData {
  const ImportBoxData({
    required this.id,
    required this.cabinetCode,
    required this.boxNumber,
    required this.displayName,
    required this.location,
    required this.status,
    required this.sortIndex,
    this.note,
    this.sourceRow,
  });

  final String id;
  final String cabinetCode;
  final String boxNumber;
  final String displayName;
  final String location;
  final String status;
  final int sortIndex;
  final String? note;
  final int? sourceRow;

  Map<String, Object?> toFirestore(String userId) {
    return {
      'cabinetCode': cabinetCode,
      'boxNumber': boxNumber,
      'displayName': displayName,
      'location': location,
      'locationLabel': location == 'external' ? 'خارجي' : 'داخلي',
      'status': status,
      'statusLabel': status == 'confirmed' ? 'مؤكد' : 'قيد الانتظار',
      'sortIndex': sortIndex,
      'note': note,
      'sourceRow': sourceRow,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    };
  }
}

class ImportCabinetData {
  const ImportCabinetData({
    required this.id,
    required this.code,
    required this.sortIndex,
    required this.boxes,
  });

  final String id;
  final String code;
  final int sortIndex;
  final List<ImportBoxData> boxes;

  int get confirmedCount =>
      boxes.where((box) => box.status == 'confirmed').length;
  int get pendingCount => boxes.length - confirmedCount;
}

class ImportPreview {
  const ImportPreview({
    required this.sourceName,
    required this.cabinets,
  });

  final String sourceName;
  final List<ImportCabinetData> cabinets;

  int get cabinetCount => cabinets.length;
  int get boxCount =>
      cabinets.fold(0, (total, cabinet) => total + cabinet.boxes.length);
  int get confirmedCount => cabinets.fold(
        0,
        (total, cabinet) => total + cabinet.confirmedCount,
      );
  int get pendingCount => boxCount - confirmedCount;
}

class ImportResult {
  const ImportResult({
    required this.cabinetCount,
    required this.boxCount,
    this.storagePath,
    this.storageWarning,
  });

  final int cabinetCount;
  final int boxCount;
  final String? storagePath;
  final String? storageWarning;
}

class ExcelImportService {
  ExcelImportService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  ImportPreview parseExcel(Uint8List bytes, String fileName) {
    final workbook = excel.Excel.decodeBytes(bytes);
    final cabinets = <ImportCabinetData>[];

    for (final entry in workbook.tables.entries) {
      final sheet = entry.value;
      if (sheet == null) continue;

      final code = SourceNormalizer.clean(entry.key).toUpperCase();
      if (code.isEmpty) continue;

      final boxes = <ImportBoxData>[];
      final usedIds = <String>{};
      final rows = sheet.rows;
      for (var rowIndex = 2; rowIndex < rows.length; rowIndex += 1) {
        final row = rows[rowIndex];
        final displayName = SourceNormalizer.clean(_valueAt(row, 0));
        if (displayName.isEmpty) continue;

        final location = SourceNormalizer.normalizeLocation(_valueAt(row, 1));
        final normalizedStatus =
            SourceNormalizer.normalizeStatus(_valueAt(row, 2));
        final boxNumber = SourceNormalizer.extractBoxNumber(
          displayName,
          rowIndex - 1,
        );

        var id = SourceNormalizer.safeDocumentId(boxNumber, rowIndex + 1);
        final idBase = id;
        var duplicateIndex = 2;
        while (usedIds.contains(id)) {
          id = '$idBase-$duplicateIndex';
          duplicateIndex += 1;
        }
        usedIds.add(id);

        boxes.add(
          ImportBoxData(
            id: id,
            cabinetCode: code,
            boxNumber: boxNumber,
            displayName: displayName,
            location: location,
            status: normalizedStatus.status,
            note: normalizedStatus.note,
            sortIndex: boxes.length + 1,
            sourceRow: rowIndex + 1,
          ),
        );
      }

      if (boxes.isNotEmpty) {
        cabinets.add(
          ImportCabinetData(
            id: code.toLowerCase(),
            code: code,
            sortIndex: cabinets.length + 1,
            boxes: boxes,
          ),
        );
      }
    }

    final preview = ImportPreview(sourceName: fileName, cabinets: cabinets);
    _validate(preview);
    return preview;
  }

  ImportPreview parseSeedJson(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final cabinetMaps = root['cabinets'] as List<dynamic>? ?? const [];
    final cabinets = <ImportCabinetData>[];

    for (final rawCabinet in cabinetMaps) {
      final map = rawCabinet as Map<String, dynamic>;
      final code = SourceNormalizer.clean(map['code']).toUpperCase();
      final rawBoxes = map['boxes'] as List<dynamic>? ?? const [];
      final boxes = rawBoxes.map((rawBox) {
        final box = rawBox as Map<String, dynamic>;
        return ImportBoxData(
          id: SourceNormalizer.clean(box['id']),
          cabinetCode: code,
          boxNumber: SourceNormalizer.clean(box['boxNumber']),
          displayName: SourceNormalizer.clean(box['displayName']),
          location: SourceNormalizer.clean(box['location']),
          status: SourceNormalizer.clean(box['status']),
          note: box['note'] as String?,
          sortIndex: (box['sortIndex'] as num?)?.toInt() ?? 0,
          sourceRow: (box['sourceRow'] as num?)?.toInt(),
        );
      }).toList();

      cabinets.add(
        ImportCabinetData(
          id: SourceNormalizer.clean(map['id']),
          code: code,
          sortIndex: (map['sortIndex'] as num?)?.toInt() ?? cabinets.length + 1,
          boxes: boxes,
        ),
      );
    }

    final preview = ImportPreview(
      sourceName: 'البيانات المرفقة',
      cabinets: cabinets,
    );
    _validate(preview);
    return preview;
  }

  Future<ImportResult> importPreview({
    required ImportPreview preview,
    Uint8List? rawFileBytes,
    String? rawFileName,
    ImportProgressCallback? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication required');
    final userSnapshot =
        await _firestore.collection('users').doc(user.uid).get();
    if (userSnapshot.data()?['role'] != 'admin') {
      throw StateError('استيراد البيانات متاح للمسؤولين فقط.');
    }
    _validate(preview);

    final importRef = _firestore.collection('imports').doc();
    await importRef.set({
      'sourceName': preview.sourceName,
      'cabinetCount': preview.cabinetCount,
      'boxCount': preview.boxCount,
      'confirmedCount': preview.confirmedCount,
      'pendingCount': preview.pendingCount,
      'status': 'running',
      'createdBy': user.uid,
      'createdByName': user.displayName ?? user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    String? storagePath;
    String? storageWarning;
    try {
      if (rawFileBytes != null && rawFileName != null) {
        onProgress?.call(0.04, 'جاري حفظ نسخة ملف Excel...');
        final safeName = rawFileName.replaceAll(
          RegExp('[^A-Za-z0-9._-]'),
          '_',
        );
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final path = 'imports/${user.uid}/${stamp}_$safeName';
        final reference = _storage.ref(path);
        await reference.putData(
          rawFileBytes,
          SettableMetadata(
            contentType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        );
        storagePath = path;
      }
    } catch (error) {
      storageWarning =
          'تم استيراد البيانات، لكن تعذر حفظ نسخة Excel في Storage: $error';
    }

    try {
      onProgress?.call(0.1, 'جاري مقارنة البيانات الحالية...');
      final writes = <void Function(WriteBatch)>[];

      for (final cabinet in preview.cabinets) {
        final cabinetRef =
            _firestore.collection('cabinets').doc(cabinet.id);
        final boxesRef = cabinetRef.collection('boxes');
        final existing = await boxesRef.get();
        final incomingIds = cabinet.boxes.map((box) => box.id).toSet();

        for (final document in existing.docs) {
          if (!incomingIds.contains(document.id)) {
            writes.add((batch) => batch.delete(document.reference));
          }
        }

        writes.add(
          (batch) => batch.set(
            cabinetRef,
            {
              'code': cabinet.code,
              'sortIndex': cabinet.sortIndex,
              'boxCount': cabinet.boxes.length,
              'confirmedCount': cabinet.confirmedCount,
              'pendingCount': cabinet.pendingCount,
              'sourceName': preview.sourceName,
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': user.uid,
            },
            SetOptions(merge: true),
          ),
        );

        for (final box in cabinet.boxes) {
          final boxRef = boxesRef.doc(box.id);
          final data = box.toFirestore(user.uid);
          writes.add((batch) => batch.set(boxRef, data));
        }
      }

      const chunkSize = 400;
      for (var start = 0; start < writes.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, writes.length).toInt();
        final batch = _firestore.batch();
        for (final write in writes.sublist(start, end)) {
          write(batch);
        }
        await batch.commit();
        final fraction = end / writes.length;
        onProgress?.call(
          0.1 + (fraction * 0.86),
          'جاري رفع البوكسات... ${(fraction * 100).round()}٪',
        );
      }

      await importRef.update({
        'status': storageWarning == null ? 'completed' : 'completed_with_warning',
        'storagePath': storagePath,
        'storageWarning': storageWarning,
        'completedAt': FieldValue.serverTimestamp(),
      });
      onProgress?.call(1, 'اكتمل الاستيراد');

      return ImportResult(
        cabinetCount: preview.cabinetCount,
        boxCount: preview.boxCount,
        storagePath: storagePath,
        storageWarning: storageWarning,
      );
    } catch (error) {
      await importRef.update({
        'status': 'failed',
        'error': error.toString(),
        'completedAt': FieldValue.serverTimestamp(),
      });
      rethrow;
    }
  }

  static Object? _valueAt(List<excel.Data?> row, int index) {
    if (index >= row.length) return null;
    final value = row[index]?.value;
    if (value == null) return null;
    if (value is excel.TextCellValue) return value.value;
    if (value is excel.IntCellValue) return value.value;
    if (value is excel.DoubleCellValue) return value.value;
    if (value is excel.BoolCellValue) return value.value;
    if (value is excel.FormulaCellValue) return value.formula;
    return value.toString();
  }

  static void _validate(ImportPreview preview) {
    if (preview.cabinets.isEmpty || preview.boxCount == 0) {
      throw const FormatException(
        'لم يتم العثور على كبائن وبوكسات صالحة في الملف.',
      );
    }
    final duplicateCodes = <String>{};
    final seenCodes = <String>{};
    for (final cabinet in preview.cabinets) {
      if (!seenCodes.add(cabinet.code)) duplicateCodes.add(cabinet.code);
    }
    if (duplicateCodes.isNotEmpty) {
      throw FormatException(
        'أسماء كبائن مكررة: ${duplicateCodes.join(', ')}',
      );
    }
  }
}
