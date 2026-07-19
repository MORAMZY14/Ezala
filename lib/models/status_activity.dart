import 'package:cloud_firestore/cloud_firestore.dart';

import 'cabinet_box.dart';
import 'status_request.dart';

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
    required this.kind,
    required this.cabinetCode,
    required this.boxNumber,
    required this.previousStatus,
    required this.targetStatus,
    required this.previousLocation,
    required this.targetLocation,
    required this.requestedByName,
    required this.actorName,
    required this.createdAt,
  });

  final String id;
  final StatusActivityType type;
  final StatusRequestKind kind;
  final String cabinetCode;
  final String boxNumber;
  final BoxStatus previousStatus;
  final BoxStatus targetStatus;
  final BoxLocation previousLocation;
  final BoxLocation targetLocation;
  final String requestedByName;
  final String actorName;
  final DateTime? createdAt;

  String get boxLabel => 'بوكس $boxNumber';

  String get actionSummary {
    return switch (kind) {
      StatusRequestKind.statusChange =>
        'تغيير حالة $boxLabel من ${previousStatus.label} إلى '
            '${targetStatus.label}',
      StatusRequestKind.locationChange =>
        'تحويل $boxLabel من ${previousLocation.label} إلى '
            '${targetLocation.label}',
      StatusRequestKind.addBox =>
        'إضافة $boxLabel بنوع ${targetLocation.label}',
    };
  }

  factory StatusActivity.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StatusActivity(
      id: doc.id,
      type: StatusActivityType.fromValue(data['eventType']),
      kind: StatusRequestKind.fromValue(data['requestKind']),
      cabinetCode: (data['cabinetCode'] as String?) ?? '',
      boxNumber: (data['boxNumber'] as String?) ?? '',
      previousStatus: BoxStatus.fromValue(data['previousStatus']),
      targetStatus: BoxStatus.fromValue(data['targetStatus']),
      previousLocation: BoxLocation.fromValue(data['previousLocation']),
      targetLocation: BoxLocation.fromValue(data['targetLocation']),
      requestedByName: (data['requestedByName'] as String?) ?? 'مستخدم',
      actorName: (data['actorName'] as String?) ?? 'مستخدم',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
