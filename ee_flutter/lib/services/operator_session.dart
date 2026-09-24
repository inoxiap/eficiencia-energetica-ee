import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthenticatedOperator {
  const AuthenticatedOperator({
    required this.uid,
    required this.displayName,
    required this.role,
    this.companyId = '',
    this.companyName = '',
    this.active = true,
    this.credentialExpiresAt,
  });

  final String uid;
  final String displayName;
  final String role;
  final String companyId;
  final String companyName;
  final bool active;
  final DateTime? credentialExpiresAt;

  bool get providerAccessExpired => role == 'provider' &&
      (!active ||
          credentialExpiresAt == null ||
          !DateTime.now().isBefore(credentialExpiresAt!));
}

abstract class OperatorSession {
  Future<AuthenticatedOperator?> currentOperator();
}

class DisabledOperatorSession implements OperatorSession {
  const DisabledOperatorSession();

  @override
  Future<AuthenticatedOperator?> currentOperator() async => null;
}

class FirebaseOperatorSession implements OperatorSession {
  FirebaseOperatorSession({
    required Future<FirebaseApp> firebaseReady,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 12),
  }) : _firebaseReady = firebaseReady,
       _auth = auth,
       _firestore = firestore;

  final Future<FirebaseApp> _firebaseReady;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final Duration timeout;

  @override
  Future<AuthenticatedOperator?> currentOperator() async {
    await _firebaseReady.timeout(timeout);
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      return null;
    }

    var displayName = (user.displayName ?? user.email ?? 'Usuario').trim();
    var role = 'unprovisioned';
    var companyId = '';
    var companyName = '';
    var active = true;
    DateTime? credentialExpiresAt;
    try {
      final profile = await (_firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      final data = profile.data();
      final storedName = (data?['displayName'] as String? ?? '').trim();
      final storedRole = (data?['role'] as String? ?? '').trim();
      companyId = (data?['companyId'] as String? ?? '').trim();
      companyName = (data?['companyNameSnapshot'] as String? ?? '').trim();
      active = data?['active'] != false;
      final expiresAtValue = data?['credentialExpiresAt'];
      credentialExpiresAt = expiresAtValue is Timestamp
          ? expiresAtValue.toDate()
          : expiresAtValue is DateTime
          ? expiresAtValue
          : null;
      if (storedName.isNotEmpty) {
        displayName = storedName;
      }
      if (storedRole == 'admin' ||
          storedRole == 'operator' ||
          storedRole == 'provider') {
        role = storedRole;
      }
    } catch (_) {
      try {
        final claims = await user.getIdTokenResult().timeout(timeout);
        final claimedRole = claims.claims?['role'];
        if (claimedRole is String &&
            ['admin', 'operator', 'provider'].contains(claimedRole)) {
          role = claimedRole;
          companyId = claims.claims?['companyId'] as String? ?? '';
        }
      } catch (_) {}
    }

    return AuthenticatedOperator(
      uid: user.uid,
      displayName: displayName,
      role: role,
      companyId: companyId,
      companyName: companyName,
      active: active,
      credentialExpiresAt: credentialExpiresAt,
    );
  }
}
