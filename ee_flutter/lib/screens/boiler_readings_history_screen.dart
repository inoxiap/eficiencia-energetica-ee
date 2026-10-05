part of '../main.dart';

class BoilerReadingsHistoryScreen extends StatefulWidget {
  const BoilerReadingsHistoryScreen({
    required this.consumptionStore,
    super.key,
  });

  final ConsumptionStore consumptionStore;

  @override
  State<BoilerReadingsHistoryScreen> createState() =>
      _BoilerReadingsHistoryScreenState();
}

class _BoilerReadingsHistoryScreenState
    extends State<BoilerReadingsHistoryScreen> {
  static const _pageSize = 15;

  final _visibleByBoiler = <String, int>{
    for (final boiler in boilerDefinitions) boiler.id: _pageSize,
  };
  List<BoilerReading> _readings = const [];
  String _selectedBoilerId = boilerDefinitions.first.id;
  _BoilerReadingView _view = _BoilerReadingView.real;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadReadings());
  }

  Future<void> _loadReadings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final readings = await widget.consumptionStore.loadReadings();
      readings.sort((left, right) {
        final byDate = right.recordedAt.compareTo(left.recordedAt);
        return byDate != 0 ? byDate : right.revision.compareTo(left.revision);
      });
      if (!mounted) return;
      setState(() {
        _readings = readings;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'No fue posible consultar los registros. Verifica la sesion y la conexion.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final boiler = boilerById(_selectedBoilerId)!;
    final selectedReadings = _readings
        .where((reading) => reading.effectiveBoilerId == _selectedBoilerId)
        .toList();
    final visibleCount = math.min(
      _visibleByBoiler[_selectedBoilerId] ?? _pageSize,
      selectedReadings.length,
    );
    final visibleReadings = selectedReadings.take(visibleCount).toList();
    final normalizedReadings = BoilerHourlyNormalizer.normalize(
      selectedReadings,
    );
    final selectedCount = _view == _BoilerReadingView.real
        ? selectedReadings.length
        : normalizedReadings.length;
    final visibleItemsCount = math.min(
      _visibleByBoiler[_selectedBoilerId] ?? _pageSize,
      selectedCount,
    );

    return AppShell(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navigationIndex,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Alfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Distral',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Casa',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Cleaver',
          ),
        ],
      ),
      children: [
        EeHeader(title: 'Registros de consumos', subtitle: boiler.displayName),
        const SizedBox(height: 14),
        if (_isLoading)
          const LinearProgressIndicator(minHeight: 3)
        else if (_errorMessage.isNotEmpty)
          MessageBox(type: MessageType.error, message: _errorMessage)
        else
          InfoPanel(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _view == _BoilerReadingView.real
                              ? 'Lecturas acumuladas'
                              : 'Consumo por hora',
                          style: Theme.of(context).textTheme.titleMediumBold,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _view == _BoilerReadingView.real
                              ? selectedReadings.isEmpty
                                    ? 'Sin registros para esta caldera.'
                                    : 'Mostrando $visibleCount de ${selectedReadings.length}.'
                              : normalizedReadings.isEmpty
                              ? 'Sin horas completas disponibles.'
                              : 'Mostrando $visibleItemsCount de $selectedCount horas; reparto uniforme.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar registros',
                    onPressed: _loadReadings,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<_BoilerReadingView>(
                  key: const Key('boiler-reading-view-toggle'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _BoilerReadingView.real,
                      label: Text('Tomas reales'),
                    ),
                    ButtonSegment(
                      value: _BoilerReadingView.normalized,
                      label: Text('Normalizadas'),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) => setState(() {
                    _view = selection.first;
                  }),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedCount == 0)
                EmptyState(
                  text: _view == _BoilerReadingView.real
                      ? 'Las lecturas apareceran aqui despues de ser confirmadas en la nube.'
                      : 'No hay horas completas entre lecturas para mostrar.',
                )
              else ...[
                if (_view == _BoilerReadingView.real)
                  _ReadingsList(readings: visibleReadings)
                else
                  _NormalizedReadingsList(
                    readings: normalizedReadings
                        .take(visibleItemsCount)
                        .toList(),
                  ),
                if (visibleItemsCount < selectedCount) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('load-more-boiler-readings'),
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Cargar 15 mas'),
                    ),
                  ),
                ],
              ],
            ],
          ),
      ],
    );
  }

  int get _navigationIndex {
    final boilerIndex = boilerDefinitions.indexWhere(
      (boiler) => boiler.id == _selectedBoilerId,
    );
    return boilerIndex < 2 ? boilerIndex : 3;
  }

  void _selectDestination(int index) {
    FocusScope.of(context).unfocus();
    if (index == 2) {
      returnToHome(context);
      return;
    }
    final boilerIndex = index < 2 ? index : 2;
    setState(() => _selectedBoilerId = boilerDefinitions[boilerIndex].id);
  }

  void _loadMore() {
    setState(() {
      _visibleByBoiler[_selectedBoilerId] =
          (_visibleByBoiler[_selectedBoilerId] ?? _pageSize) + _pageSize;
    });
  }
}

enum _BoilerReadingView { real, normalized }

class _ReadingsList extends StatelessWidget {
  const _ReadingsList({required this.readings});

  final List<BoilerReading> readings;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('boiler-readings-list'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: readings.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _ReadingRow(
        key: Key('boiler-reading-row-$index'),
        reading: readings[index],
        index: index,
      ),
    );
  }
}

class _NormalizedReadingsList extends StatelessWidget {
  const _NormalizedReadingsList({required this.readings});

  final List<NormalizedBoilerHour> readings;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('normalized-boiler-readings-list'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: readings.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) =>
          _NormalizedReadingRow(reading: readings[index], index: index),
    );
  }
}

class _NormalizedReadingRow extends StatelessWidget {
  const _NormalizedReadingRow({required this.reading, required this.index});

  final NormalizedBoilerHour reading;
  final int index;

  @override
  Widget build(BuildContext context) {
    final local = reading.hourEnd.toLocal();
    String time(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    String date(DateTime value) =>
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    _ReadingValue metric(double? value, String unit) => value == null
        ? const _ReadingValue('-', '')
        : _ReadingValue(Formats.noDecimal(value), unit);

    return Padding(
      key: Key('normalized-boiler-reading-row-$index'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: brandRed),
              const SizedBox(width: 7),
              Text(
                date(local),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                time(local),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ReadingMetric(
                    key: Key('normalized-bunker-$index'),
                    label: 'Bunker',
                    readingValue: metric(reading.bunkerGallons, 'gal'),
                  ),
                ),
                const VerticalDivider(width: 12),
                Expanded(
                  child: _ReadingMetric(
                    key: Key('normalized-water-$index'),
                    label: 'Agua',
                    readingValue: metric(reading.waterGallons, 'gal'),
                  ),
                ),
                const VerticalDivider(width: 12),
                Expanded(
                  child: _ReadingMetric(
                    key: Key('normalized-steam-$index'),
                    label: 'Vapor',
                    readingValue: metric(reading.steamKg, 'kg'),
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

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading, required this.index, super.key});

  final BoilerReading reading;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bunker = _displayValue(reading, 'bunker');
    final water = _displayValue(reading, 'water');
    final steam = reading.steamTotal == null
        ? const _ReadingValue('-', '')
        : _displayValue(reading, 'steam');
    final local = reading.recordedAt.toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: brandRed),
              const SizedBox(width: 7),
              Text(
                _date(local),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                _time(local),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ReadingMetric(
                    key: Key('boiler-reading-value-bunker-$index'),
                    label: 'Bunker',
                    readingValue: bunker,
                  ),
                ),
                const VerticalDivider(width: 12),
                Expanded(
                  child: _ReadingMetric(
                    key: Key('boiler-reading-value-water-$index'),
                    label: 'Agua',
                    readingValue: water,
                  ),
                ),
                const VerticalDivider(width: 12),
                Expanded(
                  child: _ReadingMetric(
                    key: Key('boiler-reading-value-steam-$index'),
                    label: 'Vapor',
                    readingValue: steam,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _ReadingValue _displayValue(BoilerReading reading, String key) {
    final original = reading.originalInputs[key];
    if (original is Map) {
      final value = _toDouble(original['value']);
      if (value != null) {
        return _ReadingValue(
          _formatNumber(value),
          key == 'steam'
              ? _friendlyUnit(reading.steamUnit)
              : _friendlyUnit('${original['unit'] ?? ''}'),
        );
      }
    }
    return switch (key) {
      'bunker' => _ReadingValue(
        _formatNumber(reading.fuelTotal),
        _friendlyUnit(reading.bunkerUnit),
      ),
      'water' => _ReadingValue(
        _formatNumber(reading.waterTotal),
        _friendlyUnit(reading.waterUnit),
      ),
      'steam' => _ReadingValue(
        _formatNumber(reading.steamTotal ?? 0),
        _friendlyUnit(reading.steamUnit),
      ),
      _ => const _ReadingValue('-', ''),
    };
  }

  static String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  static String _time(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static String _formatNumber(double value) {
    return Formats.noDecimal(value);
  }

  static String _friendlyUnit(String unit) {
    return switch (unit) {
      'counter_x10_L' => 'L',
      pendingUnit => 's/u',
      '' => 's/u',
      _ => unit,
    };
  }
}

class _ReadingMetric extends StatelessWidget {
  const _ReadingMetric({
    required this.label,
    required this.readingValue,
    super.key,
  });

  final String label;
  final _ReadingValue readingValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: mutedColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 28,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              readingValue.value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          readingValue.unit,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
      ],
    );
  }
}

class _ReadingValue {
  const _ReadingValue(this.value, this.unit);

  final String value;
  final String unit;
}
