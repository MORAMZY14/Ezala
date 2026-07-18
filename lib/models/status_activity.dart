import 'package:cloud_firestore/cloud_firestore.dart';

import 'cabinet_box.dart';

enum StatusActivityType {
  requestCreated('request_created'),
  requestApproved('request_approved'),
  requestRejected('request_rejected');

  const StatusActivityType(this.value);

  final String value;

  static StatusActivityType fromValue(Object? value) {
    return switch (value) {
      'request_approved' => requestApproved,
      'request_rejected' => requestRejected,
      _ => requestCreated,
    };
  }
}

class StatusActivity {
  const StatusActivity({
    required this.id,
    required this.type,
    required this.cabinetCode,
    required this.boxNumber,
    required this.previousStatus,
    required this.targetStatus,
    required this.requestedByName,
    required this.actorName,
    required this.createdAt,
  });

  final String id;
  final StatusActivityType type;
  final String cabinetCode;
  final String boxNumber;
  final BoxStatus previousStatus;
  final BoxStatus targetStatus;
  final String requestedByName;
  final String actorName;
  final DateTime? createdAt;

  String get boxLabel => 'بوكس $boxNumber';

  factory StatusActivity.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StatusActivity(
      id: doc.id,
      type: StatusActivityType.fromValue(data['eventType']),
      cabinetCode: (data['cabinetCode'] as String?) ?? '',
      boxNumber: (data['boxNumber'] as String?) ?? '',
      previousStatus: BoxStatus.fromValue(data['previousStatus']),
      targetStatus: BoxStatus.fromValue(data['targetStatus']),
      requestedByName: (data['requestedByName'] as String?) ?? 'مستخدم',
      actorName: (data['actorName'] as String?) ?? 'مستخدم',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
