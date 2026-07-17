import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cabinet.dart';
import '../models/cabinet_box.dart';

class CabinetRepository {
  CabinetRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<Cabinet>> watchCabinets() {
    return _firestore
        .collection('cabinets')
        .orderBy('sortIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Cabinet.fromDoc).toList());
  }

  Stream<List<CabinetBox>> watchBoxes(String cabinetId) {
    return _firestore
        .collection('cabinets')
        .doc(cabinetId)
        .collection('boxes')
        .orderBy('sortIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CabinetBox.fromDoc).toList());
  }

  Future<void> updateStatus({
    required Cabinet cabinet,
    required CabinetBox box,
    required BoxStatus newStatus,
  }) async {
    if (box.status == newStatus) return;

    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication required');

    final cabinetRef = _firestore.collection('cabinets').doc(cabinet.id);
    final boxRef = cabinetRef.collection('boxes').doc(box.id);

    await _firestore.runTransaction((transaction) async {
      final freshBox = await transaction.get(boxRef);
      if (!freshBox.exists) throw StateError('Box no longer exists');

      final oldStatus = BoxStatus.fromValue(freshBox.data()?['status']);
      if (oldStatus == newStatus) return;

      final confirmDelta = newStatus == BoxStatus.confirmed ? 1 : -1;
      transaction.update(boxRef, {
        'status': newStatus.value,
        'statusLabel': newStatus.label,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'updatedByName': user.displayName ?? user.email ?? '',
      });
      transaction.update(cabinetRef, {
        'confirmedCount': FieldValue.increment(confirmDelta),
        'pendingCount': FieldValue.increment(-confirmDelta),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    });
  }
}
