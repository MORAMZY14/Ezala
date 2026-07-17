import 'package:cloud_firestore/cloud_firestore.dart';

class Cabinet {
  const Cabinet({
    required this.id,
    required this.code,
    required this.sortIndex,
    required this.boxCount,
    required this.confirmedCount,
    required this.pendingCount,
  });

  final String id;
  final String code;
  final int sortIndex;
  final int boxCount;
  final int confirmedCount;
  final int pendingCount;

  double get progress => boxCount == 0 ? 0 : confirmedCount / boxCount;
  bool get isComplete => boxCount > 0 && confirmedCount == boxCount;

  factory Cabinet.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Cabinet(
      id: doc.id,
      code: (data['code'] as String?) ?? doc.id.toUpperCase(),
      sortIndex: (data['sortIndex'] as num?)?.toInt() ?? 0,
      boxCount: (data['boxCount'] as num?)?.toInt() ?? 0,
      confirmedCount: (data['confirmedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (data['pendingCount'] as num?)?.toInt() ?? 0,
    );
  }
}
