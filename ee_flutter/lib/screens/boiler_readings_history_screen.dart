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
                          'Lecturas acumuladas',
                          style: Theme.of(context).textTheme.titleMediumBold,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selectedReadings.isEmpty
                              ? 'Sin registros para esta caldera.'
                              : 'Mostrando $visibleCount de ${selectedReadings.length}.',
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
              const SizedBox(height: 12),
              if (visibleReadings.isEmpty)
                const EmptyState(
                  text:
                      'Las lecturas apareceran aqui despues de ser confirmadas en la nube.',
                )
              else ...[
                _ReadingsTable(readings: visibleReadings),
                if (visibleCount < selectedReadings.length) ...[
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

class _ReadingsTable extends StatelessWidget {
  const _ReadingsTable({required this.readings});

  final List<BoilerReading> readings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        key: const Key('boiler-readings-table'),
        headingRowColor: WidgetStatePropertyAll(
          brandRed.withValues(alpha: 0.08),
        ),
        horizontalMargin: 10,
        columnSpacing: 18,
        columns: const [
          DataColumn(label: Text('Fecha y hora')),
          DataColumn(label: Text('Bunker'), numeric: true),
          DataColumn(label: Text('Agua'), numeric: true),
          DataColumn(label: Text('Vapor'), numeric: true),
        ],
        rows: [
          for (final reading in readings)
            DataRow(
              cells: [
                DataCell(Text(Formats.date(reading.recordedAt))),
                DataCell(Text(_originalValue(reading, 'bunker'))),
                DataCell(Text(_originalValue(reading, 'water'))),
                DataCell(
                  Text(
                    reading.steamTotal == null
                        ? '-'
                        : _originalValue(reading, 'steam'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _originalValue(BoilerReading reading, String key) {
    final original = reading.originalInputs[key];
    if (original is Map) {
      final value = _toDouble(original['value']);
      if (value != null) {
        return '${_formatNumber(value)} ${_friendlyUnit('${original['unit'] ?? ''}')}';
      }
    }
    return switch (key) {
      'bunker' =>
        '${_formatNumber(reading.fuelTotal)} ${_friendlyUnit(reading.bunkerUnit)}',
      'water' =>
        '${_formatNumber(reading.waterTotal)} ${_friendlyUnit(reading.waterUnit)}',
      'steam' =>
        '${_formatNumber(reading.steamTotal ?? 0)} ${_friendlyUnit(reading.steamUnit)}',
      _ => '-',
    };
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? Formats.noDecimal(value)
        : Formats.two(value);
  }

  static String _friendlyUnit(String unit) {
    return switch (unit) {
      'counter_x10_L' => 'x10 L',
      pendingUnit => 's/u',
      '' => 's/u',
      _ => unit,
    };
  }
}
