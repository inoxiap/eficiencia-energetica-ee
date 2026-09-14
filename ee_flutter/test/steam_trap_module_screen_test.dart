import 'package:eficiencia_energetica_ee/main.dart';
import 'package:eficiencia_energetica_ee/services/cloudinary_service.dart';
import 'package:eficiencia_energetica_ee/services/operator_auth_service.dart';
import 'package:eficiencia_energetica_ee/services/operator_session.dart';
import 'package:eficiencia_energetica_ee/services/steam_trap_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session implements OperatorSession {
  @override
  Future<AuthenticatedOperator?> currentOperator() async =>
      const AuthenticatedOperator(
        uid: 'provider-1',
        displayName: 'Proveedor Uno',
        role: 'provider',
      );
}

void main() {
  testWidgets('module exposes exactly the two requested tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SteamTrapModuleScreen(
          store: const DisabledSteamTrapStore(),
          cloudinaryService: CloudinaryService(),
          operatorSession: _Session(),
          operatorAuthService: const DisabledOperatorAuthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('Ingresar trampa'), findsOneWidget);
    expect(find.text('Consulta'), findsOneWidget);
    expect(find.text('1. Evidencia fotografica'), findsOneWidget);
  });
}
