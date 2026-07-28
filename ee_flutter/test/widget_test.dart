import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/main.dart';
import 'package:eficiencia_energetica_ee/services/app_update_service.dart';
import 'package:eficiencia_energetica_ee/services/cloudinary_service.dart';
import 'package:eficiencia_energetica_ee/services/consumption_store.dart';
import 'package:eficiencia_energetica_ee/services/operator_session.dart';
import 'package:eficiencia_energetica_ee/services/report_store.dart';

void main() {
  testWidgets('shows EE home modules', (WidgetTester tester) async {
    await tester.pumpWidget(
      EeApp(
        reportStore: LocalReportStore(),
        consumptionStore: LocalConsumptionStore(),
        cloudinaryService: CloudinaryService(),
        updateService: const AppUpdateService.disabled(),
        operatorSession: const _NamedUserSession(),
      ),
    );
    await tester.pump();

    expect(find.text('Eficiencia Energetica EE'), findsOneWidget);
    expect(find.text('Jefferson Ordonez'), findsOneWidget);
    expect(find.text('Dimensionamiento de trampas'), findsOneWidget);
    expect(find.text('Reporte de tuberia desnuda'), findsOneWidget);
    expect(find.text('Ingresar consumos'), findsOneWidget);
    expect(find.text('Registros'), findsOneWidget);
    expect(find.text('Panel administrador'), findsOneWidget);

    final moduleLabels = tester
        .widgetList<EeActionButton>(find.byType(EeActionButton))
        .map((button) => button.label)
        .toList();
    expect(moduleLabels.first, 'Ingresar consumos');
    expect(moduleLabels[moduleLabels.length - 2], 'Seguimiento de reportes');
  });
}

class _NamedUserSession implements OperatorSession {
  const _NamedUserSession();

  @override
  Future<AuthenticatedOperator?> currentOperator() async {
    return const AuthenticatedOperator(
      uid: 'user-1',
      displayName: 'Jefferson Ordonez',
      role: 'operator',
    );
  }
}
