import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';

import 'domain/bare_pipe.dart';
import 'domain/boiler_consumption.dart';
import 'domain/trap_sizing.dart';
import 'firebase_options.dart';
import 'services/cloudinary_service.dart';
import 'services/consumption_store.dart';
import 'services/deferred_firestore_consumption_store.dart';
import 'services/deferred_firestore_report_store.dart';
import 'services/report_store.dart';

const brandRed = Color(0xffe3263a);
const brandRedDark = Color(0xffb8192a);
const pageColor = Color(0xfff5f7f8);
const textColor = Color(0xff20272b);
const mutedColor = Color(0xff5b6970);
const borderColor = Color(0xffdae2e5);
const tealColor = Color(0xff2f6f73);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  firebaseReady.ignore();
  final localStore = LocalReportStore();
  final localConsumptionStore = LocalConsumptionStore();
  runApp(
    EeApp(
      reportStore: HybridReportStore(
        localStore: localStore,
        remoteStore: DeferredFirestoreReportStore(firebaseReady: firebaseReady),
      ),
      consumptionStore: HybridConsumptionStore(
        localStore: localConsumptionStore,
        remoteStore: DeferredFirestoreConsumptionStore(
          firebaseReady: firebaseReady,
        ),
        remoteTimeout: const Duration(seconds: 35),
      ),
      cloudinaryService: CloudinaryService(),
    ),
  );
}

class EeApp extends StatelessWidget {
  const EeApp({
    required this.reportStore,
    required this.consumptionStore,
    required this.cloudinaryService,
    super.key,
  });

  final ReportStore reportStore;
  final ConsumptionStore consumptionStore;
  final CloudinaryService cloudinaryService;

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
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({
    required this.reportStore,
    required this.consumptionStore,
    required this.cloudinaryService,
    super.key,
  });

  final ReportStore reportStore;
  final ConsumptionStore consumptionStore;
  final CloudinaryService cloudinaryService;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  var _showSplash = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 950), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
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
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.reportStore,
    required this.consumptionStore,
    required this.cloudinaryService,
    super.key,
  });

  final ReportStore reportStore;
  final ConsumptionStore consumptionStore;
  final CloudinaryService cloudinaryService;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      children: [
        const EeHeader(
          title: 'Eficiencia Energetica EE',
          subtitle: 'Herramientas de campo para gestion energetica.',
        ),
        const SizedBox(height: 18),
        Text('Modulos', style: Theme.of(context).textTheme.titleMediumBold),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.tune,
          label: 'Dimensionamiento de trampas',
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TrapSizingScreen()));
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
                  reportStore: reportStore,
                  cloudinaryService: cloudinaryService,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.local_fire_department_outlined,
          label: 'Ingresar consumos',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ConsumptionEntryScreen(consumptionStore: consumptionStore),
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
                  reportStore: reportStore,
                  consumptionStore: consumptionStore,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class TrapSizingScreen extends StatefulWidget {
  const TrapSizingScreen({super.key});

  @override
  State<TrapSizingScreen> createState() => _TrapSizingScreenState();
}

class _TrapSizingScreenState extends State<TrapSizingScreen> {
  final _rules = createTrapRules();
  final _values = <String, double>{};
  TrapRule? _selectedRule;
  TrapResult? _result;
  var _estimateIndirectly = false;

  @override
  Widget build(BuildContext context) {
    final selectedRule = _selectedRule;
    final fields = _activeFields();

    return AppShell(
      children: [
        const BackToHomeButton(),
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
                      _result = null;
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
        if (_result != null) ...[
          const SizedBox(height: 14),
          TrapResultPanel(result: _result!),
        ],
      ],
    );
  }

  void _selectRule(TrapRule? rule) {
    setState(() {
      _selectedRule = rule;
      _estimateIndirectly = false;
      _result = null;
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
      _result = null;
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

  void _calculate() {
    final rule = _selectedRule;
    if (rule == null) return;

    if (!rule.requiresSizing) {
      setState(() {
        _result = TrapResult(
          title: 'Resumen de trampa requerida',
          rows: [('Uso', rule.name), ('Tipo recomendado', rule.trapType)],
          explanation: rule.calculate(_values).explanation,
        );
      });
      return;
    }

    late TrapCalculation calculation;
    if (_estimateIndirectly) {
      calculation = rule.calculate(_values);
    } else {
      final directCondensateLMin = _values['directCondensate'] ?? 0;
      if (directCondensateLMin <= 0) {
        setState(() {
          _result = const TrapResult(
            title: 'Falta el caudal',
            rows: [],
            explanation:
                'Ingresa el caudal de condensado a desalojar o marca "No conozco la cantidad de condensado".',
            isError: true,
          );
        });
        return;
      }
      final directCondensateKgH =
          directCondensateLMin * TrapConstants.condensateDensityKgL * 60;
      calculation = TrapCalculation(
        condensateKgH: directCondensateKgH,
        explanation:
            'Medicion directa de ${Formats.one(directCondensateLMin)} L/min, convertida con densidad aproximada de condensado de 1.0 kg/L.',
      );
    }

    final recommendedCapacity = calculation.condensateKgH * rule.safetyFactor;
    final pressure = math.max(0.0, _values['steamPressure'] ?? 0);
    final rows = <(String, String)>[
      ('Uso', rule.name),
      ('Tipo recomendado', rule.trapType),
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
      (
        'Diametro preliminar sugerido',
        recommendTrapConnectionDiameter(recommendedCapacity),
      ),
    ];
    if (pressure > 0) {
      rows.add((
        'Presion de vapor considerada',
        '${Formats.one(pressure)} bar(g)',
      ));
    }

    setState(() {
      _result = TrapResult(
        title: 'Resumen de trampa requerida',
        rows: rows,
        explanation:
            '${calculation.explanation}\n\nResultado preliminar para seleccion inicial. Para compra se debe validar contra presion diferencial, contrapresion, orificio interno, material, conexiones y tabla del fabricante.',
      );
    });
  }
}

class BarePipeReportScreen extends StatefulWidget {
  const BarePipeReportScreen({
    required this.reportStore,
    required this.cloudinaryService,
    super.key,
  });

  final ReportStore reportStore;
  final CloudinaryService cloudinaryService;

  @override
  State<BarePipeReportScreen> createState() => _BarePipeReportScreenState();
}

class _BarePipeReportScreenState extends State<BarePipeReportScreen> {
  final _picker = ImagePicker();
  final _lengthController = TextEditingController();
  Uint8List? _photoBytes;
  String _section = '';
  String _diameter = '';
  String _pressure = '';
  String _message = '';
  MessageType _messageType = MessageType.info;
  var _isSubmitting = false;

  @override
  void dispose() {
    _lengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      children: [
        const BackToHomeButton(),
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
          value: _section,
          options: [
            const PickerOption('', 'Sin dato'),
            ...barePipeSections.map(
              (section) => PickerOption(section, section),
            ),
          ],
          onSelected: (value) => setState(() => _section = value),
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
          onSelected: (value) => setState(() => _diameter = value),
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
          onSelected: (value) => setState(() => _pressure = value),
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
        ),
        const SizedBox(height: 16),
        EeActionButton(
          icon: Icons.cloud_upload_outlined,
          label: _isSubmitting ? 'Ingresando reporte...' : 'Ingresar reporte',
          onPressed: _isSubmitting ? null : _submitReport,
        ),
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
      _message = '';
    });
  }

  Future<void> _submitReport() async {
    final photoBytes = _photoBytes;
    if (photoBytes == null) {
      _setMessage(
        MessageType.error,
        'Captura una foto antes de ingresar el reporte.',
      );
      return;
    }

    final lengthText = _lengthController.text.trim();
    final lengthMeters = _parseOptionalNumber(lengthText);
    if (lengthText.isNotEmpty && (lengthMeters == null || lengthMeters <= 0)) {
      _setMessage(
        MessageType.error,
        'La longitud debe quedar en blanco o ser mayor a cero.',
      );
      return;
    }

    final pressureBarG = _pressure.isEmpty ? null : double.tryParse(_pressure);
    final reportId = _createReportId();
    setState(() {
      _isSubmitting = true;
      _messageType = MessageType.info;
      _message = 'Subiendo evidencia...';
    });

    try {
      final upload = await widget.cloudinaryService.uploadEvidence(
        bytes: photoBytes,
        reportId: reportId,
      );
      final calculation = BarePipeCalculator.calculate(
        diameterLabel: _diameter,
        pressureBarG: pressureBarG,
        lengthMeters: lengthMeters,
      );
      final report = BarePipeReport(
        id: reportId,
        createdAt: DateTime.now(),
        section: _section,
        diameterLabel: _diameter,
        pressureBarG: pressureBarG,
        lengthMeters: lengthMeters,
        photoUrl: upload.secureUrl,
        photoPublicId: upload.publicId,
        calculation: calculation,
      );
      if (!mounted) return;
      setState(() {
        _message = 'Evidencia subida. Guardando reporte...';
      });
      await widget.reportStore.saveReport(report);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _photoBytes = null;
        _section = '';
        _diameter = '';
        _pressure = '';
        _lengthController.clear();
        _messageType = MessageType.success;
        _message = calculation.isCalculated
            ? 'Reporte ingresado: ${Formats.two(calculation.heatLossKw)} kW y ${Formats.usd(calculation.monthlyUsd)}/mes estimados.'
            : 'Reporte ingresado. Quedo pendiente el calculo porque falta diametro, presion o longitud.';
      });
    } on ReportSyncException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _photoBytes = null;
        _section = '';
        _diameter = '';
        _pressure = '';
        _lengthController.clear();
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

class ConsumptionEntryScreen extends StatefulWidget {
  const ConsumptionEntryScreen({required this.consumptionStore, super.key});

  final ConsumptionStore consumptionStore;

  @override
  State<ConsumptionEntryScreen> createState() => _ConsumptionEntryScreenState();
}

class _ConsumptionEntryScreenState extends State<ConsumptionEntryScreen> {
  final _fuelController = TextEditingController();
  final _waterController = TextEditingController();
  final _steamController = TextEditingController();
  final _pinController = TextEditingController();
  String _boilerName = boilerNames.first;
  String _message = '';
  MessageType _messageType = MessageType.info;
  var _isSubmitting = false;

  @override
  void dispose() {
    _fuelController.dispose();
    _waterController.dispose();
    _steamController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readsSteam = _boilerName == alfaLavalBoiler;
    return AppShell(
      children: [
        const BackToHomeButton(),
        const EeHeader(
          title: 'Ingresar consumos',
          subtitle: 'Registro horario de agua, combustible y vapor.',
        ),
        const SizedBox(height: 14),
        InfoPanel(
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
            const SizedBox(height: 16),
            _buildNumberField(
              controller: _fuelController,
              label: 'Lectura total flujometro combustible',
              suffix: 'unid.',
            ),
            const SizedBox(height: 14),
            _buildNumberField(
              controller: _waterController,
              label: 'Lectura total flujometro agua',
              suffix: 'unid.',
            ),
            const SizedBox(height: 14),
            _buildNumberField(
              controller: _steamController,
              label: 'Lectura total vapor',
              suffix: 'unid.',
              enabled: readsSteam && !_isSubmitting,
              hintText: readsSteam ? '0.0' : 'Solo Alfa Laval 1200',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pinController,
              enabled: !_isSubmitting,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN calderista',
                hintText: '0000',
                counterText: '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        EeActionButton(
          icon: Icons.save_outlined,
          label: _isSubmitting ? 'Guardando lectura...' : 'Ingresar consumo',
          onPressed: _isSubmitting ? null : _submitReading,
        ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
      ],
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    bool enabled = true,
    String hintText = '0.0',
  }) {
    return TextField(
      controller: controller,
      enabled: enabled && !_isSubmitting,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixText: suffix,
      ),
    );
  }

  void _selectBoiler(String value) {
    setState(() {
      _boilerName = value;
      if (_boilerName != alfaLavalBoiler) {
        _steamController.clear();
      }
    });
  }

  Future<void> _submitReading() async {
    final fuelTotal = _parseRequiredNumber(_fuelController.text, 'combustible');
    if (fuelTotal == null) {
      return;
    }
    final waterTotal = _parseRequiredNumber(_waterController.text, 'agua');
    if (waterTotal == null) {
      return;
    }

    final steamText = _steamController.text.trim();
    final steamTotal = steamText.isEmpty
        ? null
        : _parseRequiredNumber(steamText, 'vapor');
    if (steamText.isNotEmpty && steamTotal == null) {
      return;
    }

    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      _setMessage(MessageType.error, 'Ingresa el PIN de 4 numeros.');
      return;
    }

    final now = DateTime.now();
    final rawReading = BoilerReading(
      id: _createReadingId(),
      recordedAt: now,
      createdAt: now,
      boilerName: _boilerName,
      fuelTotal: fuelTotal,
      waterTotal: waterTotal,
      steamTotal: _boilerName == alfaLavalBoiler ? steamTotal : null,
      operatorPin: pin,
      fuelConsumption: null,
      waterConsumption: null,
      steamConsumption: null,
    );

    setState(() {
      _isSubmitting = true;
      _messageType = MessageType.info;
      _message = 'Calculando consumo y guardando lectura...';
    });

    BoilerReading? reading;
    try {
      final existing = await widget.consumptionStore.loadReadings();
      reading = BoilerConsumptionCalculator.attachDeltas(rawReading, existing);
      await widget.consumptionStore.saveReading(reading);
      if (!mounted) {
        return;
      }
      _finishSubmission(
        MessageType.success,
        'Lectura ingresada. ${_formatReadingDelta(reading)}',
      );
    } on ConsumptionSyncException catch (error) {
      if (!mounted) {
        return;
      }
      final detail = reading == null ? '' : '\n${_formatReadingDelta(reading)}';
      _finishSubmission(MessageType.warning, '${error.message}$detail');
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

  double? _parseRequiredNumber(String raw, String label) {
    final normalized = raw.replaceAll(',', '.').trim();
    final value = double.tryParse(normalized);
    if (value == null || value < 0) {
      _setMessage(
        MessageType.error,
        'La lectura de $label debe ser un numero mayor o igual a cero.',
      );
      return null;
    }
    return value;
  }

  void _finishSubmission(MessageType type, String message) {
    setState(() {
      _isSubmitting = false;
      _fuelController.clear();
      _waterController.clear();
      _steamController.clear();
      _pinController.clear();
      _messageType = type;
      _message = message;
    });
  }

  String _formatReadingDelta(BoilerReading reading) {
    final parts = <String>[];
    if (reading.fuelConsumption != null) {
      parts.add('combustible ${Formats.two(reading.fuelConsumption!)} unid.');
    }
    if (reading.waterConsumption != null) {
      parts.add('agua ${Formats.two(reading.waterConsumption!)} unid.');
    }
    if (reading.steamConsumption != null) {
      parts.add('vapor ${Formats.two(reading.steamConsumption!)} unid.');
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

  String _createReadingId() {
    final random = math.Random().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().millisecondsSinceEpoch}-$random';
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    required this.reportStore,
    required this.consumptionStore,
    super.key,
  });

  final ReportStore reportStore;
  final ConsumptionStore consumptionStore;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

enum AdminPanelTab { barePipe, consumption }

enum ConsumptionScale { hour, day, week, month, year }

class _AdminScreenState extends State<AdminScreen> {
  List<BarePipeReport> _reports = [];
  List<BoilerReading> _readings = [];
  var _isLoadingReports = true;
  var _isLoadingReadings = true;
  var _selectedTab = AdminPanelTab.barePipe;
  var _consumptionScale = ConsumptionScale.hour;
  var _selectedBoiler = '';

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadReadings();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab.index,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = AdminPanelTab.values[index]);
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
        ],
      ),
      children: [
        const BackToHomeButton(),
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
        else
          ConsumptionAdminTab(
            readings: _readings,
            isLoading: _isLoadingReadings,
            selectedBoiler: _selectedBoiler,
            scale: _consumptionScale,
            onBoilerChanged: (value) => setState(() => _selectedBoiler = value),
            onScaleChanged: (value) =>
                setState(() => _consumptionScale = value),
          ),
      ],
    );
  }

  bool _isCurrentTabLoading() {
    return _selectedTab == AdminPanelTab.barePipe
        ? _isLoadingReports
        : _isLoadingReadings;
  }

  Future<void> _refreshCurrentTab() {
    return _selectedTab == AdminPanelTab.barePipe
        ? _loadReports()
        : _loadReadings();
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

class BackToHomeButton extends StatelessWidget {
  const BackToHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Volver a EE'),
        style: TextButton.styleFrom(
          foregroundColor: tealColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
                '${Formats.date(reading.recordedAt)} - PIN ${reading.operatorPin}',
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
