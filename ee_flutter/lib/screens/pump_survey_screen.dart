import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/pump_energy.dart';
import '../domain/section_catalog.dart';
import '../services/cloudinary_service.dart';
import '../services/operator_session.dart';
import '../services/motor_reference_store.dart';
import '../services/pump_survey_store.dart';
import '../widgets/home_navigation_bar.dart';

const _brandRed = Color(0xffe3263a);
const _borderColor = Color(0xffdae2e5);

class PumpSurveyScreen extends StatefulWidget {
  const PumpSurveyScreen({
    required this.store,
    required this.operatorSession,
    required this.cloudinaryService,
    this.motorReferenceStore = const DisabledMotorReferenceStore(),
    super.key,
  });

  final PumpSurveyStore store;
  final OperatorSession operatorSession;
  final CloudinaryService cloudinaryService;
  final MotorReferenceStore motorReferenceStore;

  @override
  State<PumpSurveyScreen> createState() => _PumpSurveyScreenState();
}

class _PumpSurveyScreenState extends State<PumpSurveyScreen> {
  final _picker = ImagePicker();
  final _equipment = TextEditingController();
  final _tag = TextEditingController();
  final _service = TextEditingController();
  final _customHp = TextEditingController();
  final _customNominalVoltage = TextEditingController();
  final _averageVoltage = TextEditingController();
  final _vab = TextEditingController();
  final _vbc = TextEditingController();
  final _vca = TextEditingController();
  final _averageCurrent = TextEditingController();
  final _ia = TextEditingController();
  final _ib = TextEditingController();
  final _ic = TextEditingController();
  final _powerFactor = TextEditingController();
  final _measuredKw = TextEditingController();
  final _efficiency = TextEditingController();
  final _measuredFrequency = TextEditingController();
  final _nominalFrequency = TextEditingController();
  final _hoursPerDay = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _rpm = TextEditingController();
  final _poles = TextEditingController();
  final _vfdFrequency = TextEditingController();
  final _measurementMethod = TextEditingController();
  final _instrument = TextEditingController();
  final _notes = TextEditingController();

  String _sectionId = plantSections.first.id;
  String _surveyType = 'baseline';
  String _starterType = 'direct';
  String _ieClass = 'unknown';
  int _phaseCount = 3;
  String _nominalVoltage = '440';
  int _hpIndex = 8;
  List<PumpBaselineOption> _baselines = const [];
  String _baselineSectionId = '';
  String _baselineEquipmentKey = '';
  String _selectedBaselineId = '';
  String _baselineLoadError = '';
  PumpEnergyResult? _result;
  PumpSurveyDraft? _draft;
  CloudinaryUpload? _photoUpload;
  Uint8List? _photoBytes;
  String _message = '';
  bool _messageIsError = false;
  bool _isSaving = false;
  bool _isCalculating = false;
  bool _isLoadingBaselines = false;

  List<TextEditingController> get _controllers => [
    _equipment,
    _tag,
    _service,
    _customHp,
    _customNominalVoltage,
    _averageVoltage,
    _vab,
    _vbc,
    _vca,
    _averageCurrent,
    _ia,
    _ib,
    _ic,
    _powerFactor,
    _measuredKw,
    _efficiency,
    _measuredFrequency,
    _nominalFrequency,
    _hoursPerDay,
    _brand,
    _model,
    _rpm,
    _poles,
    _vfdFrequency,
    _measurementMethod,
    _instrument,
    _notes,
  ];

  @override
  void initState() {
    super.initState();
    _hoursPerDay.text = '8';
    _loadBaselines();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Levantamiento de bombas'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff20272b),
      ),
      bottomNavigationBar: const HomeNavigationBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _panel('Tipo de levantamiento', _surveyTypeFields()),
                  const SizedBox(height: 14),
                  _panel('Identificacion', _identificationFields()),
                  const SizedBox(height: 14),
                  _panel('Potencia nominal', _nominalPowerFields()),
                  const SizedBox(height: 14),
                  _panel('Datos electricos', _electricalFields()),
                  const SizedBox(height: 14),
                  _optionalFields(),
                  const SizedBox(height: 14),
                  _photoSection(),
                  const SizedBox(height: 16),
                  _commandButton(
                    icon: Icons.calculate_outlined,
                    label: 'Calcular y revisar',
                    onPressed: _isSaving || _isCalculating ? null : _calculate,
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 14),
                    _resultPanel(_result!),
                    const SizedBox(height: 14),
                    _commandButton(
                      icon: Icons.cloud_upload_outlined,
                      label: _isSaving
                          ? 'Confirmando guardado...'
                          : 'Guardar levantamiento',
                      onPressed: _isSaving || _draft == null ? null : _save,
                    ),
                    const SizedBox(height: 10),
                    _commandButton(
                      icon: Icons.calculate_outlined,
                      label: 'Solo calcular / No guardar',
                      primary: false,
                      onPressed: _isSaving || _draft == null
                          ? null
                          : _onlyCalculate,
                    ),
                  ],
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _messageBox(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _usesExistingBaseline => _surveyType != 'baseline';

  List<Widget> _surveyTypeFields() => [
    _wheelField<String>(
      label: 'Selecciona el tipo',
      value: _surveyType,
      options: const [
        _PumpWheelOption('baseline', 'Linea base'),
        _PumpWheelOption('post_improvement', 'Posterior a mejora'),
        _PumpWheelOption('verification', 'Verificacion'),
      ],
      onSelected: _isSaving ? null : _selectSurveyType,
    ),
  ];

  List<Widget> _identificationFields() {
    if (_usesExistingBaseline) {
      return _existingBaselineFields();
    }
    return [
      _wheelField<String>(
        label: 'Seccion',
        value: _sectionId,
        options: plantSections
            .map((section) => _PumpWheelOption(section.id, section.displayName))
            .toList(),
        onSelected: _isSaving
            ? null
            : (value) => setState(() {
                _sectionId = value;
                _invalidate();
              }),
      ),
      const SizedBox(height: 12),
      _textField(_equipment, 'Equipo al que pertenece la bomba'),
      const SizedBox(height: 12),
      _textField(_tag, 'Tag o identificador de la bomba'),
      const SizedBox(height: 12),
      _textField(_service, 'Servicio o descripcion'),
    ];
  }

  List<Widget> _existingBaselineFields() {
    if (_isLoadingBaselines) {
      return const [
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 8),
        Center(child: Text('Consultando lineas base...')),
      ];
    }
    if (_baselineLoadError.isNotEmpty) {
      return [
        Text(_baselineLoadError, style: const TextStyle(color: _brandRed)),
        const SizedBox(height: 10),
        _commandButton(
          icon: Icons.refresh,
          label: 'Reintentar consulta',
          primary: false,
          onPressed: _loadBaselines,
        ),
      ];
    }
    if (_baselines.isEmpty) {
      return const [
        Text(
          'Todavia no existen lineas base disponibles. Registra primero la bomba como linea base.',
        ),
      ];
    }

    final sections = <String, PumpBaselineOption>{};
    for (final baseline in _baselines) {
      sections.putIfAbsent(baseline.sectionId, () => baseline);
    }
    final equipment = <String, PumpBaselineOption>{};
    for (final baseline in _baselines.where(
      (item) => item.sectionId == _baselineSectionId,
    )) {
      equipment.putIfAbsent(baseline.equipmentNameNormalized, () => baseline);
    }
    final pumps = _baselines
        .where(
          (item) =>
              item.sectionId == _baselineSectionId &&
              item.equipmentNameNormalized == _baselineEquipmentKey,
        )
        .toList();
    final selected = _selectedBaseline;

    return [
      _wheelField<String>(
        label: 'Seccion de la linea base',
        value: _baselineSectionId,
        options: [
          for (final entry in sections.entries)
            _PumpWheelOption(entry.key, entry.value.sectionName),
        ],
        onSelected: _isSaving ? null : _selectBaselineSection,
      ),
      const SizedBox(height: 12),
      _wheelField<String>(
        label: 'Equipo al que pertenece la bomba',
        value: _baselineEquipmentKey,
        options: [
          for (final entry in equipment.entries)
            _PumpWheelOption(entry.key, entry.value.equipmentName),
        ],
        onSelected: _isSaving ? null : _selectBaselineEquipment,
      ),
      const SizedBox(height: 12),
      _wheelField<String>(
        label: 'Bomba registrada',
        value: _selectedBaselineId,
        options: [
          for (final baseline in pumps)
            _PumpWheelOption(
              baseline.surveyId,
              baseline.serviceDescription.isEmpty
                  ? baseline.pumpTag
                  : '${baseline.pumpTag} - ${baseline.serviceDescription}',
            ),
        ],
        onSelected: _isSaving ? null : _selectBaseline,
      ),
      if (selected != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xfff3f6f7),
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Linea base seleccionada',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text('Equipo: ${selected.equipmentName}'),
              Text('Bomba: ${selected.pumpTag}'),
              if (selected.serviceDescription.isNotEmpty)
                Text('Servicio: ${selected.serviceDescription}'),
            ],
          ),
        ),
      ],
    ];
  }

  PumpBaselineOption? get _selectedBaseline {
    for (final baseline in _baselines) {
      if (baseline.surveyId == _selectedBaselineId) {
        return baseline;
      }
    }
    return null;
  }

  Future<void> _loadBaselines() async {
    if (_isLoadingBaselines) return;
    setState(() {
      _isLoadingBaselines = true;
      _baselineLoadError = '';
    });
    try {
      final baselines = await widget.store.loadBaselines();
      if (!mounted) return;
      setState(() {
        _baselines = baselines;
        _isLoadingBaselines = false;
        if (_usesExistingBaseline && baselines.isNotEmpty) {
          _selectFirstBaseline();
        }
      });
    } on PumpSurveyStoreException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingBaselines = false;
        _baselineLoadError = error.message;
      });
    }
  }

  void _selectSurveyType(String value) {
    final previousType = _surveyType;
    setState(() {
      _surveyType = value;
      if (_usesExistingBaseline && _baselines.isNotEmpty) {
        _selectFirstBaseline();
      } else if (value == 'baseline' && previousType != 'baseline') {
        _baselineSectionId = '';
        _baselineEquipmentKey = '';
        _selectedBaselineId = '';
        _sectionId = plantSections.first.id;
        _equipment.clear();
        _tag.clear();
        _service.clear();
        _hpIndex = 8;
        _customHp.clear();
      }
      _invalidate();
    });
    if (_usesExistingBaseline && _baselines.isEmpty && !_isLoadingBaselines) {
      _loadBaselines();
    }
  }

  void _selectFirstBaseline() {
    final baseline = _baselines.first;
    _baselineSectionId = baseline.sectionId;
    _baselineEquipmentKey = baseline.equipmentNameNormalized;
    _applyBaseline(baseline);
  }

  void _selectBaselineSection(String sectionId) {
    final baseline = _baselines.firstWhere(
      (item) => item.sectionId == sectionId,
    );
    setState(() {
      _baselineSectionId = sectionId;
      _baselineEquipmentKey = baseline.equipmentNameNormalized;
      _applyBaseline(baseline);
      _invalidate();
    });
  }

  void _selectBaselineEquipment(String equipmentKey) {
    final baseline = _baselines.firstWhere(
      (item) =>
          item.sectionId == _baselineSectionId &&
          item.equipmentNameNormalized == equipmentKey,
    );
    setState(() {
      _baselineEquipmentKey = equipmentKey;
      _applyBaseline(baseline);
      _invalidate();
    });
  }

  void _selectBaseline(String surveyId) {
    final baseline = _baselines.firstWhere((item) => item.surveyId == surveyId);
    setState(() {
      _applyBaseline(baseline);
      _invalidate();
    });
  }

  void _applyBaseline(PumpBaselineOption baseline) {
    _selectedBaselineId = baseline.surveyId;
    _sectionId = baseline.sectionId;
    _equipment.text = baseline.equipmentName;
    _tag.text = baseline.pumpTag;
    _service.text = baseline.serviceDescription;
    final hpIndex = standardMotorHp.indexWhere(
      (value) => (value - baseline.nominalPowerHp).abs() < 0.001,
    );
    if (hpIndex >= 0) {
      _hpIndex = hpIndex;
      _customHp.clear();
    } else {
      _hpIndex = standardMotorHp.length;
      _customHp.text = baseline.nominalPowerHp.toString();
    }
  }

  List<Widget> _nominalPowerFields() => [
    _wheelField<int>(
      label: 'Potencia nominal del motor',
      value: _hpIndex,
      options: [
        for (var index = 0; index < standardMotorHp.length; index++)
          _PumpWheelOption(index, '${_format(standardMotorHp[index])} HP'),
        _PumpWheelOption(standardMotorHp.length, 'Otro'),
      ],
      onSelected: _isSaving
          ? null
          : (index) => setState(() {
              _hpIndex = index;
              _invalidate();
            }),
    ),
    if (_hpIndex == standardMotorHp.length) ...[
      const SizedBox(height: 10),
      _numberField(_customHp, 'Potencia nominal manual', 'HP'),
    ],
  ];

  List<Widget> _electricalFields() => [
    SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 1, label: Text('Monofasico')),
        ButtonSegment(value: 3, label: Text('Trifasico')),
      ],
      selected: {_phaseCount},
      onSelectionChanged: _isSaving
          ? null
          : (selection) => setState(() {
              _phaseCount = selection.single;
              _invalidate();
            }),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: _nominalVoltage,
      decoration: const InputDecoration(labelText: 'Tension nominal'),
      items: const [
        DropdownMenuItem(value: '110', child: Text('110 V')),
        DropdownMenuItem(value: '220', child: Text('220 V')),
        DropdownMenuItem(value: '440', child: Text('440 V')),
        DropdownMenuItem(value: 'other', child: Text('Otro')),
      ],
      onChanged: _isSaving
          ? null
          : (value) => setState(() {
              _nominalVoltage = value ?? '440';
              _invalidate();
            }),
    ),
    if (_nominalVoltage == 'other') ...[
      const SizedBox(height: 12),
      _numberField(_customNominalVoltage, 'Tension nominal manual', 'V'),
    ],
    const SizedBox(height: 12),
    ExpansionTile(
      key: const Key('measured-voltage-expansion'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 6),
      title: const Text(
        'Medir tension en un caso puntual',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text(
        'La tension nominal se usara si no se abre esta opcion.',
      ),
      children: [
        _numberField(
          _averageVoltage,
          _phaseCount == 3 ? 'Tension promedio medida' : 'Tension medida',
          'V',
        ),
      ],
    ),
    const SizedBox(height: 12),
    _wheelField<int>(
      label: 'Corriente medida',
      value: (_number(_averageCurrent) ?? 0).round().clamp(0, 500).toInt(),
      options: [
        for (var value = 0; value <= 500; value += 2)
          _PumpWheelOption(value, '$value A'),
      ],
      onSelected: _isSaving
          ? null
          : (value) => setState(() {
              _averageCurrent.text = value.toString();
              _invalidate();
            }),
    ),
    const Text(
      'La rueda avanza cada 2 A. También puedes escribir un valor exacto.',
      style: TextStyle(color: Color(0xff5b6970), fontSize: 12),
    ),
    const SizedBox(height: 10),
    _numberField(
      _averageCurrent,
      _phaseCount == 3 ? 'Corriente promedio medida' : 'Corriente medida',
      'A',
    ),
    const SizedBox(height: 12),
    _wheelField<int>(
      label: 'Horas de trabajo diario',
      value: (_number(_hoursPerDay) ?? 8).round().clamp(1, 24).toInt(),
      options: [
        for (var value = 1; value <= 24; value++)
          _PumpWheelOption(value, '$value h/dia'),
      ],
      onSelected: _isSaving
          ? null
          : (value) => setState(() {
              _hoursPerDay.text = value.toString();
              _invalidate();
            }),
    ),
  ];

  Widget _optionalFields() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Datos opcionales de placa',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        _panel('Datos opcionales', [
          _rowOfFields([
            _textField(_brand, 'Marca'),
            _textField(_model, 'Modelo'),
          ]),
          const SizedBox(height: 12),
          _rowOfFields([
            _numberField(_rpm, 'RPM', 'rpm'),
            _numberField(_poles, 'Numero de polos', ''),
          ]),
          const SizedBox(height: 12),
          _rowOfFields([
            _numberField(_nominalFrequency, 'Frecuencia nominal', 'Hz'),
            DropdownButtonFormField<String>(
              initialValue: _ieClass,
              decoration: const InputDecoration(labelText: 'Nivel IE'),
              items: const [
                DropdownMenuItem(value: 'unknown', child: Text('Sin dato')),
                DropdownMenuItem(value: 'IE1', child: Text('IE1')),
                DropdownMenuItem(value: 'IE2', child: Text('IE2')),
                DropdownMenuItem(value: 'IE3', child: Text('IE3')),
                DropdownMenuItem(value: 'IE4', child: Text('IE4')),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() {
                      _ieClass = value ?? 'unknown';
                      _invalidate();
                    }),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _starterType,
            decoration: const InputDecoration(labelText: 'Tipo de arranque'),
            items: const [
              DropdownMenuItem(value: 'direct', child: Text('Directo')),
              DropdownMenuItem(
                value: 'star_delta',
                child: Text('Estrella-triangulo'),
              ),
              DropdownMenuItem(
                value: 'soft_starter',
                child: Text('Soft starter'),
              ),
              DropdownMenuItem(value: 'vfd', child: Text('Variador')),
            ],
            onChanged: _isSaving
                ? null
                : (value) => setState(() {
                    _starterType = value ?? 'direct';
                    _invalidate();
                  }),
          ),
          if (_starterType == 'vfd') ...[
            const SizedBox(height: 12),
            _numberField(_vfdFrequency, 'Frecuencia de salida VFD', 'Hz'),
          ],
          const SizedBox(height: 12),
          _textField(_notes, 'Observaciones', maxLines: 4),
        ]),
      ],
    );
  }

  Widget _photoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _commandButton(
          icon: Icons.photo_camera_outlined,
          label: 'Foto de placa (opcional)',
          primary: false,
          onPressed: _isSaving ? null : _pickPhoto,
        ),
        if (_photoBytes != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_photoBytes!, fit: BoxFit.cover),
            ),
          ),
        ],
      ],
    );
  }

  Widget _panel(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _rowOfFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                fields[index],
                if (index < fields.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              Expanded(child: fields[index]),
              if (index < fields.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSaving,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(_invalidate),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String unit,
  ) {
    return TextField(
      controller: controller,
      enabled: !_isSaving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit.isEmpty ? null : unit,
      ),
      onChanged: (_) => setState(_invalidate),
    );
  }

  Widget _wheelField<T>({
    required String label,
    required T value,
    required List<_PumpWheelOption<T>> options,
    required ValueChanged<T>? onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        _PumpWheelPicker<T>(
          value: value,
          options: options,
          onSelected: onSelected,
        ),
      ],
    );
  }

  Widget _commandButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool primary = true,
  }) {
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: _brandRed,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: _brandRed,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
    return primary
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          );
  }

  Widget _resultPanel(PumpEnergyResult result) {
    return _panel('Resultado', [
      _resultRow('Potencia electrica', '${_format(result.inputPowerKw)} kW'),
      if (result.shaftPowerKw != null)
        _resultRow(
          'Potencia mecanica estimada',
          '${_format(result.shaftPowerKw!)} kW',
        ),
      if (result.dailyEnergyKwh != null)
        _resultRow('Energia diaria', '${_format(result.dailyEnergyKwh!)} kWh'),
      if (result.annualEnergyKwh != null)
        _resultRow('Energia anual', '${_format(result.annualEnergyKwh!)} kWh'),
      if (result.estimatedLoadFactor != null)
        _resultRow(
          'Factor de carga estimado',
          '${_format(result.estimatedLoadFactor! * 100)} %',
        ),
      if (result.voltageUnbalancePercent != null)
        _resultRow(
          'Desequilibrio de tension',
          '${_format(result.voltageUnbalancePercent!)} %',
        ),
      if (result.currentUnbalancePercent != null)
        _resultRow(
          'Desequilibrio de corriente',
          '${_format(result.currentUnbalancePercent!)} %',
        ),
      _resultRow(
        'Nivel de confianza',
        _confidenceLabel(result.confidenceLevel),
      ),
      if (result.candidateForHydraulicReview)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Candidata a revision hidraulica. Esto no confirma sobredimensionamiento.',
            style: TextStyle(fontWeight: FontWeight.bold, color: _brandRed),
          ),
        ),
      if (result.warnings.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Advertencias: ${result.warnings.join(', ')}',
            style: const TextStyle(color: Color(0xff5b6970)),
          ),
        ),
    ]);
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _messageBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _messageIsError
            ? const Color(0xffffeeee)
            : const Color(0xffeef7f2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _messageIsError
              ? const Color(0xffd33b3b)
              : const Color(0xff4a8063),
        ),
      ),
      child: Text(_message),
    );
  }

  Future<void> _calculate() async {
    final section = plantSectionById(_sectionId);
    final baseline = _usesExistingBaseline ? _selectedBaseline : null;
    final hp = _selectedHp();
    if (section == null ||
        (_usesExistingBaseline && baseline == null) ||
        _equipment.text.trim().isEmpty ||
        _tag.text.trim().isEmpty ||
        _service.text.trim().isEmpty) {
      _setMessage(
        _usesExistingBaseline
            ? 'Selecciona una linea base valida.'
            : 'Completa seccion, equipo, tag y servicio.',
        true,
      );
      return;
    }
    if (hp == null || hp <= 0) {
      _setMessage('Ingresa una potencia nominal HP valida.', true);
      return;
    }

    final nominalVoltage = _nominalVoltage == 'other'
        ? _number(_customNominalVoltage)
        : double.parse(_nominalVoltage);
    if (nominalVoltage == null || nominalVoltage <= 0) {
      _setMessage('Ingresa una tension nominal valida.', true);
      return;
    }
    final measuredVoltage = _number(_averageVoltage);
    final voltageUsed = measuredVoltage != null && measuredVoltage > 0
        ? measuredVoltage
        : nominalVoltage;
    final voltages = [voltageUsed];
    final measuredVoltages = measuredVoltage != null && measuredVoltage > 0
        ? [measuredVoltage]
        : <double>[];
    final currents = _positiveValues([_averageCurrent]);
    final efficiencyPercent = _number(_efficiency);
    final poles = _number(_poles)?.round();
    MotorReferencePair? reference;
    if (poles != null && poles > 0 && _ieClass != 'unknown') {
      setState(() => _isCalculating = true);
      reference = await widget.motorReferenceStore.lookup(
        powerHp: hp,
        poles: poles,
        ieClass: _ieClass,
      );
      if (!mounted) return;
    }
    final result = PumpEnergyCalculator.calculate(
      PumpEnergyInput(
        nominalPowerHp: hp,
        phaseCount: _phaseCount,
        measuredVoltagesV: voltages,
        measuredCurrentsA: currents,
        measuredPowerFactor: _number(_powerFactor),
        measuredActivePowerKw: _number(_measuredKw),
        nameplateEfficiency: efficiencyPercent == null
            ? null
            : efficiencyPercent / 100,
        hoursPerDay: _number(_hoursPerDay),
        daysPerYear: null,
        powerFactorReference: reference?.powerFactor,
        efficiencyReference: reference?.efficiency,
      ),
    );
    final assetSlug = normalizeEquipmentName(
      _tag.text,
    ).replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    final draft = PumpSurveyDraft(
      id: _newId(),
      sectionId: section.id,
      sectionNameSnapshot: section.displayName,
      equipmentName: _equipment.text.trim(),
      equipmentNameNormalized: normalizeEquipmentName(_equipment.text),
      assetId: baseline?.assetId ?? '${section.id}_$assetSlug',
      pumpTag: _tag.text.trim(),
      serviceDescription: _service.text.trim(),
      surveyType: _surveyType,
      interventionId: null,
      baselineSurveyId: baseline?.surveyId,
      nominalPowerHp: hp,
      identification: {
        'pumpTag': _tag.text.trim(),
        'serviceDescription': _service.text.trim(),
        'manufacturer': _emptyToNull(_brand.text),
        'model': _emptyToNull(_model.text),
        'rpm': _number(_rpm),
        'nominalFrequencyHz': _number(_nominalFrequency),
        'poles': poles,
        'ieClass': _ieClass == 'unknown' ? null : _ieClass,
        'starterType': _starterType,
        'vfdOutputFrequencyHz': _number(_vfdFrequency),
      },
      electricalInputs: {
        'phaseCount': _phaseCount,
        'nominalVoltageV': nominalVoltage,
        'measuredVoltagesV': measuredVoltages,
        'voltageUsedV': voltageUsed,
        'voltageSource': measuredVoltages.isEmpty ? 'nominal' : 'measured',
        'measuredCurrentsA': currents,
        'averageOnly': true,
        'measuredPowerFactor': _number(_powerFactor),
        'measuredActivePowerKw': _number(_measuredKw),
        'nameplateEfficiency': efficiencyPercent == null
            ? null
            : efficiencyPercent / 100,
        'measuredFrequencyHz': _number(_measuredFrequency),
        'measurementMethod': _emptyToNull(_measurementMethod.text),
        'instrument': _emptyToNull(_instrument.text),
      },
      operatingInputs: {'hoursPerDay': _number(_hoursPerDay)},
      result: result,
      assumptions: {
        'powerFactor': result.powerFactorUsed,
        'powerFactorSource': result.powerFactorSource,
        'efficiency': result.efficiencyUsed,
        'efficiencySource': result.efficiencySource,
        'loadFactor': result.estimatedLoadFactor,
        'voltageSource': measuredVoltages.isEmpty ? 'nominal' : 'measured',
        'referenceVersion': pumpFormulaVersion,
      },
      notes: _notes.text.trim(),
    );

    setState(() {
      _result = result;
      _draft = draft;
      _photoUpload = null;
      _isCalculating = false;
      _message = 'Calculo listo. Revisa el resultado antes de guardar.';
      _messageIsError = false;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _isSaving) return;
    final operator = await widget.operatorSession.currentOperator();
    if (!mounted) return;
    if (operator == null) {
      _setMessage('Inicia sesion como usuario antes de guardar.', true);
      return;
    }
    final confirmed = await _confirmSave(draft, operator);
    if (!mounted || confirmed != true) return;

    setState(() {
      _isSaving = true;
      _message = 'Guardando y esperando confirmacion de la nube...';
      _messageIsError = false;
    });
    try {
      var upload = _photoUpload;
      if (_photoBytes != null && upload == null) {
        upload = await widget.cloudinaryService.uploadEvidence(
          bytes: _photoBytes!,
          reportId: draft.id,
        );
        if (!mounted) return;
        setState(() => _photoUpload = upload);
      }
      await widget.store.saveSurvey(
        draft,
        photoUrl: upload?.secureUrl,
        photoPublicId: upload?.publicId,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _draft = null;
        _message = 'Levantamiento confirmado en la nube.';
        _messageIsError = false;
      });
    } on PumpSurveyStoreException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = error.message;
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _message = 'No se pudo confirmar el levantamiento.';
        _messageIsError = true;
      });
    }
  }

  Future<bool?> _confirmSave(
    PumpSurveyDraft draft,
    AuthenticatedOperator operator,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar levantamiento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seccion: ${draft.sectionNameSnapshot}'),
              Text('Equipo: ${draft.equipmentName}'),
              Text('Bomba: ${draft.pumpTag}'),
              Text('Tipo: ${draft.surveyType}'),
              Text('Potencia: ${_format(draft.result.inputPowerKw)} kW'),
              Text(
                'Confianza: ${_confidenceLabel(draft.result.confidenceLevel)}',
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
      ),
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
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoUpload = null;
      _invalidate();
    });
  }

  void _onlyCalculate() {
    setState(() {
      _draft = null;
      _message = 'El resultado no se guardo.';
      _messageIsError = false;
    });
  }

  void _invalidate() {
    _result = null;
    _draft = null;
    _photoUpload = null;
    _message = '';
  }

  double? _selectedHp() {
    if (_hpIndex < standardMotorHp.length) {
      return standardMotorHp[_hpIndex];
    }
    return _number(_customHp);
  }

  List<double> _positiveValues(List<TextEditingController> controllers) {
    return controllers
        .map(_number)
        .whereType<double>()
        .where((value) => value > 0)
        .toList();
  }

  double? _number(TextEditingController controller) {
    final normalized = controller.text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _newId() {
    final random = math.Random().nextInt(1 << 32).toRadixString(16);
    return 'pump-${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  String _format(double value) {
    return value.abs() >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  String _confidenceLabel(String confidence) {
    return switch (confidence) {
      'high' => 'Alta',
      'medium' => 'Media',
      _ => 'Baja',
    };
  }

  void _setMessage(String message, bool isError) {
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }
}

class _PumpWheelOption<T> {
  const _PumpWheelOption(this.value, this.label);

  final T value;
  final String label;
}

class _PumpWheelPicker<T> extends StatefulWidget {
  const _PumpWheelPicker({
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final T value;
  final List<_PumpWheelOption<T>> options;
  final ValueChanged<T>? onSelected;

  @override
  State<_PumpWheelPicker<T>> createState() => _PumpWheelPickerState<T>();
}

class _PumpWheelPickerState<T> extends State<_PumpWheelPicker<T>> {
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
  void didUpdateWidget(covariant _PumpWheelPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _selectedIndex;
    if (_controller.hasClients && _controller.selectedItem != nextIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_controller.hasClients ||
            _controller.selectedItem == nextIndex) {
          return;
        }
        _isSyncingController = true;
        _controller.jumpToItem(nextIndex);
        _isSyncingController = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        height: 124,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Container(
                height: 42,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _brandRed.withValues(alpha: 0.24)),
                ),
              ),
            ),
            IgnorePointer(
              ignoring: widget.onSelected == null,
              child: Opacity(
                opacity: widget.onSelected == null ? 0.55 : 1,
                child: ListWheelScrollView.useDelegate(
                  controller: _controller,
                  itemExtent: 42,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.8,
                  perspective: 0.0025,
                  onSelectedItemChanged: (index) {
                    if (_isSyncingController ||
                        widget.onSelected == null ||
                        index < 0 ||
                        index >= widget.options.length) {
                      return;
                    }
                    widget.onSelected!(widget.options[index].value);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.options.length,
                    builder: (context, index) {
                      if (index < 0 || index >= widget.options.length) {
                        return null;
                      }
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            widget.options[index].label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
