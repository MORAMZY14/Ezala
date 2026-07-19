import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_profile.dart';
import '../models/cabinet.dart';
import '../models/cabinet_box.dart';
import '../models/status_activity.dart';
import '../models/status_request.dart';

class StatusRequestException implements Exception {
  const StatusRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StatusRequestRepository {
  StatusRequestRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('statusRequests');

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('statusActivities');

  Stream<List<StatusRequest>> watchRequestsForCabinet(String cabinetId) {
    return _requests
        .where('cabinetId', isEqualTo: cabinetId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map(StatusRequest.fromDoc).toList();
      requests.sort(_sortRequestsNewestFirst);
      return requests;
    });
  }

  Stream<List<StatusRequest>> watchPendingRequests() {
    return _requests
        .where('state', isEqualTo: StatusRequestState.pending.value)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map(StatusRequest.fromDoc).toList();
      requests.sort(_sortRequestsNewestFirst);
      return requests;
    });
  }

  Stream<int> watchPendingRequestCount() {
    return watchPendingRequests().map((requests) => requests.length);
  }

  Stream<List<StatusActivity>> watchActivities({int limit = 200}) {
    return _activities
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(StatusActivity.fromDoc).toList(),
        );
  }

  Future<void> submitRequest({
    required Cabinet cabinet,
    required CabinetBox box,
    required BoxStatus targetStatus,
  }) async {
    if (box.status == targetStatus) return;

    final profile = await _currentProfile();
    final requestId = '${cabinet.id}__${box.id}'.replaceAll('/', '_');
    final requestRef = _requests.doc(requestId);
    final activityRef = _activities.doc();
    final boxRef = _firestore
        .collection('cabinets')
        .doc(cabinet.id)
        .collection('boxes')
        .doc(box.id);

    await _firestore.runTransaction((transaction) async {
      final boxSnapshot = await transaction.get(boxRef);
      final requestSnapshot = await transaction.get(requestRef);

      if (!boxSnapshot.exists) {
        throw const StatusRequestException('هذا البوكس لم يعد موجودًا.');
      }
      if (_isPendingSnapshot(requestSnapshot)) {
        throw const StatusRequestException(
          'يوجد طلب معلق لتغيير حالة هذا البوكس بالفعل.',
        );
      }

      final data = boxSnapshot.data()!;
      final currentStatus = BoxStatus.fromValue(data['status']);
      final currentLocation = BoxLocation.fromValue(data['location']);
      if (currentStatus == targetStatus) {
        throw const StatusRequestException('حالة البوكس محدثة بالفعل.');
      }

      final requestData = _requestData(
        kind: StatusRequestKind.statusChange,
        cabinet: cabinet,
        boxId: box.id,
        boxNumber: box.boxNumber,
        displayName: box.displayName,
        note: box.note,
        previousStatus: currentStatus,
        targetStatus: targetStatus,
        previousLocation: currentLocation,
        targetLocation: currentLocation,
        profile: profile,
      );
      _writeNewRequest(
        transaction: transaction,
        requestRef: requestRef,
        activityRef: activityRef,
        requestId: requestId,
        requestData: requestData,
        profile: profile,
      );
    });
  }

  Future<void> submitLocationRequest({
    required Cabinet cabinet,
    required CabinetBox box,
    required BoxLocation targetLocation,
  }) async {
    if (box.location == targetLocation) return;

    final profile = await _currentProfile();
    final requestId =
        '${cabinet.id}__${box.id}__location'.replaceAll('/', '_');
    final requestRef = _requests.doc(requestId);
    final activityRef = _activities.doc();
    final boxRef = _firestore
        .collection('cabinets')
        .doc(cabinet.id)
        .collection('boxes')
        .doc(box.id);

    await _firestore.runTransaction((transaction) async {
      final boxSnapshot = await transaction.get(boxRef);
      final requestSnapshot = await transaction.get(requestRef);

      if (!boxSnapshot.exists) {
        throw const StatusRequestException('هذا البوكس لم يعد موجودًا.');
      }
      if (_isPendingSnapshot(requestSnapshot)) {
        throw const StatusRequestException(
          'يوجد طلب معلق لتغيير نوع هذا البوكس بالفعل.',
        );
      }

      final data = boxSnapshot.data()!;
      final currentStatus = BoxStatus.fromValue(data['status']);
      final currentLocation = BoxLocation.fromValue(data['location']);
      if (currentLocation == targetLocation) {
        throw const StatusRequestException('نوع البوكس محدث بالفعل.');
      }

      final requestData = _requestData(
        kind: StatusRequestKind.locationChange,
        cabinet: cabinet,
        boxId: box.id,
        boxNumber: box.boxNumber,
        displayName: box.displayName,
        note: box.note,
        previousStatus: currentStatus,
        targetStatus: currentStatus,
        previousLocation: currentLocation,
        targetLocation: targetLocation,
        profile: profile,
      );
      _writeNewRequest(
        transaction: transaction,
        requestRef: requestRef,
        activityRef: activityRef,
        requestId: requestId,
        requestData: requestData,
        profile: profile,
      );
    });
  }

  Future<void> submitAddBoxRequest({
    required Cabinet cabinet,
    required String boxNumber,
    required BoxLocation location,
    String? displayName,
    String? note,
  }) async {
    final normalizedNumber = _clean(boxNumber).toUpperCase();
    if (normalizedNumber.isEmpty) {
      throw const StatusRequestException('أدخل رقم البوكس أولًا.');
    }

    final normalizedName = _clean(displayName);
    final normalizedNote = _clean(note);
    final boxId = _manualBoxId(normalizedNumber);
    final profile = await _currentProfile();
    final requestId =
        '${cabinet.id}__${boxId}__add'.replaceAll('/', '_');
    final cabinetRef = _firestore.collection('cabinets').doc(cabinet.id);
    final boxRef = cabinetRef.collection('boxes').doc(boxId);
    final requestRef = _requests.doc(requestId);
    final activityRef = _activities.doc();

    await _firestore.runTransaction((transaction) async {
      final cabinetSnapshot = await transaction.get(cabinetRef);
      final boxSnapshot = await transaction.get(boxRef);
      final requestSnapshot = await transaction.get(requestRef);

      if (!cabinetSnapshot.exists) {
        throw const StatusRequestException('هذه الكابينة لم تعد موجودة.');
      }
      if (boxSnapshot.exists) {
        throw const StatusRequestException(
          'يوجد بوكس بهذا الرقم داخل الكابينة بالفعل.',
        );
      }
      if (_isPendingSnapshot(requestSnapshot)) {
        throw const StatusRequestException(
          'يوجد طلب إضافة معلق لهذا البوكس بالفعل.',
        );
      }

      final requestData = _requestData(
        kind: StatusRequestKind.addBox,
        cabinet: cabinet,
        boxId: boxId,
        boxNumber: normalizedNumber,
        displayName: normalizedName.isEmpty
            ? 'BOX $normalizedNumber'
            : normalizedName,
        note: normalizedNote.isEmpty ? null : normalizedNote,
        previousStatus: BoxStatus.pending,
        targetStatus: BoxStatus.pending,
        previousLocation: location,
        targetLocation: location,
        profile: profile,
      );
      _writeNewRequest(
        transaction: transaction,
        requestRef: requestRef,
        activityRef: activityRef,
        requestId: requestId,
        requestData: requestData,
        profile: profile,
      );
    });
  }

  Future<void> approveRequest(StatusRequest request) async {
    final admin = await _currentAdmin();
    final requestRef = _requests.doc(request.id);
    final activityRef = _activities.doc();

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists ||
          requestSnapshot.data()?['state'] !=
              StatusRequestState.pending.value) {
        throw const StatusRequestException(
          'تمت مراجعة هذا الطلب بالفعل.',
        );
      }

      final data = requestSnapshot.data()!;
      final kind = StatusRequestKind.fromValue(data['requestKind']);
      final cabinetId = data['cabinetId'] as String;
      final boxId = data['boxId'] as String;
      final cabinetRef = _firestore.collection('cabinets').doc(cabinetId);
      final boxRef = cabinetRef.collection('boxes').doc(boxId);
      final cabinetSnapshot = await transaction.get(cabinetRef);
      final boxSnapshot = await transaction.get(boxRef);

      if (!cabinetSnapshot.exists) {
        throw const StatusRequestException('هذه الكابينة لم تعد موجودة.');
      }

      var previousStatus = BoxStatus.fromValue(data['previousStatus']);
      var targetStatus = BoxStatus.fromValue(data['targetStatus']);
      var previousLocation =
          BoxLocation.fromValue(data['previousLocation']);
      var targetLocation = BoxLocation.fromValue(data['targetLocation']);

      switch (kind) {
        case StatusRequestKind.statusChange:
          if (!boxSnapshot.exists) {
            throw const StatusRequestException('هذا البوكس لم يعد موجودًا.');
          }
          previousStatus = BoxStatus.fromValue(boxSnapshot.data()?['status']);
          previousLocation =
              BoxLocation.fromValue(boxSnapshot.data()?['location']);
          targetLocation = previousLocation;

          if (previousStatus != targetStatus) {
            final confirmDelta =
                targetStatus == BoxStatus.confirmed ? 1 : -1;
            transaction.update(boxRef, {
              'status': targetStatus.value,
              'statusLabel': targetStatus.label,
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': admin.uid,
              'updatedByName': admin.name,
              'requestedBy': data['requestedByUid'],
              'requestedByName': data['requestedByName'],
            });
            transaction.update(cabinetRef, {
              'confirmedCount': FieldValue.increment(confirmDelta),
              'pendingCount': FieldValue.increment(-confirmDelta),
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': admin.uid,
              'updatedByName': admin.name,
            });
          }
          break;

        case StatusRequestKind.locationChange:
          if (!boxSnapshot.exists) {
            throw const StatusRequestException('هذا البوكس لم يعد موجودًا.');
          }
          previousStatus = BoxStatus.fromValue(boxSnapshot.data()?['status']);
          targetStatus = previousStatus;
          previousLocation =
              BoxLocation.fromValue(boxSnapshot.data()?['location']);

          if (previousLocation != targetLocation) {
            transaction.update(boxRef, {
              'location': targetLocation.value,
              'locationLabel': targetLocation.label,
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': admin.uid,
              'updatedByName': admin.name,
              'requestedBy': data['requestedByUid'],
              'requestedByName': data['requestedByName'],
            });
            transaction.update(cabinetRef, {
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': admin.uid,
              'updatedByName': admin.name,
            });
          }
          break;

        case StatusRequestKind.addBox:
          if (boxSnapshot.exists) {
            throw const StatusRequestException(
              'تمت إضافة بوكس بهذا الرقم بالفعل.',
            );
          }
          previousStatus = BoxStatus.pending;
          targetStatus = BoxStatus.pending;
          previousLocation = targetLocation;
          final cabinetData = cabinetSnapshot.data()!;
          final nextSortIndex =
              (cabinetData['boxCount'] as num?)?.toInt() ?? 0;

          transaction.set(boxRef, {
            'cabinetCode': data['cabinetCode'],
            'boxNumber': data['boxNumber'],
            'displayName': data['displayName'],
            'location': targetLocation.value,
            'locationLabel': targetLocation.label,
            'status': BoxStatus.pending.value,
            'statusLabel': BoxStatus.pending.label,
            'note': data['note'],
            'sortIndex': nextSortIndex + 1,
            'sourceRow': null,
            'source': 'manual_request',
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': data['requestedByUid'],
            'createdByName': data['requestedByName'],
            'approvedBy': admin.uid,
            'approvedByName': admin.name,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': admin.uid,
            'updatedByName': admin.name,
          });
          transaction.update(cabinetRef, {
            'boxCount': FieldValue.increment(1),
            'pendingCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': admin.uid,
            'updatedByName': admin.name,
          });
          break;
      }

      transaction.update(requestRef, {
        'state': StatusRequestState.approved.value,
        'reviewedByUid': admin.uid,
        'reviewedByName': admin.name,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        ...data,
        'requestId': request.id,
        'requestKind': kind.value,
        'eventType': StatusActivityType.requestApproved.value,
        'actorUid': admin.uid,
        'actorName': admin.name,
        'previousStatus': previousStatus.value,
        'targetStatus': targetStatus.value,
        'previousLocation': previousLocation.value,
        'targetLocation': targetLocation.value,
        'state': StatusRequestState.approved.value,
        'reviewedByUid': admin.uid,
        'reviewedByName': admin.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectRequest(StatusRequest request) async {
    final admin = await _currentAdmin();
    final requestRef = _requests.doc(request.id);
    final activityRef = _activities.doc();

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists ||
          requestSnapshot.data()?['state'] !=
              StatusRequestState.pending.value) {
        throw const StatusRequestException(
          'تمت مراجعة هذا الطلب بالفعل.',
        );
      }

      final data = requestSnapshot.data()!;
      final kind = StatusRequestKind.fromValue(data['requestKind']);
      transaction.update(requestRef, {
        'state': StatusRequestState.rejected.value,
        'reviewedByUid': admin.uid,
        'reviewedByName': admin.name,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        ...data,
        'requestId': request.id,
        'requestKind': kind.value,
        'eventType': StatusActivityType.requestRejected.value,
        'actorUid': admin.uid,
        'actorName': admin.name,
        'previousStatus':
            BoxStatus.fromValue(data['previousStatus']).value,
        'targetStatus': BoxStatus.fromValue(data['targetStatus']).value,
        'previousLocation':
            BoxLocation.fromValue(data['previousLocation']).value,
        'targetLocation':
            BoxLocation.fromValue(data['targetLocation']).value,
        'state': StatusRequestState.rejected.value,
        'reviewedByUid': admin.uid,
        'reviewedByName': admin.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Map<String, dynamic> _requestData({
    required StatusRequestKind kind,
    required Cabinet cabinet,
    required String boxId,
    required String boxNumber,
    required String displayName,
    required String? note,
    required BoxStatus previousStatus,
    required BoxStatus targetStatus,
    required BoxLocation previousLocation,
    required BoxLocation targetLocation,
    required AppUserProfile profile,
  }) {
    return <String, dynamic>{
      'requestKind': kind.value,
      'cabinetId': cabinet.id,
      'cabinetCode': cabinet.code,
      'boxId': boxId,
      'boxNumber': boxNumber,
      'displayName': displayName,
      'note': note,
      'previousStatus': previousStatus.value,
      'targetStatus': targetStatus.value,
      'previousLocation': previousLocation.value,
      'targetLocation': targetLocation.value,
      'state': StatusRequestState.pending.value,
      'requestedByUid': profile.uid,
      'requestedByName': profile.name,
      'requestedByEmail': profile.email,
      'requestedAt': FieldValue.serverTimestamp(),
      'reviewedByUid': null,
      'reviewedByName': null,
      'reviewedAt': null,
    };
  }

  static void _writeNewRequest({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> requestRef,
    required DocumentReference<Map<String, dynamic>> activityRef,
    required String requestId,
    required Map<String, dynamic> requestData,
    required AppUserProfile profile,
  }) {
    transaction.set(requestRef, requestData);
    transaction.set(activityRef, {
      ...requestData,
      'requestId': requestId,
      'eventType': StatusActivityType.requestCreated.value,
      'actorUid': profile.uid,
      'actorName': profile.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static bool _isPendingSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.exists &&
        snapshot.data()?['state'] == StatusRequestState.pending.value;
  }

  static String _clean(Object? value) {
    return (value ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _manualBoxId(String value) {
    final safe = value
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_-]'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (safe.isNotEmpty) return safe;
    final encoded = value.runes.map((rune) => rune.toRadixString(16)).join('-');
    return 'box-$encoded';
  }

  Future<AppUserProfile> _currentProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication required');
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    return AppUserProfile.fromDoc(snapshot, user);
  }

  Future<AppUserProfile> _currentAdmin() async {
    final profile = await _currentProfile();
    if (!profile.isAdmin) {
      throw const StatusRequestException(
        'هذه العملية متاحة للمسؤولين فقط.',
      );
    }
    return profile;
  }

  static int _sortRequestsNewestFirst(
    StatusRequest first,
    StatusRequest second,
  ) {
    final firstDate = first.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final secondDate =
        second.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return secondDate.compareTo(firstDate);
  }
}
