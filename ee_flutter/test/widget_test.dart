import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/main.dart';
import 'package:eficiencia_energetica_ee/services/cloudinary_service.dart';
import 'package:eficiencia_energetica_ee/services/consumption_store.dart';
import 'package:eficiencia_energetica_ee/services/report_store.dart';

void main() {
  testWidgets('shows EE home modules', (WidgetTester tester) async {
    await tester.pumpWidget(
      EeApp(
        reportStore: LocalReportStore(),
        consumptionStore: LocalConsumptionStore(),
        cloudinaryService: CloudinaryService(),
      ),
    );

    expect(find.text('Eficiencia Energetica EE'), findsOneWidget);
    expect(find.text('Dimensionamiento de trampas'), findsOneWidget);
    expect(find.text('Reporte de tuberia desnuda'), findsOneWidget);
    expect(find.text('Ingresar consumos'), findsOneWidget);
    expect(find.text('Panel administrador'), findsOneWidget);
  });
}
