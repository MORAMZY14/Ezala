import 'package:cloud_firestore/cloud_firestore.dart';

import 'cabinet_box.dart';

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
    required this.cabinetId,
    required this.cabinetCode,
    required this.boxId,
    required this.boxNumber,
    required this.previousStatus,
    required this.targetStatus,
    required this.state,
    required this.requestedByUid,
    required this.requestedByName,
    required this.requestedAt,
    this.reviewedByUid,
    this.reviewedByName,
    this.reviewedAt,
  });

  final String id;
  final String cabinetId;
  final String cabinetCode;
  final String boxId;
  final String boxNumber;
  final BoxStatus previousStatus;
  final BoxStatus targetStatus;
  final StatusRequestState state;
  final String requestedByUid;
  final String requestedByName;
  final DateTime? requestedAt;
  final String? reviewedByUid;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  bool get isPending => state == StatusRequestState.pending;
  String get boxLabel => 'بوكس $boxNumber';

  factory StatusRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StatusRequest(
      id: doc.id,
      cabinetId: (data['cabinetId'] as String?) ?? '',
      cabinetCode: (data['cabinetCode'] as String?) ?? '',
      boxId: (data['boxId'] as String?) ?? '',
      boxNumber: (data['boxNumber'] as String?) ?? '',
      previousStatus: BoxStatus.fromValue(data['previousStatus']),
      targetStatus: BoxStatus.fromValue(data['targetStatus']),
      state: StatusRequestState.fromValue(data['state']),
      requestedByUid: (data['requestedByUid'] as String?) ?? '',
      requestedByName: (data['requestedByName'] as String?) ?? 'مستخدم',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      reviewedByUid: data['reviewedByUid'] as String?,
      reviewedByName: data['reviewedByName'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }
}
