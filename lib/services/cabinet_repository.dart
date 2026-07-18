import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cabinet.dart';
import '../models/cabinet_box.dart';

class CabinetRepository {
  CabinetRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

}
