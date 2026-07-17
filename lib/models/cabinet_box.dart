import 'package:cloud_firestore/cloud_firestore.dart';

enum BoxStatus {
  pending('pending', 'قيد الانتظار'),
  confirmed('confirmed', 'مؤكد');

  const BoxStatus(this.value, this.label);

  final String value;
  final String label;

  static BoxStatus fromValue(Object? value) {
    return value == confirmed.value ? confirmed : pending;
  }
}

enum BoxLocation {
  internal('internal', 'داخلي'),
  external('external', 'خارجي');

  const BoxLocation(this.value, this.label);

  final String value;
  final String label;

  static BoxLocation fromValue(Object? value) {
    return value == external.value ? external : internal;
  }
}

class CabinetBox {
  const CabinetBox({
    required this.id,
    required this.cabinetCode,
    required this.boxNumber,
    required this.displayName,
    required this.location,
    required this.status,
    required this.sortIndex,
    this.note,
  });

  final String id;
  final String cabinetCode;
  final String boxNumber;
  final String displayName;
  final BoxLocation location;
  final BoxStatus status;
  final int sortIndex;
  final String? note;

  factory CabinetBox.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CabinetBox(
      id: doc.id,
      cabinetCode: (data['cabinetCode'] as String?) ?? '',
      boxNumber: (data['boxNumber'] as String?) ?? doc.id.toUpperCase(),
      displayName:
          (data['displayName'] as String?) ?? 'BOX ${doc.id.toUpperCase()}',
      location: BoxLocation.fromValue(data['location']),
      status: BoxStatus.fromValue(data['status']),
      sortIndex: (data['sortIndex'] as num?)?.toInt() ?? 0,
      note: data['note'] as String?,
    );
  }
}
