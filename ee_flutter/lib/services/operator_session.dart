import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthenticatedOperator {
  const AuthenticatedOperator({
    required this.uid,
    required this.displayName,
    required this.role,
  });

  final String uid;
  final String displayName;
  final String role;
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
    var role = 'operator';
    try {
      final profile = await (_firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      final data = profile.data();
      final storedName = (data?['displayName'] as String? ?? '').trim();
      final storedRole = (data?['role'] as String? ?? '').trim();
      if (storedName.isNotEmpty) {
        displayName = storedName;
      }
      if (storedRole == 'admin' || storedRole == 'operator') {
        role = storedRole;
      }
    } catch (_) {
      // Auth remains the source of identity when the profile is unavailable.
    }

    return AuthenticatedOperator(
      uid: user.uid,
      displayName: displayName,
      role: role,
    );
  }
}
