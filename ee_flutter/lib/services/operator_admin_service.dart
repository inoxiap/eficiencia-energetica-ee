import 'package:cloud_firestore/cloud_firestore.dart';

class OperatorAdminUser {
  const OperatorAdminUser({
    required this.uid,
    required this.displayName,
    required this.nationalId,
    required this.role,
    required this.active,
    required this.maintenanceZoneNumbers,
  });

  final String uid;
  final String displayName;
  final String nationalId;
  final String role;
  final bool active;
  final List<int> maintenanceZoneNumbers;

  factory OperatorAdminUser.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final zones =
        (data['maintenanceZoneNumbers'] as List? ?? const [])
            .whereType<num>()
            .map((zone) => zone.toInt())
            .toSet()
            .toList()
          ..sort();
    return OperatorAdminUser(
      uid: snapshot.id,
      displayName: (data['displayName'] as String? ?? '').trim(),
      nationalId: (data['nationalId'] as String? ?? '').trim(),
      role: (data['role'] as String? ?? 'unprovisioned').trim(),
      active: data['active'] != false,
      maintenanceZoneNumbers: zones,
    );
  }
}

abstract class OperatorAdminService {
  Future<List<OperatorAdminUser>> listUsers();

  Future<void> deactivateUser({required String uid, required String adminUid});
}

class FirebaseOperatorAdminService implements OperatorAdminService {
  FirebaseOperatorAdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<OperatorAdminUser>> listUsers() async {
    final snapshot = await _firestore.collection('users').get();
    final users = snapshot.docs.map(OperatorAdminUser.fromSnapshot).toList();
    users.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return users;
  }

  @override
  Future<void> deactivateUser({
    required String uid,
    required String adminUid,
  }) async {
    if (uid == adminUid) {
      throw StateError('No puedes desactivar tu propio acceso.');
    }
    await _firestore.collection('users').doc(uid).update({
      'active': false,
      'status': 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': adminUid,
    });
  }
}
