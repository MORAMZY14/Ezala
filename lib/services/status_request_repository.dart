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
      final requests = snapshot.docs
          .map(StatusRequest.fromDoc)
          .toList();
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
      if (!boxSnapshot.exists) {
        throw const StatusRequestException('هذا البوكس لم يعد موجودًا.');
      }

      final requestSnapshot = await transaction.get(requestRef);
      if (requestSnapshot.exists &&
          requestSnapshot.data()?['state'] ==
              StatusRequestState.pending.value) {
        throw const StatusRequestException(
          'يوجد طلب معلق لهذا البوكس بالفعل.',
        );
      }

      final currentStatus =
          BoxStatus.fromValue(boxSnapshot.data()?['status']);
      if (currentStatus == targetStatus) {
        throw const StatusRequestException(
          'حالة البوكس محدثة بالفعل.',
        );
      }

      final requestData = <String, dynamic>{
        'cabinetId': cabinet.id,
        'cabinetCode': cabinet.code,
        'boxId': box.id,
        'boxNumber': box.boxNumber,
        'previousStatus': currentStatus.value,
        'targetStatus': targetStatus.value,
        'state': StatusRequestState.pending.value,
        'requestedByUid': profile.uid,
        'requestedByName': profile.name,
        'requestedByEmail': profile.email,
        'requestedAt': FieldValue.serverTimestamp(),
        'reviewedByUid': null,
        'reviewedByName': null,
        'reviewedAt': null,
      };

      transaction.set(requestRef, requestData);
      transaction.set(activityRef, {
        ...requestData,
        'requestId': requestId,
        'eventType': StatusActivityType.requestCreated.value,
        'actorUid': profile.uid,
        'actorName': profile.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
      final cabinetId = data['cabinetId'] as String;
      final boxId = data['boxId'] as String;
      final targetStatus = BoxStatus.fromValue(data['targetStatus']);
      final cabinetRef = _firestore.collection('cabinets').doc(cabinetId);
      final boxRef = cabinetRef.collection('boxes').doc(boxId);
      final boxSnapshot = await transaction.get(boxRef);
      if (!boxSnapshot.exists) {
        throw const StatusRequestException('هذا البوكس لم يعد موجودًا.');
      }

      final currentStatus =
          BoxStatus.fromValue(boxSnapshot.data()?['status']);
      if (currentStatus != targetStatus) {
        final confirmDelta = targetStatus == BoxStatus.confirmed ? 1 : -1;
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

      transaction.update(requestRef, {
        'state': StatusRequestState.approved.value,
        'reviewedByUid': admin.uid,
        'reviewedByName': admin.name,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        ...data,
        'requestId': request.id,
        'eventType': StatusActivityType.requestApproved.value,
        'actorUid': admin.uid,
        'actorName': admin.name,
        'previousStatus': currentStatus.value,
        'targetStatus': targetStatus.value,
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
      transaction.update(requestRef, {
        'state': StatusRequestState.rejected.value,
        'reviewedByUid': admin.uid,
        'reviewedByName': admin.name,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        ...data,
        'requestId': request.id,
        'eventType': StatusActivityType.requestRejected.value,
        'actorUid': admin.uid,
        'actorName': admin.name,
        'state': StatusRequestState.rejected.value,
        'reviewedByUid': admin.uid,
        'reviewedByName': admin.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
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
