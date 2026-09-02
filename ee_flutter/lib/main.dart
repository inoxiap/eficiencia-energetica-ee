import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dial_knob/flutter_dial_knob.dart' as industrial_knob;
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart'
    as industrial_gauge;
import 'package:url_launcher/url_launcher.dart';
import 'package:segment_display/segment_display.dart' as segment_display;
import 'package:sleek_circular_slider/sleek_circular_slider.dart'
    as circular_instrument;

import 'domain/bare_pipe.dart';
import 'domain/boiler_consumption.dart';
import 'domain/destination_catalog.dart';
import 'domain/leak_report.dart';
import 'domain/maintenance_report.dart';
import 'domain/section_catalog.dart';
import 'domain/steam_pressure_reading.dart';
import 'domain/trap_sizing.dart';
import 'domain/trap_sizing_report.dart';
import 'firebase_options.dart';
import 'screens/pump_survey_screen.dart';
import 'services/app_update_service.dart';
import 'services/cloudinary_service.dart';
import 'services/consumption_store.dart';
import 'services/deferred_firestore_consumption_store.dart';
import 'services/deferred_firestore_report_store.dart';
import 'services/destination_catalog_loader.dart';
import 'services/firebase_auth_plugin_registration.dart';
import 'services/operator_session.dart';
import 'services/motor_reference_store.dart';
import 'services/maintenance_report_store.dart';
import 'services/operator_auth_service.dart';
import 'services/pressure_reading_store.dart';
import 'services/report_store.dart';
import 'services/pump_survey_store.dart';
import 'services/trap_sizing_report_store.dart';
import 'widgets/home_navigation_bar.dart';

part 'screens/leak_report_screen.dart';
part 'screens/maintenance_history_screen.dart';
part 'screens/boiler_readings_history_screen.dart';
part 'screens/pressure_entry_tab.dart';
part 'screens/input_controls_playground_screen.dart';

const brandRed = Color(0xffe3263a);
const brandRedDark = Color(0xffb8192a);
const pageColor = Color(0xfff5f7f8);
const textColor = Color(0xff20272b);
const mutedColor = Color(0xff5b6970);
const borderColor = Color(0xffdae2e5);
const tealColor = Color(0xff2f6f73);
const useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

Future<FirebaseApp> _initializeFirebase() async {
  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (useFirebaseEmulators) {
    final host = kIsWeb ? '127.0.0.1' : '10.0.2.2';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8081);
  }
  return app;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFirebaseAuthPlugin();
  final firebaseReady = _initializeFirebase();
  firebaseReady.ignore();
  final localStore = LocalReportStore();
  final localConsumptionStore = LocalConsumptionStore();
  final operatorSession = FirebaseOperatorSession(firebaseReady: firebaseReady);
  final operatorAuthService = FirebaseOperatorAuthService(
    firebaseReady: firebaseReady,
  );
  final maintenanceReportStore = FirebaseMaintenanceReportStore(
    firebaseReady: firebaseReady,
    operatorSession: operatorSession,
  );
  runApp(
    EeApp(
      reportStore: HybridReportStore(
        localStore: localStore,
        remoteStore: DeferredFirestoreReportStore(
          firebaseReady: firebaseReady,
          operatorSession: operatorSession,
        ),
      ),
      consumptionStore: HybridConsumptionStore(
        localStore: localConsumptionStore,
        remoteStore: DeferredFirestoreConsumptionStore(
          firebaseReady: firebaseReady,
          operatorSession: operatorSession,
        ),
        remoteTimeout: const Duration(seconds: 35),
      ),
      pressureReadingStore: FirebasePressureReadingStore(
        firebaseReady: firebaseReady,
        operatorSession: operatorSession,
      ),
      cloudinaryService: CloudinaryService(),
      trapSizingReportStore: FirebaseTrapSizingReportStore(
        firebaseReady: firebaseReady,
        operatorSession: operatorSession,
      ),
      operatorSession: operatorSession,
      operatorAuthService: operatorAuthService,
      pumpSurveyStore: FirebasePumpSurveyStore(
        firebaseReady: firebaseReady,
        operatorSession: operatorSession,
      ),
      motorReferenceStore: FirebaseMotorReferenceStore(
        firebaseReady: firebaseReady,
      ),
      maintenanceReportStore: maintenanceReportStore,
      updateService: AppUpdateService(firebaseReady: firebaseReady),
    ),
  );
}

class EeApp extends StatelessWidget {
  const EeApp({
    required this.reportStore,
    required this.consumptionStore,
    required this.cloudinaryService,
    required this.updateService,
    this.trapSizingReportStore = const DisabledTrapSizingReportStore(),
    this.operatorSession = const DisabledOperatorSession(),
    this.operatorAuthService = const DisabledOperatorAuthService(),
    this.pressureReadingStore = const DisabledPressureReadingStore(),
    this.pumpSurveyStore = const DisabledPumpSurveyStore(),
    this.motorReferenceStore = const DisabledMotorReferenceStore(),
    this.maintenanceReportStore = const DisabledMaintenanceReportStore(),
    super.key,
  });

  final ReportStore reportStore;
  final ConsumptionStore consumptionStore;
  final CloudinaryService cloudinaryService;
  final AppUpdateService updateService;
  final TrapSizingReportStore trapSizingReportStore;
  final OperatorSession operatorSession;
  final OperatorAuthService operatorAuthService;
  final PressureReadingStore pressureReadingStore;
  final PumpSurveyStore pumpSurveyStore;
  final MotorReferenceStore motorReferenceStore;
  final MaintenanceReportStore maintenanceReportStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eficiencia Energetica EE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandRed,
          primary: brandRed,
          surface: Colors.white,
        ),
        fontFamily: 'Arial',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: brandRed, width: 1.5),
          ),
        ),
      ),
      home: SplashGate(
        reportStore: reportStore,
        consumptionStore: consumptionStore,
        cloudinaryService: cloudinaryService,
        updateService: updateService,
        trapSizingReportStore: trapSizingReportStore,
        operatorSession: operatorSession,
        operatorAuthService: operatorAuthService,
        pressureReadingStore: pressureReadingStore,
        pumpSurveyStore: pumpSurveyStore,
        motorReferenceStore: motorReferenceStore,
        maintenanceReportStore: maintenanceReportStore,
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({
    required this.reportStore,
    required this.consumptionStore,
    required this.cloudinaryService,
    required this.updateService,
    required this.trapSizingReportStore,
    required this.operatorSession,
    required this.operatorAuthService,
    required this.pressureReadingStore,
    required this.pumpSurveyStore,
    required this.motorReferenceStore,
    required this.maintenanceReportStore,
    super.key,
  });

  final ReportStore reportStore;
  final ConsumptionStore consumptionStore;
  final CloudinaryService cloudinaryService;
  final AppUpdateService updateService;
  final TrapSizingReportStore trapSizingReportStore;
  final OperatorSession operatorSession;
  final OperatorAuthService operatorAuthService;
  final PressureReadingStore pressureReadingStore;
  final PumpSurveyStore pumpSurveyStore;
  final MotorReferenceStore motorReferenceStore;
  final MaintenanceReportStore maintenanceReportStore;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  var _showSplash = true;
  var _updateDialogShown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 950), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
    if (!widget.updateService.isDisabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HomeScreen(
          reportStore: widget.reportStore,
          consumptionStore: widget.consumptionStore,
          cloudinaryService: widget.cloudinaryService,
          trapSizingReportStore: widget.trapSizingReportStore,
          operatorSession: widget.operatorSession,
          operatorAuthService: widget.operatorAuthService,
          pressureReadingStore: widget.pressureReadingStore,
          pumpSurveyStore: widget.pumpSurveyStore,
          motorReferenceStore: widget.motorReferenceStore,
          maintenanceReportStore: widget.maintenanceReportStore,
        ),
        IgnorePointer(
          ignoring: !_showSplash,
          child: AnimatedOpacity(
            opacity: _showSplash ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: const ColoredBox(
              color: brandRed,
              child: Center(
                child: Image(
                  image: AssetImage('assets/logo-white.png'),
                  width: 88,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkForUpdate() async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted || _updateDialogShown) {
      return;
    }

    final notice = await widget.updateService.checkForUpdate();
    if (!mounted || notice == null || _updateDialogShown) {
      return;
    }

    _updateDialogShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: !notice.forceUpdate,
      builder: (context) => UpdateAvailableDialog(notice: notice),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.reportStore,
    required this.consumptionStore,
    required this.cloudinaryService,
    required this.trapSizingReportStore,
    required this.operatorSession,
    required this.operatorAuthService,
    required this.pressureReadingStore,
    required this.pumpSurveyStore,
    required this.motorReferenceStore,
    required this.maintenanceReportStore,
    super.key,
  });

  final ReportStore reportStore;
  final ConsumptionStore consumptionStore;
  final CloudinaryService cloudinaryService;
  final TrapSizingReportStore trapSizingReportStore;
  final OperatorSession operatorSession;
  final OperatorAuthService operatorAuthService;
  final PressureReadingStore pressureReadingStore;
  final PumpSurveyStore pumpSurveyStore;
  final MotorReferenceStore motorReferenceStore;
  final MaintenanceReportStore maintenanceReportStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AuthenticatedOperator? _user;
  var _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _refreshUser();
  }

  Future<void> _refreshUser() async {
    try {
      final user = await widget.operatorSession.currentOperator();
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoadingUser = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _openUserAccess() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OperatorAccessScreen(
          authService: widget.operatorAuthService,
          operatorSession: widget.operatorSession,
        ),
      ),
    );
    await _refreshUser();
  }

  Widget _identityButton() {
    final label =
        _user?.displayName ??
        (_isLoadingUser ? 'Cargando' : 'Ingresar o cambiar usuario');
    return OutlinedButton(
      key: const Key('home-user-button'),
      onPressed: _isLoadingUser ? null : _openUserAccess,
      style: OutlinedButton.styleFrom(
        foregroundColor: tealColor,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        side: const BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.badge_outlined, size: 24),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(
                flex: 4,
                child: EeHeader(
                  title: 'Eficiencia Energetica EE',
                  subtitle: 'Herramientas de campo para gestion energetica.',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _identityButton()),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Modulos', style: Theme.of(context).textTheme.titleMediumBold),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: EeActionButton(
                icon: Icons.local_fire_department_outlined,
                label: 'Ingresar consumos',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ConsumptionEntryScreen(
                        consumptionStore: widget.consumptionStore,
                        pressureReadingStore: widget.pressureReadingStore,
                        operatorSession: widget.operatorSession,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  key: const Key('boiler-readings-history-button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BoilerReadingsHistoryScreen(
                          consumptionStore: widget.consumptionStore,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 5,
                    ),
                    backgroundColor: brandRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 20),
                      SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Registros',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.tune,
          label: 'Dimensionamiento de trampas',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrapSizingScreen(
                  reportStore: widget.trapSizingReportStore,
                  operatorSession: widget.operatorSession,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.photo_camera_outlined,
          label: 'Reporte de tuberia desnuda',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BarePipeReportScreen(
                  reportStore: widget.reportStore,
                  cloudinaryService: widget.cloudinaryService,
                  operatorSession: widget.operatorSession,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.water_drop_outlined,
          label: 'Reportar fugas',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LeakReportScreen(
                  store: widget.maintenanceReportStore,
                  cloudinaryService: widget.cloudinaryService,
                  operatorSession: widget.operatorSession,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.electric_bolt_outlined,
          label: 'Levantamiento de bombas',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PumpSurveyScreen(
                  store: widget.pumpSurveyStore,
                  operatorSession: widget.operatorSession,
                  cloudinaryService: widget.cloudinaryService,
                  motorReferenceStore: widget.motorReferenceStore,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.touch_app_outlined,
          label: 'Tablero de ingreso',
          isPrimary: false,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InputControlsPlaygroundScreen(
                  consumptionStore: widget.consumptionStore,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Seguimiento de reportes',
          isPrimary: false,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MaintenanceHistoryScreen(
                  store: widget.maintenanceReportStore,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.bar_chart,
          label: 'Panel administrador',
          isPrimary: false,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminScreen(
                  reportStore: widget.reportStore,
                  consumptionStore: widget.consumptionStore,
                  maintenanceReportStore: widget.maintenanceReportStore,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class OperatorAccessScreen extends StatefulWidget {
  const OperatorAccessScreen({
    required this.authService,
    required this.operatorSession,
    super.key,
  });

  final OperatorAuthService authService;
  final OperatorSession operatorSession;

  @override
  State<OperatorAccessScreen> createState() => _OperatorAccessScreenState();
}

class _OperatorAccessScreenState extends State<OperatorAccessScreen> {
  final _loginNationalIdController = TextEditingController();
  final _loginPinController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerNationalIdController = TextEditingController();
  final _registerPinController = TextEditingController();
  final _registerPinConfirmationController = TextEditingController();
  AuthenticatedOperator? _operator;
  String _mode = 'login';
  String _message = '';
  MessageType _messageType = MessageType.info;
  var _isLoading = true;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _refreshOperator();
  }

  @override
  void dispose() {
    _loginNationalIdController.dispose();
    _loginPinController.dispose();
    _registerNameController.dispose();
    _registerNationalIdController.dispose();
    _registerPinController.dispose();
    _registerPinConfirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Usuario',
          subtitle: 'Sesion segura para identificar cada registro.',
        ),
        const SizedBox(height: 14),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_operator != null)
          _buildActiveSession()
        else
          _buildAccessForms(),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
      ],
    );
  }

  Widget _buildActiveSession() {
    final operator = _operator!;
    return InfoPanel(
      children: [
        TwoColumnInfo(
          leftLabel: 'Usuario activo',
          leftValue: operator.displayName,
          rightLabel: 'Rol',
          rightValue: operator.role == 'admin' ? 'Administrador' : 'Usuario',
        ),
        const SizedBox(height: 14),
        EeActionButton(
          icon: Icons.logout,
          label: _isSubmitting ? 'Cerrando sesion...' : 'Cerrar sesion',
          isPrimary: false,
          onPressed: _isSubmitting ? null : _signOut,
        ),
      ],
    );
  }

  Widget _buildAccessForms() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'login',
                icon: Icon(Icons.login),
                label: Text('Ingresar'),
              ),
              ButtonSegment(
                value: 'register',
                icon: Icon(Icons.person_add_alt_1),
                label: Text('Registrarse'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _isSubmitting
                ? null
                : (selection) {
                    setState(() {
                      _mode = selection.single;
                      _message = '';
                      _clearPinControllers();
                    });
                  },
          ),
        ),
        const SizedBox(height: 14),
        if (_mode == 'login') _buildLoginForm() else _buildRegistrationForm(),
      ],
    );
  }

  Widget _buildLoginForm() {
    return InfoPanel(
      children: [
        TextField(
          controller: _loginNationalIdController,
          enabled: !_isSubmitting,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Cedula',
            counterText: '',
            helperText: useFirebaseEmulators
                ? 'Modo de prueba: se acepta cualquier numero de 10 digitos.'
                : null,
          ),
        ),
        const SizedBox(height: 14),
        _pinField(controller: _loginPinController, label: 'PIN'),
        const SizedBox(height: 14),
        EeActionButton(
          icon: Icons.login,
          label: _isSubmitting ? 'Verificando...' : 'Ingresar',
          onPressed: _isSubmitting ? null : _signIn,
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return InfoPanel(
      children: [
        TextField(
          controller: _registerNameController,
          enabled: !_isSubmitting,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _registerNationalIdController,
          enabled: !_isSubmitting,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Cedula',
            counterText: '',
            helperText: useFirebaseEmulators
                ? 'Modo de prueba: se acepta cualquier numero de 10 digitos.'
                : null,
          ),
        ),
        const SizedBox(height: 14),
        _pinField(
          controller: _registerPinController,
          label: 'PIN de 4 a 6 numeros',
        ),
        const SizedBox(height: 14),
        _pinField(
          controller: _registerPinConfirmationController,
          label: 'Confirmar PIN',
        ),
        const SizedBox(height: 14),
        EeActionButton(
          icon: Icons.person_add_alt_1,
          label: _isSubmitting ? 'Registrando...' : 'Crear usuario',
          onPressed: _isSubmitting ? null : _register,
        ),
      ],
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSubmitting,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      decoration: InputDecoration(labelText: label, counterText: ''),
    );
  }

  Future<void> _refreshOperator() async {
    try {
      final operator = await widget.operatorSession.currentOperator();
      if (!mounted) return;
      setState(() {
        _operator = operator;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messageType = MessageType.error;
        _message = 'No fue posible verificar la sesion actual.';
      });
    }
  }

  Future<void> _signIn() async {
    final nationalId = _loginNationalIdController.text.trim();
    final pin = _loginPinController.text;
    if (nationalId.length != 10 || pin.length < 4) {
      _setAuthMessage(
        MessageType.error,
        'Ingresa una cedula de 10 digitos y un PIN de 4 a 6 numeros.',
      );
      return;
    }
    await _runAuthAction(
      () => widget.authService.signIn(nationalId: nationalId, pin: pin),
      'Sesion iniciada.',
    );
  }

  Future<void> _register() async {
    final fullName = _registerNameController.text.trim();
    final nationalId = _registerNationalIdController.text.trim();
    final pin = _registerPinController.text;
    if (fullName.length < 3 || nationalId.length != 10 || pin.length < 4) {
      _setAuthMessage(
        MessageType.error,
        'Completa nombre, cedula de 10 digitos y PIN de 4 a 6 numeros.',
      );
      return;
    }
    if (pin != _registerPinConfirmationController.text) {
      _setAuthMessage(MessageType.error, 'Los PIN no coinciden.');
      return;
    }
    await _runAuthAction(
      () => widget.authService.register(
        fullName: fullName,
        nationalId: nationalId,
        pin: pin,
      ),
      'Usuario registrado y sesion iniciada.',
    );
  }

  Future<void> _runAuthAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _isSubmitting = true;
      _message = '';
    });
    try {
      await action();
      _clearPinControllers();
      final operator = await widget.operatorSession.currentOperator();
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _operator = operator;
        _messageType = MessageType.success;
        _message = successMessage;
      });
    } on OperatorAuthException catch (error) {
      if (!mounted) return;
      _clearPinControllers();
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.error;
        _message = error.message;
      });
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSubmitting = true);
    await widget.authService.signOut();
    if (!mounted) return;
    _clearAllControllers();
    setState(() {
      _isSubmitting = false;
      _operator = null;
      _mode = 'login';
      _messageType = MessageType.success;
      _message = 'Sesion cerrada. Ya puedes ingresar con otro usuario.';
    });
  }

  void _clearPinControllers() {
    _loginPinController.clear();
    _registerPinController.clear();
    _registerPinConfirmationController.clear();
  }

  void _clearAllControllers() {
    _loginNationalIdController.clear();
    _registerNameController.clear();
    _registerNationalIdController.clear();
    _clearPinControllers();
  }

  void _setAuthMessage(MessageType type, String message) {
    setState(() {
      _messageType = type;
      _message = message;
    });
  }
}

class TrapSizingScreen extends StatefulWidget {
  const TrapSizingScreen({
    this.reportStore = const DisabledTrapSizingReportStore(),
    this.operatorSession = const DisabledOperatorSession(),
    super.key,
  });

  final TrapSizingReportStore reportStore;
  final OperatorSession operatorSession;

  @override
  State<TrapSizingScreen> createState() => _TrapSizingScreenState();
}

class _TrapSizingScreenState extends State<TrapSizingScreen> {
  final _rules = createTrapRules();
  final _values = <String, double>{};
  final _equipmentController = TextEditingController();
  final _notesController = TextEditingController();
  TrapRule? _selectedRule;
  TrapResult? _result;
  TrapSizingReportDraft? _reportDraft;
  String _sectionId = '';
  String _cloudMessage = '';
  MessageType _cloudMessageType = MessageType.info;
  String? _savedReportId;
  var _estimateIndirectly = false;
  var _isSaving = false;

  @override
  void dispose() {
    _equipmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRule = _selectedRule;
    final fields = _activeFields();

    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Seleccion de trampa',
          subtitle: 'Dimensionamiento preliminar para trampas de condensado.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TrapRule>(
          key: ValueKey(selectedRule?.name ?? 'empty-rule'),
          initialValue: selectedRule,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Uso'),
          items: _rules
              .map(
                (rule) => DropdownMenuItem(
                  value: rule,
                  child: Text(
                    rule.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _selectRule,
        ),
        if (selectedRule != null) ...[
          const SizedBox(height: 14),
          InfoPanel(
            children: [
              TwoColumnInfo(
                leftLabel: 'Tipo de trampa',
                leftValue: selectedRule.trapType,
                rightLabel: 'Condicion tipica',
                rightValue: selectedRule.condition,
              ),
              const SizedBox(height: 12),
              LabelValue(
                label: 'Observaciones',
                value: selectedRule.observations,
              ),
            ],
          ),
        ],
        if (selectedRule != null) ...[
          const SizedBox(height: 14),
          InfoPanel(
            children: [
              Text(
                'Datos del equipo',
                style: Theme.of(context).textTheme.titleMediumBold,
              ),
              const SizedBox(height: 12),
              Text('Seccion', style: Theme.of(context).textTheme.smallLabel),
              const SizedBox(height: 8),
              EmbeddedWheelPicker<String>(
                value: _sectionId,
                options: [
                  const PickerOption('', 'Selecciona una seccion'),
                  ...plantSections.map(
                    (section) => PickerOption(section.id, section.displayName),
                  ),
                ],
                onSelected: (value) {
                  setState(() {
                    _sectionId = value;
                    _invalidateCalculation();
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _equipmentController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Equipo',
                  hintText: 'Nombre o identificacion del equipo',
                ),
                onChanged: (_) => setState(_invalidateCalculation),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                ),
                onChanged: (_) => setState(_invalidateCalculation),
              ),
            ],
          ),
        ],
        if (selectedRule != null && selectedRule.requiresSizing) ...[
          const SizedBox(height: 14),
          InfoPanel(
            children: [
              Text(
                'Valores disponibles',
                style: Theme.of(context).textTheme.titleMediumBold,
              ),
              CheckboxListTile(
                value: _estimateIndirectly,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('No conozco la cantidad de condensado'),
                activeColor: brandRed,
                onChanged: (value) => _toggleEstimate(value ?? false),
              ),
              for (final field in fields) ...[
                const SizedBox(height: 8),
                FieldWheel(
                  field: field,
                  value: _values[field.key] ?? field.defaultValue,
                  onChanged: (value) {
                    setState(() {
                      _values[field.key] = value;
                      _invalidateCalculation();
                    });
                  },
                ),
              ],
              const SizedBox(height: 14),
              EeActionButton(
                icon: Icons.calculate_outlined,
                label: 'Calcular',
                onPressed: _calculate,
              ),
            ],
          ),
        ],
        if (selectedRule != null && !selectedRule.requiresSizing) ...[
          const SizedBox(height: 14),
          EeActionButton(
            icon: Icons.calculate_outlined,
            label: 'Calcular',
            onPressed: _calculate,
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 14),
          TrapResultPanel(result: _result!),
          const SizedBox(height: 14),
          InfoPanel(
            children: [
              EeActionButton(
                icon: _savedReportId == _reportDraft?.id
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_upload_outlined,
                label: _savedReportId == _reportDraft?.id
                    ? 'Guardado en la nube'
                    : (_isSaving
                          ? 'Confirmando guardado...'
                          : 'Guardar en la nube'),
                onPressed:
                    _isSaving ||
                        _reportDraft == null ||
                        _savedReportId == _reportDraft?.id
                    ? null
                    : _saveReport,
              ),
              const SizedBox(height: 10),
              EeActionButton(
                icon: Icons.calculate_outlined,
                label: 'Solo calcular / No guardar',
                isPrimary: false,
                onPressed: _isSaving || _reportDraft == null
                    ? null
                    : _keepWithoutSaving,
              ),
            ],
          ),
        ],
        if (_cloudMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _cloudMessageType, message: _cloudMessage),
        ],
      ],
    );
  }

  void _selectRule(TrapRule? rule) {
    setState(() {
      _selectedRule = rule;
      _estimateIndirectly = false;
      _invalidateCalculation();
      _values.clear();
      if (rule != null && rule.requiresSizing) {
        _seedFields([directCondensateField()]);
      }
    });
  }

  void _toggleEstimate(bool value) {
    final rule = _selectedRule;
    if (rule == null) return;
    setState(() {
      _estimateIndirectly = value;
      _invalidateCalculation();
      _values.clear();
      _seedFields(value ? rule.fields : [directCondensateField()]);
    });
  }

  List<FieldSpec> _activeFields() {
    final rule = _selectedRule;
    if (rule == null || !rule.requiresSizing) {
      return [];
    }
    return _estimateIndirectly ? rule.fields : [directCondensateField()];
  }

  void _seedFields(List<FieldSpec> fields) {
    for (final field in fields) {
      _values[field.key] = field.defaultValue;
    }
  }

  void _invalidateCalculation() {
    _result = null;
    _reportDraft = null;
    _savedReportId = null;
    _cloudMessage = '';
  }

  void _calculate() {
    final rule = _selectedRule;
    if (rule == null) return;

    final section = plantSectionById(_sectionId);
    if (section == null) {
      _showCalculationError('Selecciona la seccion del equipo.');
      return;
    }

    final equipmentName = _equipmentController.text.trim();
    if (equipmentName.isEmpty) {
      _showCalculationError('Ingresa el nombre o identificacion del equipo.');
      return;
    }

    late TrapCalculation calculation;
    late String calculationMethod;
    late List<FieldSpec> inputFields;
    if (!rule.requiresSizing) {
      calculation = rule.calculate(_values);
      calculationMethod = 'direct_selection';
      inputFields = const [];
    } else if (_estimateIndirectly) {
      calculation = rule.calculate(_values);
      calculationMethod = 'indirect';
      inputFields = rule.fields;
    } else {
      final directCondensateLMin = _values['directCondensate'] ?? 0;
      if (directCondensateLMin <= 0) {
        _showCalculationError(
          'Ingresa el caudal de condensado a desalojar o marca '
          '"No conozco la cantidad de condensado".',
        );
        return;
      }
      calculation = calculateDirectCondensate(directCondensateLMin);
      calculationMethod = 'direct';
      inputFields = [directCondensateField()];
    }

    final recommendedCapacity = calculation.condensateKgH * rule.safetyFactor;
    final recommendedDiameter = rule.requiresSizing
        ? recommendTrapConnectionDiameter(recommendedCapacity)
        : 'No aplica: seleccion directa';
    final pressure = math.max(0.0, _values['steamPressure'] ?? 0);
    final rows = <(String, String)>[
      ('Uso', rule.name),
      ('Tipo recomendado', rule.trapType),
    ];
    if (rule.requiresSizing) {
      rows.addAll([
        (
          'Carga estimada',
          '${Formats.noDecimal(calculation.condensateKgH)} kg/h',
        ),
        (
          'Equivalente aproximado',
          '${Formats.noDecimal(calculation.condensateKgH)} L/h',
        ),
        ('Factor de seguridad', Formats.one(rule.safetyFactor)),
        (
          'Capacidad minima sugerida',
          '${Formats.noDecimal(recommendedCapacity)} kg/h',
        ),
        ('Diametro preliminar sugerido', recommendedDiameter),
      ]);
    }
    if (rule.requiresSizing && pressure > 0) {
      rows.add((
        'Presion de vapor considerada',
        '${Formats.one(pressure)} bar(g)',
      ));
    }

    final explanation = rule.requiresSizing
        ? '${calculation.explanation}\n\nResultado preliminar para seleccion inicial. Para compra se debe validar contra presion diferencial, contrapresion, orificio interno, material, conexiones y tabla del fabricante.'
        : calculation.explanation;
    final inputs = <String, TrapReportInput>{
      for (final field in inputFields)
        field.key: TrapReportInput(
          value: _values[field.key] ?? field.defaultValue,
          unit: field.unit,
          labelSnapshot: field.label,
        ),
    };
    final reportResult = TrapSizingReportResult(
      condensateLoadKgH: calculation.condensateKgH,
      condensateEquivalentLH: calculation.condensateKgH,
      requiredCapacityKgH: recommendedCapacity,
      recommendedTrapType: rule.trapType,
      recommendedConnectionDiameter: recommendedDiameter,
      explanation: explanation,
    );

    setState(() {
      _result = TrapResult(
        title: 'Resumen de trampa requerida',
        rows: rows,
        explanation: explanation,
      );
      _reportDraft = TrapSizingReportDraft(
        id: _createTrapReportId(),
        sectionId: section.id,
        sectionNameSnapshot: section.displayName,
        equipmentName: equipmentName,
        equipmentNameNormalized: normalizeEquipmentName(equipmentName),
        notes: _notesController.text.trim(),
        applicationTypeId: rule.id,
        applicationTypeNameSnapshot: rule.name,
        calculationMethod: calculationMethod,
        inputs: inputs,
        result: reportResult,
        safetyFactor: rule.safetyFactor,
        assumptions: TrapSizingReportDraft.currentAssumptions(),
      );
      _savedReportId = null;
      _cloudMessage = '';
    });
  }

  void _showCalculationError(String message) {
    setState(() {
      _reportDraft = null;
      _savedReportId = null;
      _result = TrapResult(
        title: 'Faltan datos',
        rows: const [],
        explanation: message,
        isError: true,
      );
      _cloudMessage = '';
    });
  }

  Future<void> _saveReport() async {
    final draft = _reportDraft;
    if (draft == null || _isSaving) {
      return;
    }

    AuthenticatedOperator? operator;
    try {
      operator = await widget.operatorSession.currentOperator();
    } catch (_) {
      if (!mounted) return;
      _setCloudMessage(
        MessageType.error,
        'No fue posible verificar la sesion del usuario.',
      );
      return;
    }
    if (!mounted) return;
    if (operator == null) {
      _setCloudMessage(
        MessageType.warning,
        'Inicia sesion como usuario antes de guardar en la nube.',
      );
      return;
    }

    final confirmed = await _confirmCloudSave(draft, operator);
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _cloudMessageType = MessageType.info;
      _cloudMessage = 'Guardando y esperando confirmacion de la nube...';
    });

    try {
      final receipt = await widget.reportStore.saveReport(draft);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _savedReportId = receipt.id;
        _cloudMessageType = MessageType.success;
        _cloudMessage = 'Reporte confirmado en la nube.';
      });
    } on TrapSizingStoreException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _cloudMessageType = MessageType.error;
        _cloudMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _cloudMessageType = MessageType.error;
        _cloudMessage = 'No se pudo confirmar el reporte en la nube.';
      });
    }
  }

  Future<bool?> _confirmCloudSave(
    TrapSizingReportDraft draft,
    AuthenticatedOperator operator,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar guardado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryText('Seccion', draft.sectionNameSnapshot),
                _summaryText('Equipo', draft.equipmentName),
                _summaryText(
                  'Metodo',
                  _calculationMethodLabel(draft.calculationMethod),
                ),
                for (final input in draft.inputs.values)
                  _summaryText(
                    input.labelSnapshot,
                    '${Formats.one(input.value)} ${input.unit}',
                  ),
                _summaryText(
                  'Carga de condensado',
                  '${Formats.noDecimal(draft.result.condensateLoadKgH)} kg/h',
                ),
                _summaryText('Trampa', draft.result.recommendedTrapType),
                _summaryText('Usuario', operator.displayName),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Corregir'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Confirmar y guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('$label: $value'),
    );
  }

  String _calculationMethodLabel(String method) {
    return switch (method) {
      'direct' => 'Condensado conocido',
      'indirect' => 'Calculo indirecto',
      _ => 'Seleccion directa',
    };
  }

  void _keepWithoutSaving() {
    setState(() {
      _reportDraft = null;
      _savedReportId = null;
      _cloudMessageType = MessageType.info;
      _cloudMessage =
          'El resultado se mantuvo solo como calculo y no se guardo.';
    });
  }

  void _setCloudMessage(MessageType type, String message) {
    setState(() {
      _cloudMessageType = type;
      _cloudMessage = message;
    });
  }

  String _createTrapReportId() {
    final random = math.Random().nextInt(1 << 32).toRadixString(16);
    return 'trap-${DateTime.now().microsecondsSinceEpoch}-$random';
  }
}

class BarePipeReportScreen extends StatefulWidget {
  const BarePipeReportScreen({
    required this.reportStore,
    required this.cloudinaryService,
    required this.operatorSession,
    super.key,
  });

  final ReportStore reportStore;
  final CloudinaryService cloudinaryService;
  final OperatorSession operatorSession;

  @override
  State<BarePipeReportScreen> createState() => _BarePipeReportScreenState();
}

class _BarePipeReportScreenState extends State<BarePipeReportScreen> {
  final _picker = ImagePicker();
  final _lengthController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _notesController = TextEditingController();
  Uint8List? _photoBytes;
  String _sectionId = '';
  String _diameter = '';
  String _pressure = '';
  BarePipeCalculation? _calculation;
  CloudinaryUpload? _uploadedEvidence;
  String? _reportId;
  String _message = '';
  MessageType _messageType = MessageType.info;
  var _isSubmitting = false;

  @override
  void dispose() {
    _lengthController.dispose();
    _equipmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Reporte de tuberia desnuda',
          subtitle: 'Evidencia de vapor o condensado sin aislamiento.',
        ),
        const SizedBox(height: 14),
        EeActionButton(
          icon: Icons.photo_camera_outlined,
          label: 'Capturar evidencia',
          onPressed: _isSubmitting ? null : _pickPhoto,
        ),
        if (_photoBytes != null) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_photoBytes!, fit: BoxFit.cover),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'Seleccione la seccion',
          style: Theme.of(context).textTheme.labelBold,
        ),
        const SizedBox(height: 8),
        EmbeddedWheelPicker<String>(
          value: _sectionId,
          options: [
            const PickerOption('', 'Selecciona una seccion'),
            ...plantSections.map(
              (section) => PickerOption(section.id, section.displayName),
            ),
          ],
          onSelected: (value) {
            setState(() {
              _sectionId = value;
              _invalidateBareCalculation();
            });
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _equipmentController,
          enabled: !_isSubmitting,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Equipo o ubicacion',
            hintText: 'Ej. Cabezal de vapor del area',
          ),
          onChanged: (_) => setState(_invalidateBareCalculation),
        ),
        const SizedBox(height: 14),
        Text(
          'Indique el diametro de la tuberia',
          style: Theme.of(context).textTheme.labelBold,
        ),
        const SizedBox(height: 8),
        EmbeddedWheelPicker<String>(
          value: _diameter,
          options: [
            const PickerOption('', 'Sin dato'),
            ...barePipeDiameters.map(
              (diameter) => PickerOption(diameter.label, diameter.label),
            ),
          ],
          onSelected: (value) {
            setState(() {
              _diameter = value;
              _invalidateBareCalculation();
            });
          },
        ),
        const SizedBox(height: 14),
        Text(
          'Indique la presion estimada de la linea',
          style: Theme.of(context).textTheme.labelBold,
        ),
        const SizedBox(height: 8),
        EmbeddedWheelPicker<String>(
          value: _pressure,
          options: [
            const PickerOption('', 'Sin dato'),
            ...saturationTemperatureByPressure.map(
              (item) => PickerOption(
                item.$1.toStringAsFixed(0),
                '${item.$1.toStringAsFixed(0)} bar(g)',
              ),
            ),
          ],
          onSelected: (value) {
            setState(() {
              _pressure = value;
              _invalidateBareCalculation();
            });
          },
        ),
        const SizedBox(height: 14),
        Text(
          'Indique la longitud de la tuberia desnuda',
          style: Theme.of(context).textTheme.labelBold,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _lengthController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
          ],
          decoration: const InputDecoration(hintText: '0.0', suffixText: 'm'),
          onChanged: (_) => setState(_invalidateBareCalculation),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _notesController,
          enabled: !_isSubmitting,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Observaciones (opcional)',
          ),
          onChanged: (_) => setState(_invalidateBareCalculation),
        ),
        const SizedBox(height: 16),
        EeActionButton(
          icon: Icons.calculate_outlined,
          label: 'Calcular y revisar',
          onPressed: _isSubmitting ? null : _calculateBarePipeReport,
        ),
        if (_calculation != null) ...[
          const SizedBox(height: 14),
          InfoPanel(
            children: [
              Text(
                'Resumen del reporte',
                style: Theme.of(context).textTheme.titleMediumBold,
              ),
              const SizedBox(height: 12),
              TwoColumnInfo(
                leftLabel: 'Perdida termica',
                leftValue:
                    '${Formats.two(_calculation!.heatLossKw)} kW termicos',
                rightLabel: 'Perdida lineal',
                rightValue: '${Formats.two(_calculation!.heatLossWPerM)} W/m',
              ),
              const SizedBox(height: 12),
              LabelValue(
                label: 'Equipo o ubicacion',
                value: _equipmentController.text.trim(),
              ),
              const SizedBox(height: 12),
              LabelValue(
                label: 'Datos principales',
                value:
                    '$_diameter - $_pressure bar(g) - ${_lengthController.text.trim()} m',
              ),
            ],
          ),
          const SizedBox(height: 14),
          EeActionButton(
            icon: _uploadedEvidence == null
                ? Icons.cloud_upload_outlined
                : Icons.sync_outlined,
            label: _isSubmitting
                ? 'Guardando reporte...'
                : (_uploadedEvidence == null
                      ? 'Guardar reporte'
                      : 'Reintentar guardado'),
            onPressed: _isSubmitting ? null : _saveBarePipeReport,
          ),
        ],
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
      ],
    );
  }

  Future<void> _pickPhoto() async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } catch (_) {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
    }

    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _invalidateBareCalculation();
    });
  }

  void _calculateBarePipeReport() {
    final photoBytes = _photoBytes;
    if (photoBytes == null) {
      _setMessage(
        MessageType.error,
        'Captura una foto para revisar el reporte completo.',
      );
      return;
    }

    final section = plantSectionById(_sectionId);
    if (section == null) {
      _setMessage(MessageType.error, 'Selecciona la seccion.');
      return;
    }
    if (_equipmentController.text.trim().isEmpty) {
      _setMessage(
        MessageType.error,
        'Ingresa el equipo o ubicacion de la tuberia.',
      );
      return;
    }
    if (_diameter.isEmpty) {
      _setMessage(MessageType.error, 'Selecciona el diametro de la tuberia.');
      return;
    }
    if (_pressure.isEmpty) {
      _setMessage(MessageType.error, 'Selecciona la presion estimada.');
      return;
    }

    final lengthText = _lengthController.text.trim();
    final lengthMeters = _parseOptionalNumber(lengthText);
    if (lengthMeters == null || lengthMeters <= 0) {
      _setMessage(MessageType.error, 'La longitud debe ser mayor a cero.');
      return;
    }

    final pressureBarG = double.tryParse(_pressure);
    final calculation = BarePipeCalculator.calculate(
      diameterLabel: _diameter,
      pressureBarG: pressureBarG,
      lengthMeters: lengthMeters,
    );
    if (!calculation.isCalculated) {
      _setMessage(
        MessageType.error,
        'No fue posible calcular la perdida termica con estos datos.',
      );
      return;
    }

    setState(() {
      _calculation = calculation;
      _uploadedEvidence = null;
      _reportId = _createReportId();
      _messageType = MessageType.success;
      _message =
          'Calculo listo. Revisa el resumen y confirma antes de guardar.';
    });
  }

  Future<void> _saveBarePipeReport() async {
    final photoBytes = _photoBytes;
    final calculation = _calculation;
    final reportId = _reportId;
    final section = plantSectionById(_sectionId);
    final lengthMeters = _parseOptionalNumber(_lengthController.text);
    final pressureBarG = double.tryParse(_pressure);
    if (photoBytes == null ||
        calculation == null ||
        reportId == null ||
        section == null ||
        lengthMeters == null ||
        pressureBarG == null ||
        _isSubmitting) {
      _setMessage(
        MessageType.error,
        'Calcula y revisa el reporte antes de guardarlo.',
      );
      return;
    }

    final operator = await widget.operatorSession.currentOperator();
    if (!mounted) return;
    if (operator == null) {
      _setMessage(
        MessageType.warning,
        'Inicia sesion como usuario antes de guardar en la nube.',
      );
      return;
    }

    final confirmed = await _confirmBarePipeSave(
      section: section,
      calculation: calculation,
      operator: operator,
    );
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _messageType = MessageType.info;
      _message = _uploadedEvidence == null
          ? 'Subiendo evidencia a Cloudinary...'
          : 'Reintentando confirmacion del reporte...';
    });

    try {
      final upload =
          _uploadedEvidence ??
          await widget.cloudinaryService.uploadEvidence(
            bytes: photoBytes,
            reportId: reportId,
          );
      if (!mounted) return;
      setState(() {
        _uploadedEvidence = upload;
        _message = 'Evidencia subida. Confirmando documento en la nube...';
      });
      final report = BarePipeReport(
        id: reportId,
        createdAt: DateTime.now(),
        section: section.displayName,
        diameterLabel: _diameter,
        pressureBarG: pressureBarG,
        lengthMeters: lengthMeters,
        photoUrl: upload.secureUrl,
        photoPublicId: upload.publicId,
        calculation: calculation,
        sectionId: section.id,
        sectionNameSnapshot: section.displayName,
        equipmentName: _equipmentController.text.trim(),
        equipmentNameNormalized: normalizeEquipmentName(
          _equipmentController.text,
        ),
        notes: _notesController.text.trim(),
        photoProvider: 'cloudinary',
        status: 'synced',
      );
      await widget.reportStore.saveReport(report);

      if (!mounted) return;
      setState(() {
        _resetBarePipeForm();
        _messageType = MessageType.success;
        _message =
            'Reporte confirmado: ${Formats.two(calculation.heatLossKw)} kW termicos.';
      });
    } on ReportSyncException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.warning;
        _message = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.error;
        _message = error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  Future<bool?> _confirmBarePipeSave({
    required PlantSection section,
    required BarePipeCalculation calculation,
    required AuthenticatedOperator operator,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar reporte'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_photoBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _photoBytes!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Seccion: ${section.displayName}'),
                Text('Equipo: ${_equipmentController.text.trim()}'),
                Text(
                  'Tuberia: $_diameter - $_pressure bar(g) - '
                  '${_lengthController.text.trim()} m',
                ),
                Text(
                  'Perdida: ${Formats.two(calculation.heatLossKw)} kW termicos',
                ),
                Text('Usuario: ${operator.displayName}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Corregir'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Confirmar y guardar'),
            ),
          ],
        );
      },
    );
  }

  void _invalidateBareCalculation() {
    _calculation = null;
    _uploadedEvidence = null;
    _reportId = null;
    _message = '';
  }

  void _resetBarePipeForm() {
    _isSubmitting = false;
    _photoBytes = null;
    _sectionId = '';
    _diameter = '';
    _pressure = '';
    _calculation = null;
    _uploadedEvidence = null;
    _reportId = null;
    _lengthController.clear();
    _equipmentController.clear();
    _notesController.clear();
  }

  void _setMessage(MessageType type, String message) {
    setState(() {
      _messageType = type;
      _message = message;
    });
  }

  double? _parseOptionalNumber(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  String _createReportId() {
    final random = math.Random().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().millisecondsSinceEpoch}-$random';
  }
}

enum ConsumptionEntryTab { consumption, pressure }

class ConsumptionEntryScreen extends StatefulWidget {
  const ConsumptionEntryScreen({
    required this.consumptionStore,
    required this.pressureReadingStore,
    required this.operatorSession,
    super.key,
  });

  final ConsumptionStore consumptionStore;
  final PressureReadingStore pressureReadingStore;
  final OperatorSession operatorSession;

  @override
  State<ConsumptionEntryScreen> createState() => _ConsumptionEntryScreenState();
}

class _ConsumptionEntryScreenState extends State<ConsumptionEntryScreen> {
  static const _psiPerBar = 14.5037738;

  final _notesController = TextEditingController();
  String _boilerName = boilerNames.first;
  double _boilerPressurePsi = 10.4 * _psiPerBar;
  int _fuelInputValue = 0;
  int _waterInputValue = 0;
  int _steamInputValue = 0;
  Map<String, BoilerReading> _latestReadingByBoilerId = {};
  bool _isLoadingPreviousReadings = true;
  bool _pressureInBar = false;
  ConsumptionEntryTab _selectedTab = ConsumptionEntryTab.consumption;
  String _message = '';
  MessageType _messageType = MessageType.info;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_synchronizePendingOnOpen());
  }

  Future<void> _synchronizePendingOnOpen() async {
    try {
      final readings = await widget.consumptionStore.loadReadings();
      if (!mounted) return;
      final sorted = [...readings]
        ..sort((left, right) {
          final byDate = right.recordedAt.compareTo(left.recordedAt);
          return byDate != 0 ? byDate : right.revision.compareTo(left.revision);
        });
      final latest = <String, BoilerReading>{};
      for (final reading in sorted) {
        latest.putIfAbsent(reading.effectiveBoilerId, () => reading);
      }
      final pendingCount = readings
          .where((reading) => reading.status == 'pending_sync')
          .length;
      setState(() {
        _latestReadingByBoilerId = latest;
        _isLoadingPreviousReadings = false;
        _applyPreviousReading(latest[boilerByName(_boilerName)!.id]);
      });
      if (pendingCount > 0) {
        _setMessage(
          MessageType.warning,
          pendingCount == 1
              ? 'Hay una lectura pendiente de sincronizacion. Se reintentara automaticamente.'
              : 'Hay $pendingCount lecturas pendientes de sincronizacion. Se reintentaran automaticamente.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPreviousReadings = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boiler = boilerByName(_boilerName)!;
    final readsSteam = boiler.readsSteam;
    return AppShell(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab == ConsumptionEntryTab.consumption ? 0 : 2,
        onDestinationSelected: (index) {
          FocusScope.of(context).unfocus();
          if (index == 1) {
            returnToHome(context);
            return;
          }
          setState(() {
            _selectedTab = index == 0
                ? ConsumptionEntryTab.consumption
                : ConsumptionEntryTab.pressure;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Consumos',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Casa',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Presiones',
          ),
        ],
      ),
      children: [
        EeHeader(
          title: 'Ingresar consumos',
          subtitle: _selectedTab == ConsumptionEntryTab.consumption
              ? 'Registro horario de lecturas acumuladas.'
              : 'Registro de presiones de distribuidores de vapor.',
        ),
        const SizedBox(height: 14),
        Visibility(
          visible: _selectedTab == ConsumptionEntryTab.consumption,
          maintainState: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoPanel(
                children: [
                  if (_isLoadingPreviousReadings) ...[
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Seleccione la caldera',
                              style: Theme.of(context).textTheme.labelBold,
                            ),
                            const SizedBox(height: 8),
                            EmbeddedWheelPicker<String>(
                              value: _boilerName,
                              options: boilerNames
                                  .map((name) => PickerOption(name, name))
                                  .toList(),
                              onSelected: _selectBoiler,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Presion',
                              style: Theme.of(context).textTheme.labelBold,
                            ),
                            const SizedBox(height: 8),
                            EmbeddedWheelPicker<double>(
                              value: _selectedPressureValue,
                              options: _pressureOptions,
                              onSelected: _selectPressure,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _pressureUnitButton(
                                    label: 'PSI',
                                    selected: !_pressureInBar,
                                    onPressed: () => _setPressureUnit(false),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _pressureUnitButton(
                                    label: 'bar',
                                    selected: _pressureInBar,
                                    onPressed: () => _setPressureUnit(true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tipo de dato ingresado',
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: brandRed, size: 20),
                        SizedBox(width: 10),
                        Text('Lectura acumulada'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildConsumptionOdometer(
                    label: 'Lectura acumulada de bunker',
                    helper: _isAlfaLaval
                        ? 'El medidor nuevo se lee directamente en galones.'
                        : 'Lectura acumulada del medidor en galones.',
                    value: _fuelInputValue,
                    unit: 'gal',
                    keyPrefix: 'consumption-bunker',
                    onChanged: (value) =>
                        setState(() => _fuelInputValue = value),
                  ),
                  const SizedBox(height: 14),
                  _buildConsumptionOdometer(
                    label: 'Lectura acumulada de agua',
                    helper: _isAlfaLaval
                        ? 'Cada unidad del contador equivale a 10 litros.'
                        : 'Lectura acumulada del medidor en galones.',
                    value: _waterInputValue,
                    unit: _isAlfaLaval ? 'x10 L' : 'gal',
                    keyPrefix: 'consumption-water',
                    onChanged: (value) =>
                        setState(() => _waterInputValue = value),
                  ),
                  if (readsSteam) ...[
                    const SizedBox(height: 14),
                    _buildConsumptionOdometer(
                      label: 'Lectura acumulada de vapor',
                      helper: 'Lectura acumulada del medidor en kilogramos.',
                      value: _steamInputValue,
                      unit: 'kg',
                      keyPrefix: 'consumption-steam',
                      onChanged: (value) =>
                          setState(() => _steamInputValue = value),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    enabled: !_isSubmitting,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              EeActionButton(
                icon: Icons.fact_check_outlined,
                label: _isSubmitting
                    ? 'Guardando lectura...'
                    : 'Revisar lectura',
                onPressed: _isSubmitting ? null : _reviewAndSaveReading,
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                MessageBox(type: _messageType, message: _message),
              ],
            ],
          ),
        ),
        Visibility(
          visible: _selectedTab == ConsumptionEntryTab.pressure,
          maintainState: true,
          child: PressureEntryTab(
            store: widget.pressureReadingStore,
            operatorSession: widget.operatorSession,
          ),
        ),
      ],
    );
  }

  Widget _buildConsumptionOdometer({
    required String label,
    required String helper,
    required int value,
    required String unit,
    required String keyPrefix,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelBold),
        const SizedBox(height: 3),
        Text(
          helper,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
        const SizedBox(height: 8),
        IgnorePointer(
          ignoring: _isSubmitting,
          child: IndustrialOdometer(
            value: value,
            unitLabel: unit,
            digitKeyPrefix: keyPrefix,
            valueKey: ValueKey('$keyPrefix-value'),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _selectBoiler(String value) {
    setState(() {
      _boilerName = value;
      _boilerPressurePsi = _defaultPressurePsi(value);
      _applyPreviousReading(_latestReadingByBoilerId[boilerByName(value)!.id]);
    });
  }

  bool get _isAlfaLaval => _boilerName == alfaLavalBoiler;

  double _defaultPressurePsi(String boilerName) {
    final pressureBar = boilerName == alfaLavalBoiler ? 10.4 : 8.0;
    return pressureBar * _psiPerBar;
  }

  double get _selectedPressureValue {
    if (_pressureInBar) {
      return ((_boilerPressurePsi / _psiPerBar) * 10).round() / 10;
    }
    return _boilerPressurePsi.roundToDouble();
  }

  List<PickerOption<double>> get _pressureOptions {
    if (_pressureInBar) {
      return [
        for (var tenth = 0; tenth <= 138; tenth++)
          PickerOption(tenth / 10, (tenth / 10).toStringAsFixed(1)),
      ];
    }
    return [
      for (var psi = 0; psi <= 200; psi++) PickerOption(psi.toDouble(), '$psi'),
    ];
  }

  void _selectPressure(double value) {
    setState(() {
      _boilerPressurePsi = _pressureInBar
          ? math.min(value * _psiPerBar, 200)
          : value;
    });
  }

  void _setPressureUnit(bool useBar) {
    if (_pressureInBar == useBar) return;
    setState(() => _pressureInBar = useBar);
  }

  Widget _pressureUnitButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: selected
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(label),
            ),
    );
  }

  Future<void> _reviewAndSaveReading() async {
    AuthenticatedOperator? operator;
    try {
      operator = await widget.operatorSession.currentOperator();
    } catch (_) {
      _setMessage(
        MessageType.error,
        'No fue posible verificar la sesion del usuario.',
      );
      return;
    }
    if (!mounted) return;
    if (operator == null) {
      _setMessage(
        MessageType.warning,
        'Inicia sesion como usuario antes de guardar lecturas.',
      );
      return;
    }

    final boiler = boilerByName(_boilerName)!;
    final boilerPressurePsi = _boilerPressurePsi;
    if (_fuelInputValue <= 0) {
      _setMessage(
        MessageType.error,
        'La lectura acumulada de bunker debe ser mayor que cero.',
      );
      return;
    }
    if (_waterInputValue <= 0) {
      _setMessage(
        MessageType.error,
        'La lectura acumulada de agua debe ser mayor que cero.',
      );
      return;
    }
    if (boiler.readsSteam && _steamInputValue <= 0) {
      _setMessage(
        MessageType.error,
        'La lectura de vapor es obligatoria para Alfa Laval 1200.',
      );
      return;
    }
    final fuelInput = _fuelInputValue.toDouble();
    final waterInput = _waterInputValue.toDouble();
    final fuelTotal = fuelInput;
    final waterTotal = _isAlfaLaval
        ? alfaWaterGallonsFromCounter(waterInput)
        : waterInput;
    final steamTotal = boiler.readsSteam ? _steamInputValue.toDouble() : null;
    final originalInputs = <String, dynamic>{
      'bunker': {'value': fuelInput, 'unit': 'gal', 'gallons': fuelTotal},
      'water': {
        'value': waterInput,
        'unit': _isAlfaLaval ? 'counter_x10_L' : 'gal',
        'gallons': waterTotal,
        if (_isAlfaLaval) 'litersPerCounterUnit': alfaWaterLitersPerCounterUnit,
        if (_isAlfaLaval)
          'gallonsPerCounterUnit': alfaWaterGallonsPerCounterUnit,
      },
      if (boiler.readsSteam)
        'steam': {'value': steamTotal, 'unit': 'kg', 'kilograms': steamTotal},
    };

    final now = DateTime.now().toUtc();
    final intervalStart = guayaquilHourStart(now);
    final intervalEnd = intervalStart.add(const Duration(hours: 1));
    final baseId = deterministicBoilerReadingId(boiler.id, intervalStart);
    var rawReading = BoilerReading(
      id: baseId,
      recordedAt: now,
      createdAt: now,
      boilerName: _boilerName,
      boilerId: boiler.id,
      readingMode: 'cumulative_meter',
      fuelTotal: fuelTotal,
      waterTotal: waterTotal,
      steamTotal: boiler.readsSteam ? steamTotal : null,
      boilerPressurePsi: boilerPressurePsi,
      boilerPressureUnit: defaultBoilerPressureUnit,
      waterUnit: boiler.waterUnit,
      bunkerUnit: boiler.bunkerUnit,
      steamUnit: boiler.steamUnit,
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      rootRecordId: baseId,
      validationWarnings: const [],
      originalInputs: originalInputs,
      validationReferenceVersion: boilerSafetyReferenceVersion,
      notes: _notesController.text.trim(),
      status: 'synced',
      fuelConsumption: null,
      waterConsumption: null,
      steamConsumption: null,
    );

    try {
      final existing = await widget.consumptionStore.loadReadings();
      final sameInterval = existing
          .where(
            (reading) =>
                reading.effectiveBoilerId == boiler.id &&
                guayaquilHourStart(reading.recordedAt.toUtc()) == intervalStart,
          )
          .toList();
      if (sameInterval.isNotEmpty) {
        sameInterval.sort(
          (left, right) => right.revision.compareTo(left.revision),
        );
        final latest = sameInterval.first;
        if (operator.role != 'admin') {
          _setMessage(
            MessageType.warning,
            'Ya existe una lectura para esta caldera y hora. Un administrador debe autorizar una revision.',
          );
          return;
        }
        final createRevision = await _confirmRevision(latest);
        if (!mounted || createRevision != true) {
          return;
        }
        final revision = latest.revision + 1;
        rawReading = rawReading.copyWith(
          id: '${baseId}_r$revision',
          revision: revision,
          replacesRecordId: latest.id,
          rootRecordId: latest.rootRecordId ?? baseId,
        );
      }

      final reading = BoilerConsumptionCalculator.attachDeltas(
        rawReading,
        existing,
      );
      if (reading.validationWarnings.isNotEmpty) {
        final acceptedWarnings = await _confirmValidationWarnings(reading);
        if (!mounted || acceptedWarnings != true) {
          return;
        }
      }
      final confirmed = await _confirmBoilerReading(reading, operator);
      if (!mounted || confirmed != true) {
        return;
      }

      setState(() {
        _isSubmitting = true;
        _messageType = MessageType.info;
        _message = 'Guardando y esperando confirmacion de la nube...';
      });
      await widget.consumptionStore.saveReading(reading);
      if (!mounted) {
        return;
      }
      _finishSubmission(
        MessageType.success,
        'Lectura ingresada. ${_formatReadingDelta(reading)}',
        reading,
      );
    } on DuplicateBoilerReadingException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.warning;
        _message = error.message;
      });
    } on ConsumptionSyncException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.warning;
        _message = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.error;
        _message = error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  Future<bool?> _confirmRevision(BoilerReading previous) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lectura existente'),
          content: Text(
            'Ya existe el registro ${previous.id}. La correccion creara una nueva revision y conservara el valor anterior.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Crear revision'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmBoilerReading(
    BoilerReading reading,
    AuthenticatedOperator operator,
  ) {
    final mode = reading.readingMode == 'cumulative_meter'
        ? 'Lectura acumulada'
        : 'Consumo del intervalo';
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar lectura'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Caldera: ${reading.boilerName}'),
                Text('Tipo: $mode'),
                Text(
                  'Presion: ${Formats.one(reading.boilerPressurePsi!)} PSI '
                  '(${Formats.one(reading.boilerPressurePsi! / _psiPerBar)} bar)',
                ),
                Text(
                  'Bunker: ${Formats.noDecimal(reading.fuelTotal)} '
                  '(${_unitLabel(reading.bunkerUnit)})',
                ),
                Text(
                  _isAlfaLaval
                      ? 'Agua: ${Formats.two(alfaWaterLitersFromCounter(_waterInputValue.toDouble()))} L = '
                            '${Formats.two(reading.waterTotal)} gal'
                      : 'Agua: ${Formats.two(reading.waterTotal)} '
                            '(${_unitLabel(reading.waterUnit)})',
                ),
                if (reading.steamTotal != null)
                  Text(
                    'Vapor: ${Formats.two(reading.steamTotal!)} (${_unitLabel(reading.steamUnit)})',
                  ),
                Text('Revision: ${reading.revision}'),
                Text('Usuario: ${operator.displayName}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Corregir'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Confirmar y guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmValidationWarnings(BoilerReading reading) {
    final limits = boilerSafetyLimits[reading.effectiveBoilerId];
    final messages = <String>[];
    for (final warning in reading.validationWarnings) {
      switch (warning) {
        case 'bunker_meter_reset_or_negative_delta':
          messages.add(
            'La lectura de bunker es menor que la lectura anterior.',
          );
          break;
        case 'water_meter_reset_or_negative_delta':
          messages.add('La lectura de agua es menor que la lectura anterior.');
          break;
        case 'steam_meter_reset_or_negative_delta':
          messages.add('La lectura de vapor es menor que la lectura anterior.');
          break;
        case 'bunker_delta_above_historical_range':
          messages.add(
            'El salto de bunker supera el rango historico'
            '${limits == null ? '' : ' de ${Formats.noDecimal(limits.bunkerGallonsPerHour)} gal/h'}.',
          );
          break;
        case 'water_delta_above_historical_range':
          messages.add(
            'El salto de agua supera el rango historico'
            '${limits == null ? '' : ' de ${Formats.noDecimal(limits.waterGallonsPerHour)} gal/h'}.',
          );
          break;
      }
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: const Text('Revisa los digitos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La lectura puede ser real, pero esta fuera del comportamiento habitual:',
              ),
              const SizedBox(height: 12),
              for (final message in messages) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('- '),
                    Expanded(child: Text(message)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Corregir lectura'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continuar de todas formas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finishSubmission(
    MessageType type,
    String message,
    BoilerReading reading,
  ) {
    setState(() {
      _isSubmitting = false;
      _boilerPressurePsi = _defaultPressurePsi(_boilerName);
      _notesController.clear();
      _latestReadingByBoilerId = {
        ..._latestReadingByBoilerId,
        reading.effectiveBoilerId: reading,
      };
      _applyPreviousReading(reading);
      _messageType = type;
      _message = message;
    });
  }

  void _applyPreviousReading(BoilerReading? reading) {
    if (reading == null) {
      _fuelInputValue = 0;
      _waterInputValue = 0;
      _steamInputValue = 0;
      return;
    }
    if (_isAlfaLaval) {
      _fuelInputValue = alfaBunkerMeterInputGallons(reading).round();
      _waterInputValue =
          (_originalInputValue(reading, 'water') ??
                  reading.waterTotal / alfaWaterGallonsPerCounterUnit)
              .round();
    } else {
      _fuelInputValue = reading.fuelTotal.round();
      _waterInputValue = reading.waterTotal.round();
    }
    _steamInputValue = reading.steamTotal?.round() ?? 0;
  }

  double? _originalInputValue(BoilerReading reading, String key) {
    final item = reading.originalInputs[key];
    if (item is! Map) return null;
    final value = item['value'];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  String _formatReadingDelta(BoilerReading reading) {
    final parts = <String>[];
    if (reading.fuelConsumption != null) {
      parts.add(
        'bunker ${Formats.two(reading.fuelConsumption!)} ${_unitLabel(reading.bunkerUnit)}',
      );
    }
    if (reading.waterConsumption != null) {
      parts.add(
        'agua ${Formats.two(reading.waterConsumption!)} ${_unitLabel(reading.waterUnit)}',
      );
    }
    if (reading.steamConsumption != null) {
      parts.add(
        'vapor ${Formats.two(reading.steamConsumption!)} ${_unitLabel(reading.steamUnit)}',
      );
    }
    if (parts.isEmpty) {
      return 'Es la primera lectura disponible para esta caldera; los consumos se calcularan desde la siguiente lectura.';
    }
    return 'Consumo calculado: ${parts.join(', ')}.';
  }

  void _setMessage(MessageType type, String message) {
    setState(() {
      _messageType = type;
      _message = message;
    });
  }

  String _unitLabel(String unit) =>
      unit == pendingUnit ? 'unidad pendiente' : unit;
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    required this.reportStore,
    required this.consumptionStore,
    required this.maintenanceReportStore,
    super.key,
  });

  final ReportStore reportStore;
  final ConsumptionStore consumptionStore;
  final MaintenanceReportStore maintenanceReportStore;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

enum AdminPanelTab { barePipe, consumption, leaks }

enum ConsumptionScale { hour, day, week, month, year }

class _AdminScreenState extends State<AdminScreen> {
  List<BarePipeReport> _reports = [];
  List<BoilerReading> _readings = [];
  List<MaintenanceReportSummary> _maintenanceReports = [];
  var _isLoadingReports = true;
  var _isLoadingReadings = true;
  var _isLoadingMaintenance = true;
  var _selectedTab = AdminPanelTab.barePipe;
  var _consumptionScale = ConsumptionScale.hour;
  var _selectedBoiler = '';

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadReadings();
    _loadMaintenanceReports();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (_selectedTab) {
          AdminPanelTab.barePipe => 0,
          AdminPanelTab.consumption => 1,
          AdminPanelTab.leaks => 3,
        },
        onDestinationSelected: (index) {
          if (index == 2) {
            returnToHome(context);
            return;
          }
          setState(() {
            _selectedTab = switch (index) {
              0 => AdminPanelTab.barePipe,
              1 => AdminPanelTab.consumption,
              _ => AdminPanelTab.leaks,
            };
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.thermostat_outlined),
            selectedIcon: Icon(Icons.thermostat),
            label: 'Tuberias',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Consumos',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Casa',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Fugas',
          ),
        ],
      ),
      children: [
        const EeHeader(
          title: 'Panel administrador',
          subtitle: 'Indicadores de campo para eficiencia energetica.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isCurrentTabLoading() ? null : _refreshCurrentTab,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ),
        if (_selectedTab == AdminPanelTab.barePipe)
          BarePipeAdminTab(reports: _reports, isLoading: _isLoadingReports)
        else if (_selectedTab == AdminPanelTab.consumption)
          ConsumptionAdminTab(
            readings: _readings,
            isLoading: _isLoadingReadings,
            selectedBoiler: _selectedBoiler,
            scale: _consumptionScale,
            onBoilerChanged: (value) => setState(() => _selectedBoiler = value),
            onScaleChanged: (value) =>
                setState(() => _consumptionScale = value),
          )
        else
          LeakAdminTab(
            reports: _maintenanceReports
                .where((item) => item.type == MaintenanceReportType.leak)
                .toList(),
            isLoading: _isLoadingMaintenance,
          ),
      ],
    );
  }

  bool _isCurrentTabLoading() {
    return switch (_selectedTab) {
      AdminPanelTab.barePipe => _isLoadingReports,
      AdminPanelTab.consumption => _isLoadingReadings,
      AdminPanelTab.leaks => _isLoadingMaintenance,
    };
  }

  Future<void> _refreshCurrentTab() {
    return switch (_selectedTab) {
      AdminPanelTab.barePipe => _loadReports(),
      AdminPanelTab.consumption => _loadReadings(),
      AdminPanelTab.leaks => _loadMaintenanceReports(),
    };
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    final reports = await widget.reportStore.loadReports();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _isLoadingReports = false;
    });
  }

  Future<void> _loadReadings() async {
    setState(() => _isLoadingReadings = true);
    final readings = await widget.consumptionStore.loadReadings();
    if (!mounted) return;
    setState(() {
      _readings = readings;
      _isLoadingReadings = false;
    });
  }

  Future<void> _loadMaintenanceReports() async {
    setState(() => _isLoadingMaintenance = true);
    try {
      final reports = await widget.maintenanceReportStore.loadReports();
      if (!mounted) return;
      setState(() {
        _maintenanceReports = reports;
        _isLoadingMaintenance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMaintenance = false);
    }
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.children, this.bottomNavigationBar, super.key});

  final List<Widget> children;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EeHeader extends StatelessWidget {
  const EeHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: brandRed,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Image.asset('assets/logo-white.png', width: 44, height: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EeActionButton extends StatelessWidget {
  const EeActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final background = isPrimary ? brandRed : Colors.white;
    final foreground = isPrimary ? Colors.white : textColor;
    final borderSide = isPrimary
        ? BorderSide.none
        : const BorderSide(color: borderColor);

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: borderColor,
          disabledForegroundColor: mutedColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: borderSide,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: textColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class TwoColumnInfo extends StatelessWidget {
  const TwoColumnInfo({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    super.key,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        final children = [
          LabelValue(label: leftLabel, value: leftValue),
          LabelValue(label: rightLabel, value: rightValue),
        ];
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [children[0], const SizedBox(height: 12), children[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 12),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }
}

class LabelValue extends StatelessWidget {
  const LabelValue({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.smallLabel),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class FieldWheel extends StatelessWidget {
  const FieldWheel({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final FieldSpec field;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${field.label} (${field.unit})',
          style: Theme.of(context).textTheme.labelBold,
        ),
        const SizedBox(height: 8),
        EmbeddedWheelPicker<double>(
          value: value,
          options: field.values
              .map((item) => PickerOption(item, field.labelFor(item)))
              .toList(),
          onSelected: onChanged,
        ),
      ],
    );
  }
}

class PickerOption<T> {
  const PickerOption(this.value, this.label);

  final T value;
  final String label;
}

class EmbeddedWheelPicker<T> extends StatefulWidget {
  const EmbeddedWheelPicker({
    required this.options,
    required this.value,
    required this.onSelected,
    this.height = 132,
    this.itemExtent = 44,
    super.key,
  });

  final List<PickerOption<T>> options;
  final T value;
  final ValueChanged<T> onSelected;
  final double height;
  final double itemExtent;

  @override
  State<EmbeddedWheelPicker<T>> createState() => _EmbeddedWheelPickerState<T>();
}

class _EmbeddedWheelPickerState<T> extends State<EmbeddedWheelPicker<T>> {
  late FixedExtentScrollController _controller;
  var _isSyncingController = false;

  int get _selectedIndex {
    final index = widget.options.indexWhere(
      (option) => option.value == widget.value,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void didUpdateWidget(covariant EmbeddedWheelPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _selectedIndex;
    if (_controller.hasClients && _controller.selectedItem != next) {
      _isSyncingController = true;
      _controller.jumpToItem(next);
      _isSyncingController = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Container(
                height: widget.itemExtent,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: brandRed.withValues(alpha: 0.24)),
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: widget.itemExtent,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.8,
              perspective: 0.002,
              overAndUnderCenterOpacity: 0.42,
              onSelectedItemChanged: (index) {
                final option = widget.options[index];
                if (_isSyncingController || option.value == widget.value) {
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || option.value == widget.value) {
                    return;
                  }
                  widget.onSelected(option.value);
                });
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.options.length,
                builder: (context, index) {
                  final option = widget.options[index];
                  final selected = option.value == widget.value;
                  return Center(
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? brandRedDark : textColor,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: selected ? 17 : 15,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrapResult {
  const TrapResult({
    required this.title,
    required this.rows,
    required this.explanation,
    this.isError = false,
  });

  final String title;
  final List<(String, String)> rows;
  final String explanation;
  final bool isError;
}

class TrapResultPanel extends StatelessWidget {
  const TrapResultPanel({required this.result, super.key});

  final TrapResult result;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Text(
          result.title,
          style: Theme.of(context).textTheme.titleMediumBold?.copyWith(
            color: result.isError ? brandRedDark : textColor,
          ),
        ),
        if (result.rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final row in result.rows)
            ResultRow(label: row.$1, value: row.$2),
        ],
        const SizedBox(height: 10),
        Text(
          result.explanation,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: result.isError ? brandRedDark : mutedColor,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class ResultRow extends StatelessWidget {
  const ResultRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.smallLabel),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

enum MessageType { info, success, warning, error }

class MessageBox extends StatelessWidget {
  const MessageBox({required this.type, required this.message, super.key});

  final MessageType type;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      MessageType.success => const Color(0xff167245),
      MessageType.warning => const Color(0xff8a5a00),
      MessageType.error => brandRedDark,
      MessageType.info => tealColor,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class UpdateAvailableDialog extends StatefulWidget {
  const UpdateAvailableDialog({required this.notice, super.key});

  final AppUpdateNotice notice;

  @override
  State<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<UpdateAvailableDialog> {
  String _message = '';
  var _isOpening = false;

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final canOpenUpdateLink = _canOpenUpdateLink(notice.updateUrl);
    return PopScope(
      canPop: !notice.forceUpdate || !canOpenUpdateLink,
      child: AlertDialog(
        title: const Text('Actualizacion disponible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notice.message),
            const SizedBox(height: 12),
            Text(
              'Instalada: ${notice.currentVersion}\nDisponible: ${notice.latestVersion}+${notice.latestBuildNumber}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: mutedColor),
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _message,
                style: const TextStyle(
                  color: brandRedDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!notice.forceUpdate || !canOpenUpdateLink)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Despues'),
            ),
          FilledButton.icon(
            onPressed: _isOpening ? null : _openUpdateUrl,
            icon: Icon(kIsWeb ? Icons.refresh : Icons.open_in_new),
            label: Text(
              _isOpening
                  ? (kIsWeb ? 'Recargando...' : 'Abriendo...')
                  : (kIsWeb ? 'Recargar ahora' : 'Actualizar'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpdateUrl() async {
    final updateUrl = widget.notice.updateUrl;
    final uri = Uri.tryParse(updateUrl);
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _message =
            'La ruta de actualizacion no esta configurada en Firebase todavia.';
      });
      return;
    }

    setState(() {
      _isOpening = true;
      _message = '';
    });
    final opened = kIsWeb
        ? await launchUrl(
            uri.replace(
              queryParameters: {
                ...uri.queryParameters,
                'build': '${widget.notice.latestBuildNumber}',
              },
            ),
            webOnlyWindowName: '_self',
          )
        : await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) {
      return;
    }
    setState(() => _isOpening = false);
    if (!opened) {
      setState(() {
        _message = 'No pude abrir el enlace de actualizacion.';
      });
    }
  }

  static bool _canOpenUpdateLink(String updateUrl) {
    final uri = Uri.tryParse(updateUrl);
    return uri != null && uri.hasScheme;
  }
}

class BarePipeAdminTab extends StatelessWidget {
  const BarePipeAdminTab({
    required this.reports,
    required this.isLoading,
    super.key,
  });

  final List<BarePipeReport> reports;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final totals = _AdminTotals.fromReports(reports);
    final groups = AdminGroup.fromReports(reports);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLoading) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
        ],
        MetricGrid(
          metrics: [
            Metric('Reportes', Formats.noDecimal(reports.length.toDouble())),
            Metric('Calor disipado', '${Formats.two(totals.heatKw)} kW'),
            Metric(
              'Energia mensual',
              '${Formats.noDecimal(totals.energyKwhMonth)} kWh',
            ),
            Metric('Dinero perdido', '${Formats.usd(totals.monthlyUsd)}/mes'),
          ],
        ),
        const SizedBox(height: 14),
        ChartPanel(
          title: 'Calor reportado por seccion',
          groups: groups,
          valueFor: (group) => group.heatKw,
          formatValue: (value) => '${Formats.two(value)} kW',
          emptyText: 'Todavia no hay reportes ingresados.',
        ),
        const SizedBox(height: 14),
        ChartPanel(
          title: 'Dinero perdido por seccion',
          groups: groups,
          valueFor: (group) => group.monthlyUsd,
          formatValue: (value) => '${Formats.usd(value)}/mes',
          emptyText: 'Todavia no hay reportes ingresados.',
        ),
        const SizedBox(height: 14),
        RecentReportsPanel(reports: reports),
      ],
    );
  }
}

class LeakAdminTab extends StatelessWidget {
  const LeakAdminTab({
    required this.reports,
    required this.isLoading,
    super.key,
  });

  final List<MaintenanceReportSummary> reports;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final open = reports.where((item) => !item.workOrderCreated).length;
    final withOrder = reports
        .where((item) => item.workOrderCreated && !item.workCompleted)
        .length;
    final completed = reports.where((item) => item.workCompleted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLoading) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
        ],
        MetricGrid(
          metrics: [
            Metric('Reportadas', reports.length.toString()),
            Metric('Sin OT', open.toString()),
            Metric('Con OT', withOrder.toString()),
            Metric('Ejecutadas', completed.toString()),
          ],
        ),
        const SizedBox(height: 14),
        InfoPanel(
          children: [
            Text(
              'Ultimas fugas reportadas',
              style: Theme.of(context).textTheme.titleMediumBold,
            ),
            const SizedBox(height: 12),
            if (reports.isEmpty)
              const EmptyState(
                text: 'Las fugas apareceran aqui cuando sean reportadas.',
              )
            else
              for (final report in reports.take(12)) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReportThumbnail(url: report.photoUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.sectionName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(report.detail),
                          if (report.equipmentName.isNotEmpty)
                            Text(
                              report.equipmentName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            report.workCompleted
                                ? 'Trabajo ejecutado'
                                : report.workOrderCreated
                                ? 'OT generada'
                                : 'Pendiente de OT',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: report.workCompleted
                                      ? tealColor
                                      : brandRedDark,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
              ],
          ],
        ),
      ],
    );
  }
}

class ConsumptionAdminTab extends StatelessWidget {
  const ConsumptionAdminTab({
    required this.readings,
    required this.isLoading,
    required this.selectedBoiler,
    required this.scale,
    required this.onBoilerChanged,
    required this.onScaleChanged,
    super.key,
  });

  final List<BoilerReading> readings;
  final bool isLoading;
  final String selectedBoiler;
  final ConsumptionScale scale;
  final ValueChanged<String> onBoilerChanged;
  final ValueChanged<ConsumptionScale> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    final series = _ConsumptionSeries.fromReadings(
      readings,
      boilerName: selectedBoiler,
      scale: scale,
    );
    final totals = _ConsumptionTotals.fromPoints(series.points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLoading) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
        ],
        ConsumptionFilterPanel(
          selectedBoiler: selectedBoiler,
          scale: scale,
          onBoilerChanged: onBoilerChanged,
          onScaleChanged: onScaleChanged,
        ),
        const SizedBox(height: 14),
        MetricGrid(
          metrics: [
            Metric(
              'Lecturas',
              Formats.noDecimal(series.readingCount.toDouble()),
            ),
            Metric('Combustible', '${Formats.two(totals.fuel)} unid.'),
            Metric('Agua', '${Formats.two(totals.water)} unid.'),
            Metric('Vapor', '${Formats.two(totals.steam)} unid.'),
          ],
        ),
        const SizedBox(height: 14),
        _TimeSeriesChartPanel(
          title: 'Consumo combustible vs tiempo',
          points: series.points,
          valueFor: (point) => point.fuel,
          color: brandRed,
          emptyText: 'Todavia no hay consumos calculados de combustible.',
        ),
        const SizedBox(height: 14),
        _TimeSeriesChartPanel(
          title: 'Consumo agua vs tiempo',
          points: series.points,
          valueFor: (point) => point.water,
          color: tealColor,
          emptyText: 'Todavia no hay consumos calculados de agua.',
        ),
        const SizedBox(height: 14),
        RecentBoilerReadingsPanel(readings: series.filteredReadings),
      ],
    );
  }
}

class ConsumptionFilterPanel extends StatelessWidget {
  const ConsumptionFilterPanel({
    required this.selectedBoiler,
    required this.scale,
    required this.onBoilerChanged,
    required this.onScaleChanged,
    super.key,
  });

  final String selectedBoiler;
  final ConsumptionScale scale;
  final ValueChanged<String> onBoilerChanged;
  final ValueChanged<ConsumptionScale> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Text(
          'Filtros de consumo',
          style: Theme.of(context).textTheme.titleMediumBold,
        ),
        const SizedBox(height: 12),
        Text('Caldera', style: Theme.of(context).textTheme.smallLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: selectedBoiler.isEmpty,
              onSelected: (_) => onBoilerChanged(''),
            ),
            for (final boiler in boilerNames)
              ChoiceChip(
                label: Text(boiler.replaceFirst('Caldera ', '')),
                selected: selectedBoiler == boiler,
                onSelected: (_) => onBoilerChanged(boiler),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Escala de tiempo', style: Theme.of(context).textTheme.smallLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in ConsumptionScale.values)
              ChoiceChip(
                label: Text(item.label),
                selected: scale == item,
                onSelected: (_) => onScaleChanged(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimeSeriesChartPanel extends StatelessWidget {
  const _TimeSeriesChartPanel({
    required this.title,
    required this.points,
    required this.valueFor,
    required this.color,
    required this.emptyText,
  });

  final String title;
  final List<_ConsumptionPoint> points;
  final double Function(_ConsumptionPoint point) valueFor;
  final Color color;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final visiblePoints = points.length > 18
        ? points.sublist(points.length - 18)
        : points;
    final values = visiblePoints.map(valueFor).toList();
    final maxValue = values.fold<double>(0, math.max);

    return InfoPanel(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMediumBold),
        const SizedBox(height: 12),
        if (visiblePoints.isEmpty)
          EmptyState(text: emptyText)
        else if (maxValue <= 0)
          EmptyState(
            text:
                'Hay lecturas guardadas, pero falta una lectura anterior para calcular consumos.',
          )
        else ...[
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _TimeSeriesChartPainter(
                values: values,
                labels: visiblePoints
                    .map((point) => point.label)
                    .toList(growable: false),
                color: color,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ultimo valor: ${Formats.two(values.last)} unid.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeSeriesChartPainter extends CustomPainter {
  const _TimeSeriesChartPainter({
    required this.values,
    required this.labels,
    required this.color,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    const left = 48.0;
    const top = 14.0;
    const right = 12.0;
    const bottom = 34.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxValue = values.fold<double>(0, math.max);
    if (maxValue <= 0 || chart.width <= 0 || chart.height <= 0) {
      return;
    }

    final gridPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = mutedColor.withValues(alpha: 0.34)
      ..strokeWidth = 1.2;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var index = 0; index <= 4; index += 1) {
      final y = chart.top + chart.height * index / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, axisPaint);

    final points = <Offset>[];
    for (var index = 0; index < values.length; index += 1) {
      final fraction = values.length == 1 ? 0.5 : index / (values.length - 1);
      final x = chart.left + chart.width * fraction;
      final y = chart.bottom - chart.height * (values[index] / maxValue);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 4.2, pointPaint);
      canvas.drawCircle(point, 4.2, pointBorderPaint);
    }

    _drawText(canvas, Offset(0, chart.top - 5), Formats.two(maxValue), 11);
    _drawText(
      canvas,
      Offset(0, chart.center.dy - 7),
      Formats.two(maxValue / 2),
      11,
    );
    _drawText(canvas, Offset(0, chart.bottom - 13), '0', 11);

    final labelIndexes = _labelIndexes(values.length);
    for (final index in labelIndexes) {
      final point = points[index];
      _drawCenteredText(
        canvas,
        Offset(point.dx, chart.bottom + 8),
        labels[index],
        11,
      );
    }
  }

  Set<int> _labelIndexes(int length) {
    if (length <= 6) {
      return {for (var index = 0; index < length; index += 1) index};
    }
    return {0, length ~/ 2, length - 1};
  }

  void _drawText(Canvas canvas, Offset offset, String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: mutedColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 44);
    painter.paint(canvas, offset);
  }

  void _drawCenteredText(
    Canvas canvas,
    Offset anchor,
    String text,
    double fontSize,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: mutedColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 92);
    painter.paint(canvas, Offset(anchor.dx - painter.width / 2, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _TimeSeriesChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.color != color;
  }
}

class Metric {
  const Metric(this.label, this.value);

  final String label;
  final String value;
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({required this.metrics, super.key});

  final List<Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 4 ? 1.35 : 1.55,
          ),
          itemBuilder: (context, index) => MetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({required this.metric, super.key});

  final Metric metric;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(metric.label, style: Theme.of(context).textTheme.smallLabel),
            const SizedBox(height: 8),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                metric.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartPanel extends StatelessWidget {
  const ChartPanel({
    required this.title,
    required this.groups,
    required this.valueFor,
    required this.formatValue,
    required this.emptyText,
    super.key,
  });

  final String title;
  final List<AdminGroup> groups;
  final double Function(AdminGroup group) valueFor;
  final String Function(double value) formatValue;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final maxValue = groups.fold<double>(
      0,
      (max, group) => math.max(max, valueFor(group)),
    );

    return InfoPanel(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMediumBold),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          EmptyState(text: emptyText)
        else if (maxValue <= 0)
          const EmptyState(
            text:
                'Hay reportes guardados, pero faltan diametro, presion o longitud para calcular perdidas.',
          )
        else
          for (final group in groups.where((group) => valueFor(group) > 0)) ...[
            BarRow(
              label: group.name,
              value: formatValue(valueFor(group)),
              count: group.count,
              percent: valueFor(group) / maxValue,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class BarRow extends StatelessWidget {
  const BarRow({
    required this.label,
    required this.value,
    required this.count,
    required this.percent,
    super.key,
  });

  final String label;
  final String value;
  final int count;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: math.max(0.06, percent),
            minHeight: 10,
            backgroundColor: const Color(0xffedf2f3),
            color: brandRed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count ${count == 1 ? 'reporte' : 'reportes'}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
      ],
    );
  }
}

class RecentReportsPanel extends StatelessWidget {
  const RecentReportsPanel({required this.reports, super.key});

  final List<BarePipeReport> reports;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Text(
          'Ultimos reportes',
          style: Theme.of(context).textTheme.titleMediumBold,
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          const EmptyState(
            text:
                'Los reportes apareceran aqui cuando el equipo ingrese evidencias.',
          )
        else
          for (final report in reports.take(8)) ...[
            RecentReportTile(report: report),
            const Divider(height: 18),
          ],
      ],
    );
  }
}

class RecentReportTile extends StatelessWidget {
  const RecentReportTile({required this.report, super.key});

  final BarePipeReport report;

  @override
  Widget build(BuildContext context) {
    final calculation = report.calculation;
    final lossText = calculation.isCalculated
        ? '${Formats.two(calculation.heatLossKw)} kW - ${Formats.usd(calculation.monthlyUsd)}/mes'
        : 'Pendiente de datos para calculo';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 92,
            height: 74,
            child: Image.network(
              report.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xffedf2f3),
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.section.isEmpty ? 'Sin seccion' : report.section,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                Formats.date(report.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
              const SizedBox(height: 4),
              Text(
                _formatReportDetails(report),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(lossText, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  String _formatReportDetails(BarePipeReport report) {
    final parts = <String>[];
    if (report.diameterLabel.isNotEmpty) {
      parts.add('Diametro ${report.diameterLabel}');
    }
    if (report.pressureBarG != null) {
      parts.add('${Formats.one(report.pressureBarG!)} bar(g)');
    }
    if (report.lengthMeters != null) {
      parts.add('${Formats.two(report.lengthMeters!)} m');
    }
    return parts.isEmpty ? 'Datos tecnicos pendientes' : parts.join(' - ');
  }
}

class RecentBoilerReadingsPanel extends StatelessWidget {
  const RecentBoilerReadingsPanel({required this.readings, super.key});

  final List<BoilerReading> readings;

  @override
  Widget build(BuildContext context) {
    final sorted = [...readings]
      ..sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
    return InfoPanel(
      children: [
        Text(
          'Ultimas lecturas',
          style: Theme.of(context).textTheme.titleMediumBold,
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const EmptyState(
            text:
                'Las lecturas de caldera apareceran aqui cuando se ingresen consumos.',
          )
        else
          for (final reading in sorted.take(8)) ...[
            RecentBoilerReadingTile(reading: reading),
            const Divider(height: 18),
          ],
      ],
    );
  }
}

class RecentBoilerReadingTile extends StatelessWidget {
  const RecentBoilerReadingTile({required this.reading, super.key});

  final BoilerReading reading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: brandRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.local_fire_department, color: brandRed),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reading.boilerName,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${Formats.date(reading.recordedAt)} - ${reading.createdByNameSnapshot.isEmpty ? 'Registro historico' : reading.createdByNameSnapshot}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
              const SizedBox(height: 4),
              Text(
                _formatReadingTotals(reading),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                _formatReadingConsumption(reading),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatReadingTotals(BoilerReading reading) {
    final parts = [
      'Comb. total ${Formats.two(reading.fuelTotal)}',
      'Agua total ${Formats.two(reading.waterTotal)}',
    ];
    if (reading.steamTotal != null) {
      parts.add('Vapor total ${Formats.two(reading.steamTotal!)}');
    }
    return parts.join(' - ');
  }

  String _formatReadingConsumption(BoilerReading reading) {
    final parts = <String>[];
    if (reading.fuelConsumption != null) {
      parts.add('comb. ${Formats.two(reading.fuelConsumption!)}');
    }
    if (reading.waterConsumption != null) {
      parts.add('agua ${Formats.two(reading.waterConsumption!)}');
    }
    if (reading.steamConsumption != null) {
      parts.add('vapor ${Formats.two(reading.steamConsumption!)}');
    }
    return parts.isEmpty
        ? 'Consumo pendiente de lectura anterior'
        : 'Consumo: ${parts.join(' - ')} unid.';
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: mutedColor, height: 1.4),
    );
  }
}

class _AdminTotals {
  const _AdminTotals({
    required this.heatKw,
    required this.energyKwhMonth,
    required this.monthlyUsd,
  });

  factory _AdminTotals.fromReports(List<BarePipeReport> reports) {
    var heatKw = 0.0;
    var energyKwhMonth = 0.0;
    var monthlyUsd = 0.0;
    for (final report in reports) {
      heatKw += report.calculation.heatLossKw;
      energyKwhMonth += report.calculation.energyKwhMonth;
      monthlyUsd += report.calculation.monthlyUsd;
    }
    return _AdminTotals(
      heatKw: heatKw,
      energyKwhMonth: energyKwhMonth,
      monthlyUsd: monthlyUsd,
    );
  }

  final double heatKw;
  final double energyKwhMonth;
  final double monthlyUsd;
}

class AdminGroup {
  const AdminGroup({
    required this.name,
    required this.count,
    required this.heatKw,
    required this.monthlyUsd,
  });

  static List<AdminGroup> fromReports(List<BarePipeReport> reports) {
    final groups = <String, _AdminGroupAccumulator>{};
    for (final report in reports) {
      final name = report.section.isEmpty ? 'Sin seccion' : report.section;
      final group = groups.putIfAbsent(
        name,
        () => _AdminGroupAccumulator(name),
      );
      group.count += 1;
      group.heatKw += report.calculation.heatLossKw;
      group.monthlyUsd += report.calculation.monthlyUsd;
    }
    final result = groups.values
        .map(
          (group) => AdminGroup(
            name: group.name,
            count: group.count,
            heatKw: group.heatKw,
            monthlyUsd: group.monthlyUsd,
          ),
        )
        .toList();
    result.sort((left, right) => right.monthlyUsd.compareTo(left.monthlyUsd));
    return result;
  }

  final String name;
  final int count;
  final double heatKw;
  final double monthlyUsd;
}

class _AdminGroupAccumulator {
  _AdminGroupAccumulator(this.name);

  final String name;
  int count = 0;
  double heatKw = 0;
  double monthlyUsd = 0;
}

class _ConsumptionSeries {
  const _ConsumptionSeries({
    required this.points,
    required this.filteredReadings,
    required this.readingCount,
  });

  factory _ConsumptionSeries.fromReadings(
    List<BoilerReading> readings, {
    required String boilerName,
    required ConsumptionScale scale,
  }) {
    final sorted = [...readings]
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    final previousByBoiler = <String, BoilerReading>{};
    final buckets = <DateTime, _ConsumptionBucket>{};
    final filteredReadings = <BoilerReading>[];

    for (final reading in sorted) {
      final previous = previousByBoiler[reading.boilerName];
      final fuel =
          reading.fuelConsumption ??
          _positiveDelta(reading.fuelTotal, previous?.fuelTotal);
      final water =
          reading.waterConsumption ??
          _positiveDelta(reading.waterTotal, previous?.waterTotal);
      final steam =
          reading.steamConsumption ??
          _positiveDelta(reading.steamTotal, previous?.steamTotal);
      previousByBoiler[reading.boilerName] = reading;

      if (boilerName.isNotEmpty && reading.boilerName != boilerName) {
        continue;
      }

      filteredReadings.add(reading);
      final bucketStart = _bucketFor(reading.recordedAt, scale);
      final bucket = buckets.putIfAbsent(
        bucketStart,
        () => _ConsumptionBucket(bucketStart),
      );
      bucket.count += 1;
      bucket.fuel += fuel ?? 0;
      bucket.water += water ?? 0;
      bucket.steam += steam ?? 0;
    }

    final points = buckets.values
        .map(
          (bucket) => _ConsumptionPoint(
            bucket: bucket.bucket,
            label: _labelForBucket(bucket.bucket, scale),
            count: bucket.count,
            fuel: bucket.fuel,
            water: bucket.water,
            steam: bucket.steam,
          ),
        )
        .toList();
    points.sort((left, right) => left.bucket.compareTo(right.bucket));
    filteredReadings.sort(
      (left, right) => right.recordedAt.compareTo(left.recordedAt),
    );

    return _ConsumptionSeries(
      points: points,
      filteredReadings: filteredReadings,
      readingCount: filteredReadings.length,
    );
  }

  final List<_ConsumptionPoint> points;
  final List<BoilerReading> filteredReadings;
  final int readingCount;

  static double? _positiveDelta(double? current, double? previous) {
    if (current == null || previous == null) {
      return null;
    }
    final delta = current - previous;
    return delta < 0 ? null : delta;
  }

  static DateTime _bucketFor(DateTime value, ConsumptionScale scale) {
    final local = value.toLocal();
    return switch (scale) {
      ConsumptionScale.hour => DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
      ),
      ConsumptionScale.day => DateTime(local.year, local.month, local.day),
      ConsumptionScale.week => DateTime(
        local.year,
        local.month,
        local.day,
      ).subtract(Duration(days: local.weekday - 1)),
      ConsumptionScale.month => DateTime(local.year, local.month),
      ConsumptionScale.year => DateTime(local.year),
    };
  }

  static String _labelForBucket(DateTime value, ConsumptionScale scale) {
    return switch (scale) {
      ConsumptionScale.hour =>
        '${_twoDigits(value.day)}/${_twoDigits(value.month)} ${_twoDigits(value.hour)}:00',
      ConsumptionScale.day =>
        '${_twoDigits(value.day)}/${_twoDigits(value.month)}',
      ConsumptionScale.week =>
        'Sem ${_twoDigits(value.day)}/${_twoDigits(value.month)}',
      ConsumptionScale.month =>
        '${_twoDigits(value.month)}/${value.year.toString()}',
      ConsumptionScale.year => value.year.toString(),
    };
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _ConsumptionBucket {
  _ConsumptionBucket(this.bucket);

  final DateTime bucket;
  int count = 0;
  double fuel = 0;
  double water = 0;
  double steam = 0;
}

class _ConsumptionPoint {
  const _ConsumptionPoint({
    required this.bucket,
    required this.label,
    required this.count,
    required this.fuel,
    required this.water,
    required this.steam,
  });

  final DateTime bucket;
  final String label;
  final int count;
  final double fuel;
  final double water;
  final double steam;
}

class _ConsumptionTotals {
  const _ConsumptionTotals({
    required this.fuel,
    required this.water,
    required this.steam,
  });

  factory _ConsumptionTotals.fromPoints(List<_ConsumptionPoint> points) {
    var fuel = 0.0;
    var water = 0.0;
    var steam = 0.0;
    for (final point in points) {
      fuel += point.fuel;
      water += point.water;
      steam += point.steam;
    }
    return _ConsumptionTotals(fuel: fuel, water: water, steam: steam);
  }

  final double fuel;
  final double water;
  final double steam;
}

class Formats {
  static final _noDecimal = NumberFormat('#,##0', 'es_EC');
  static final _oneDecimal = NumberFormat('#,##0.0', 'es_EC');
  static final _twoDecimals = NumberFormat('#,##0.00', 'es_EC');
  static final _usd = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  );

  static String noDecimal(double value) => _noDecimal.format(value);
  static String one(double value) => _oneDecimal.format(value);
  static String two(double value) => _twoDecimals.format(value);
  static String usd(double value) => _usd.format(value);

  static String date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

extension ConsumptionScaleLabels on ConsumptionScale {
  String get label {
    return switch (this) {
      ConsumptionScale.hour => 'Hora',
      ConsumptionScale.day => 'Dia',
      ConsumptionScale.week => 'Semana',
      ConsumptionScale.month => 'Mes',
      ConsumptionScale.year => 'Ano',
    };
  }
}

extension AppTextStyles on TextTheme {
  TextStyle? get titleMediumBold =>
      titleMedium?.copyWith(fontWeight: FontWeight.w900, color: textColor);

  TextStyle? get labelBold =>
      labelLarge?.copyWith(fontWeight: FontWeight.w800, color: textColor);

  TextStyle? get smallLabel =>
      labelSmall?.copyWith(color: mutedColor, fontWeight: FontWeight.w800);
}
