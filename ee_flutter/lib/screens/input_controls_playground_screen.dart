part of '../main.dart';

class InputControlsPlaygroundScreen extends StatefulWidget {
  const InputControlsPlaygroundScreen({this.consumptionStore, super.key});

  final ConsumptionStore? consumptionStore;

  @override
  State<InputControlsPlaygroundScreen> createState() =>
      _InputControlsPlaygroundScreenState();
}

class _InputControlsPlaygroundScreenState
    extends State<InputControlsPlaygroundScreen> {
  static const _units = <_InstrumentUnit>[
    _InstrumentUnit(
      id: 'gal',
      label: 'gal',
      maximum: 100000,
      fineStep: 1,
      initialValue: 1250,
    ),
    _InstrumentUnit(
      id: 'psi',
      label: 'PSI',
      maximum: 250,
      fineStep: 0.1,
      initialValue: 90,
    ),
    _InstrumentUnit(
      id: 'amp',
      label: 'A',
      maximum: 500,
      fineStep: 0.1,
      initialValue: 50,
    ),
    _InstrumentUnit(
      id: 'temperature',
      label: 'C',
      maximum: 300,
      fineStep: 0.5,
      initialValue: 80,
    ),
  ];

  static const _instrumentSurface = Color(0xff171c1f);
  static const _instrumentFrame = Color(0xff778187);
  static const _instrumentGreen = Color(0xff00ff66);
  static const _instrumentAmber = Color(0xffffb33c);

  var _unitIndex = 0;
  var _value = _units.first.initialValue;
  var _odometerBoiler = boilerNames.first;
  var _odometerDigits = List<int>.filled(10, 0);
  var _previousFuelByBoiler = <String, double>{};
  var _isLoadingOdometer = false;

  _InstrumentUnit get _unit => _units[_unitIndex];
  String get _odometerText => _odometerDigits.join();

  @override
  void initState() {
    super.initState();
    _loadPreviousOdometerReadings();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Banco de instrumentos',
          subtitle: 'Borrador para usuarios',
        ),
        const SizedBox(height: 16),
        _masterReadout(),
        const SizedBox(height: 14),
        _instrumentPanel(
          number: '01',
          title: 'Manometro analogico',
          icon: Icons.speed_outlined,
          child: _analogGauge(),
        ),
        const SizedBox(height: 14),
        _instrumentPanel(
          number: '02',
          title: 'Encoder rotativo',
          icon: Icons.settings_input_component_outlined,
          child: _rotaryEncoder(),
        ),
        const SizedBox(height: 14),
        _instrumentPanel(
          number: '03',
          title: 'Dial circular',
          icon: Icons.donut_large_outlined,
          child: _circularDial(),
        ),
        const SizedBox(height: 14),
        _instrumentPanel(
          number: '04',
          title: 'Transmisor lineal',
          icon: Icons.straighten_outlined,
          child: _linearTransmitter(),
        ),
        const SizedBox(height: 14),
        _instrumentPanel(
          number: '05',
          title: 'Odometro digital de 10 digitos',
          icon: Icons.pin_outlined,
          child: _digitalOdometer(),
        ),
      ],
    );
  }

  Widget _masterReadout() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffe6eaec),
        border: Border.all(color: _instrumentFrame, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: _instrumentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LECTURA ACTIVA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  'EE-INPUT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _digitalReadout(large: true),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final unit in _units)
                  ButtonSegment<String>(
                    value: unit.id,
                    label: Text(unit.label),
                  ),
              ],
              selected: {_unit.id},
              onSelectionChanged: (selection) {
                final index = _units.indexWhere(
                  (unit) => unit.id == selection.first,
                );
                _selectUnit(index);
              },
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: 'Ajuste fino inferior',
                  child: IconButton.outlined(
                    key: const Key('industrial-fine-decrement'),
                    onPressed: () => _changeBy(-_unit.fineStep),
                    icon: const Icon(Icons.remove),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'AJUSTE FINO  ${_formatDisplay(_unit.fineStep)} ${_unit.label}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Ajuste fino superior',
                  child: IconButton.filled(
                    key: const Key('industrial-fine-increment'),
                    onPressed: () => _changeBy(_unit.fineStep),
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _instrumentPanel({
    required String number,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xffe9edef),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _instrumentSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: _instrumentGreen,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 21, color: tealColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMediumBold,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _analogGauge() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: AspectRatio(
          aspectRatio: 1.35,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xfff7f8f8),
              border: Border.all(color: _instrumentFrame, width: 5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                  child: industrial_gauge.RadialGauge(
                    key: ValueKey('analog-${_unit.id}'),
                    radiusFactor: 0.88,
                    yCenterCoordinate: 0.58,
                    track: industrial_gauge.RadialTrack(
                      start: 0,
                      end: _unit.maximum,
                      steps: (_unit.maximum / 5).round(),
                      startAngle: -30,
                      endAngle: 210,
                      thickness: 8,
                      color: borderColor,
                      gradient: const LinearGradient(
                        colors: [tealColor, _instrumentAmber, brandRed],
                      ),
                      trackLabelFormater: _compactGaugeLabel,
                      trackStyle: const industrial_gauge.TrackStyle(
                        primaryRulersHeight: 14,
                        secondaryRulersHeight: 7,
                        primaryRulerColor: textColor,
                        secondaryRulerColor: mutedColor,
                        secondaryRulerPerInterval: 4,
                        labelOffset: 2,
                        labelStyle: TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    needlePointer: [
                      industrial_gauge.NeedlePointer(
                        value: _value,
                        color: brandRed,
                        tailColor: textColor,
                        needleHeight: 110,
                        needleWidth: 5,
                        tailRadius: 14,
                        isInteractive: true,
                        onChanged: _setValue,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 70,
                  right: 70,
                  bottom: 12,
                  child: _compactReadout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rotaryEncoder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        final knob = DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xffe2e6e8),
            border: Border.all(color: _instrumentFrame, width: 3),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: industrial_knob.DialKnob(
              key: ValueKey('knob-${_unit.id}'),
              value: _value,
              min: 0,
              max: _unit.maximum,
              size: narrow ? 150 : 170,
              dragDirection: industrial_knob.DragDirection.both,
              trackColor: mutedColor,
              levelColorStart: tealColor,
              levelColorEnd: brandRed,
              knobColor: _instrumentSurface,
              indicatorColor: _instrumentGreen,
              onChanged: _setValue,
            ),
          ),
        );
        final readout = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _digitalReadout(),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'MIN 0',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'MAX ${_compactGaugeLabel(_unit.maximum)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        );

        if (narrow) {
          return Column(
            children: [
              SizedBox(width: 174, height: 174, child: knob),
              const SizedBox(height: 14),
              readout,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 194, height: 194, child: knob),
            const SizedBox(width: 24),
            Expanded(child: readout),
          ],
        );
      },
    );
  }

  Widget _circularDial() {
    return Center(
      child: circular_instrument.SleekCircularSlider(
        key: ValueKey('circular-${_unit.id}'),
        min: 0,
        max: _unit.maximum,
        initialValue: _value,
        appearance: circular_instrument.CircularSliderAppearance(
          size: 230,
          startAngle: 145,
          angleRange: 250,
          animationEnabled: false,
          customWidths: circular_instrument.CustomSliderWidths(
            trackWidth: 8,
            progressBarWidth: 18,
            handlerSize: 9,
            shadowWidth: 0,
          ),
          customColors: circular_instrument.CustomSliderColors(
            trackColor: const Color(0xffcfd5d8),
            progressBarColors: const [tealColor, _instrumentAmber, brandRed],
            dotColor: _instrumentSurface,
            hideShadow: true,
          ),
        ),
        onChange: _setValue,
        innerWidget: (_) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.rotate_right_outlined,
                size: 22,
                color: tealColor,
              ),
              const SizedBox(height: 6),
              Text(
                _formatDisplay(_value),
                style: const TextStyle(
                  color: textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _unit.label,
                style: const TextStyle(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linearTransmitter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _compactReadout(),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          child: industrial_gauge.LinearGauge(
            key: ValueKey('linear-${_unit.id}'),
            start: 0,
            end: _unit.maximum,
            steps: _unit.maximum / 5,
            enableGaugeAnimation: false,
            linearGaugeBoxDecoration:
                const industrial_gauge.LinearGaugeBoxDecoration(
                  thickness: 12,
                  linearGradient: LinearGradient(
                    colors: [tealColor, _instrumentAmber, brandRed],
                  ),
                ),
            rulers: industrial_gauge.RulerStyle(
              rulerPosition: industrial_gauge.RulerPosition.bottom,
              primaryRulersHeight: 14,
              secondaryRulersHeight: 7,
              secondaryRulerPerInterval: 4,
              primaryRulerColor: textColor,
              secondaryRulerColor: mutedColor,
              textStyle: const TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            pointers: [
              industrial_gauge.Pointer(
                value: _value,
                shape: industrial_gauge.PointerShape.triangle,
                color: _instrumentSurface,
                width: 20,
                height: 20,
                pointerPosition: industrial_gauge.PointerPosition.top,
                isInteractive: true,
                enableAnimation: false,
                onChanged: _setValue,
              ),
            ],
            valueBar: [
              industrial_gauge.ValueBar(
                value: _value,
                color: brandRed,
                valueBarThickness: 5,
                enableAnimation: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _digitalOdometer() {
    final previous = _previousFuelByBoiler[_odometerBoiler];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Caldera', style: Theme.of(context).textTheme.labelBold),
        const SizedBox(height: 8),
        EmbeddedWheelPicker<String>(
          value: _odometerBoiler,
          options: boilerNames.map((name) => PickerOption(name, name)).toList(),
          onSelected: _selectOdometerBoiler,
          height: 110,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'LECTURA ANTERIOR DE BUNKER',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (_isLoadingOdometer)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                previous == null ? 'SIN HISTORIAL' : 'CARGADA',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: previous == null ? brandRedDark : tealColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        IndustrialOdometer(
          value: int.parse(_odometerText),
          unitLabel: 'gal',
          digitKeyPrefix: 'odometer-digit',
          valueKey: const Key('odometer-current-value'),
          onChanged: (value) =>
              setState(() => _applyOdometerValue(value.toDouble())),
        ),
      ],
    );
  }

  Future<void> _loadPreviousOdometerReadings() async {
    final store = widget.consumptionStore;
    if (store == null) return;
    setState(() => _isLoadingOdometer = true);
    try {
      final readings = await store.loadReadings();
      final sorted = [...readings]
        ..sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
      final previousByBoiler = <String, double>{};
      for (final reading in sorted) {
        final definition =
            boilerById(reading.effectiveBoilerId) ??
            boilerByName(reading.boilerName);
        if (definition != null) {
          previousByBoiler.putIfAbsent(
            definition.displayName,
            () => reading.fuelTotal,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _previousFuelByBoiler = previousByBoiler;
        _isLoadingOdometer = false;
        _applyOdometerValue(previousByBoiler[_odometerBoiler]);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOdometer = false);
    }
  }

  void _selectOdometerBoiler(String boilerName) {
    setState(() {
      _odometerBoiler = boilerName;
      _applyOdometerValue(_previousFuelByBoiler[boilerName]);
    });
  }

  void _applyOdometerValue(double? value) {
    final normalized = (value ?? 0).round().clamp(0, 9999999999);
    final padded = normalized.toString().padLeft(10, '0');
    _odometerDigits = padded
        .split('')
        .map((digit) => int.parse(digit))
        .toList();
  }

  Widget _digitalReadout({bool large = false}) {
    final displayValue = _rawValue(_value);
    return Container(
      key: large ? const Key('playground-current-value') : null,
      constraints: BoxConstraints(minHeight: large ? 82 : 68),
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: _instrumentSurface,
        border: Border.all(color: const Color(0xff050708), width: 2),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: segment_display.SevenSegmentDisplay(
                  value: displayValue,
                  characterCount: 6,
                  size: large ? 9 : 7,
                  characterSpacing: 5,
                  backgroundColor: _instrumentSurface,
                  segmentStyle: const segment_display.HexSegmentStyle(
                    enabledColor: _instrumentGreen,
                    disabledColor: Color(0xff24362a),
                    segmentSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _unit.label,
            style: TextStyle(
              color: _instrumentGreen,
              fontWeight: FontWeight.w800,
              fontSize: large ? 20 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactReadout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _instrumentSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xff050708)),
      ),
      child: Text(
        '${_formatDisplay(_value)}  ${_unit.label}',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _instrumentGreen,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  void _selectUnit(int index) {
    if (index < 0 || index == _unitIndex) {
      return;
    }
    setState(() {
      _unitIndex = index;
      _value = _units[index].initialValue;
    });
  }

  void _changeBy(double delta) {
    _setValue(_value + delta);
  }

  void _setValue(double next) {
    final clamped = next.clamp(0, _unit.maximum);
    final snapped = (clamped / _unit.fineStep).roundToDouble() * _unit.fineStep;
    final normalized = double.parse(snapped.toStringAsFixed(2));
    if ((normalized - _value).abs() < 0.001) {
      return;
    }
    setState(() {
      _value = normalized;
    });
  }

  String _compactGaugeLabel(double value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      final digits = thousands == thousands.roundToDouble() ? 0 : 1;
      return '${thousands.toStringAsFixed(digits)}k';
    }
    return _rawValue(value);
  }

  String _rawValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatDisplay(double value) {
    final raw = _rawValue(value);
    final parts = raw.split('.');
    final digits = parts.first;
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }
    if (parts.length > 1) {
      buffer
        ..write(',')
        ..write(parts[1]);
    }
    return buffer.toString();
  }
}

class _InstrumentUnit {
  const _InstrumentUnit({
    required this.id,
    required this.label,
    required this.maximum,
    required this.fineStep,
    required this.initialValue,
  });

  final String id;
  final String label;
  final double maximum;
  final double fineStep;
  final double initialValue;
}

class IndustrialOdometer extends StatelessWidget {
  const IndustrialOdometer({
    required this.value,
    required this.unitLabel,
    required this.onChanged,
    required this.digitKeyPrefix,
    this.valueKey,
    super.key,
  });

  final int value;
  final String unitLabel;
  final ValueChanged<int> onChanged;
  final String digitKeyPrefix;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0, 9999999999);
    final text = normalized.toString().padLeft(10, '0');
    final digits = text.split('').map(int.parse).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          decoration: BoxDecoration(
            color: _InputControlsPlaygroundScreenState._instrumentSurface,
            border: Border.all(color: const Color(0xff050708), width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              for (var index = 0; index < digits.length; index++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: _OdometerDigit(
                      key: ValueKey('$digitKeyPrefix-$index'),
                      value: digits[index],
                      enabledColor:
                          _InputControlsPlaygroundScreenState._instrumentGreen,
                      onChanged: (digit) {
                        final updated = [...digits];
                        updated[index] = digit;
                        onChanged(int.parse(updated.join()));
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$text $unitLabel',
          key: valueKey,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: tealColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _OdometerDigit extends StatefulWidget {
  const _OdometerDigit({
    required this.value,
    required this.onChanged,
    required this.enabledColor,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final Color enabledColor;

  @override
  State<_OdometerDigit> createState() => _OdometerDigitState();
}

class _OdometerDigitState extends State<_OdometerDigit> {
  static const _anchor = 1000;
  late final FixedExtentScrollController _controller;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: _anchor + widget.value,
    );
  }

  @override
  void didUpdateWidget(covariant _OdometerDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value || !_controller.hasClients) return;
    final current = _controller.selectedItem;
    if (current % 10 == widget.value) return;
    _syncing = true;
    _controller.jumpToItem(_anchor + widget.value);
    _syncing = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xff20272b),
                border: Border.all(color: brandRed.withValues(alpha: 0.75)),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: 48,
            physics: const FixedExtentScrollPhysics(),
            diameterRatio: 1.45,
            perspective: 0.004,
            overAndUnderCenterOpacity: 0.25,
            onSelectedItemChanged: (index) {
              if (!_syncing) widget.onChanged(index % 10);
            },
            childDelegate: ListWheelChildLoopingListDelegate(
              children: [
                for (var digit = 0; digit <= 9; digit++)
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: segment_display.SevenSegmentDisplay(
                        value: '$digit',
                        characterCount: 1,
                        size: 4.2,
                        backgroundColor: _InputControlsPlaygroundScreenState
                            ._instrumentSurface,
                        segmentStyle: segment_display.HexSegmentStyle(
                          enabledColor: widget.enabledColor,
                          disabledColor: const Color(0xff24362a),
                          segmentSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
