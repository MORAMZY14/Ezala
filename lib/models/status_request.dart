import 'package:cloud_firestore/cloud_firestore.dart';

import 'cabinet_box.dart';

enum StatusRequestKind {
  statusChange('status_change', 'تغيير الحالة'),
  locationChange('location_change', 'تغيير النوع'),
  addBox('add_box', 'إضافة بوكس');

  const StatusRequestKind(this.value, this.label);

  final String value;
  final String label;

  static StatusRequestKind fromValue(Object? value) {
    return switch (value) {
      'location_change' => locationChange,
      'add_box' => addBox,
      _ => statusChange,
    };
  }
}

enum StatusRequestState {
  pending('pending', 'بانتظار الموافقة'),
  approved('approved', 'تمت الموافقة'),
  rejected('rejected', 'مرفوض');

  const StatusRequestState(this.value, this.label);

  final String value;
  final String label;

  static StatusRequestState fromValue(Object? value) {
    return switch (value) {
      'approved' => approved,
      'rejected' => rejected,
      _ => pending,
    };
  }
}

class StatusRequest {
  const StatusRequest({
    required this.id,
    required this.kind,
    required this.cabinetId,
    required this.cabinetCode,
    required this.boxId,
    required this.boxNumber,
    required this.displayName,
    required this.previousStatus,
    required this.targetStatus,
    required this.previousLocation,
    required this.targetLocation,
    required this.state,
    required this.requestedByUid,
    required this.requestedByName,
    required this.requestedAt,
    this.note,
    this.reviewedByUid,
    this.reviewedByName,
    this.reviewedAt,
  });

  final String id;
  final StatusRequestKind kind;
  final String cabinetId;
  final String cabinetCode;
  final String boxId;
  final String boxNumber;
  final String displayName;
  final BoxStatus previousStatus;
  final BoxStatus targetStatus;
  final BoxLocation previousLocation;
  final BoxLocation targetLocation;
  final StatusRequestState state;
  final String requestedByUid;
  final String requestedByName;
  final DateTime? requestedAt;
  final String? note;
  final String? reviewedByUid;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  bool get isPending => state == StatusRequestState.pending;
  bool get isStatusChange => kind == StatusRequestKind.statusChange;
  bool get isLocationChange => kind == StatusRequestKind.locationChange;
  bool get isAddBox => kind == StatusRequestKind.addBox;
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

  factory StatusRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final boxNumber = (data['boxNumber'] as String?) ?? '';
    return StatusRequest(
      id: doc.id,
      kind: StatusRequestKind.fromValue(data['requestKind']),
      cabinetId: (data['cabinetId'] as String?) ?? '',
      cabinetCode: (data['cabinetCode'] as String?) ?? '',
      boxId: (data['boxId'] as String?) ?? '',
      boxNumber: boxNumber,
      displayName:
          (data['displayName'] as String?) ?? 'BOX $boxNumber',
      previousStatus: BoxStatus.fromValue(data['previousStatus']),
      targetStatus: BoxStatus.fromValue(data['targetStatus']),
      previousLocation: BoxLocation.fromValue(data['previousLocation']),
      targetLocation: BoxLocation.fromValue(data['targetLocation']),
      state: StatusRequestState.fromValue(data['state']),
      requestedByUid: (data['requestedByUid'] as String?) ?? '',
      requestedByName: (data['requestedByName'] as String?) ?? 'مستخدم',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      note: data['note'] as String?,
      reviewedByUid: data['reviewedByUid'] as String?,
      reviewedByName: data['reviewedByName'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }
}
