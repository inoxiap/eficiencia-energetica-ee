part of '../main.dart';

class MaintenanceHistoryScreen extends StatefulWidget {
  const MaintenanceHistoryScreen({required this.store, super.key});

  final MaintenanceReportStore store;

  @override
  State<MaintenanceHistoryScreen> createState() =>
      _MaintenanceHistoryScreenState();
}

class _MaintenanceHistoryScreenState extends State<MaintenanceHistoryScreen> {
  List<MaintenanceReportSummary> _reports = [];
  MaintenanceReportType _selectedType = MaintenanceReportType.leak;
  DateTimeRange? _dateRange;
  String? _updatingId;
  bool _isLoading = true;
  String _message = '';
  MessageType _messageType = MessageType.info;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReports();
    final openCount = filtered.where((item) => !item.workOrderCreated).length;
    final otCount = filtered
        .where((item) => item.workOrderCreated && !item.workCompleted)
        .length;
    final completedCount = filtered.where((item) => item.workCompleted).length;
    return AppShell(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedType == MaintenanceReportType.leak ? 0 : 2,
        onDestinationSelected: (index) {
          if (index == 1) {
            returnToHome(context);
            return;
          }
          setState(() {
            _selectedType = index == 0
                ? MaintenanceReportType.leak
                : MaintenanceReportType.barePipe;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Fugas',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Casa',
          ),
          NavigationDestination(
            icon: Icon(Icons.thermostat_outlined),
            selectedIcon: Icon(Icons.thermostat),
            label: 'Tuberias',
          ),
        ],
      ),
      children: [
        const EeHeader(
          title: 'Seguimiento de reportes',
          subtitle: 'Consulta lo reportado y actualiza su avance.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _dateRange == null
                      ? 'Todas las fechas'
                      : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoading ? null : _loadReports,
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
            ),
            if (_dateRange != null)
              IconButton(
                onPressed: () => setState(() => _dateRange = null),
                tooltip: 'Quitar filtro',
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
          ],
        ),
        const SizedBox(height: 12),
        MetricGrid(
          metrics: [
            Metric('Sin OT', openCount.toString()),
            Metric('Con OT', otCount.toString()),
            Metric('Ejecutados', completedCount.toString()),
          ],
        ),
        if (_isLoading) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(minHeight: 3),
        ],
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
        const SizedBox(height: 14),
        if (!_isLoading && filtered.isEmpty)
          const EmptyState(
            text: 'No hay reportes para el tipo y las fechas seleccionadas.',
          )
        else
          for (final report in filtered) ...[
            _MaintenanceReportCard(
              report: report,
              isUpdating: _updatingId == report.id,
              onWorkOrderChanged: (value) => _updateWorkflow(
                report,
                workOrderCreated: value,
                workCompleted: value ? report.workCompleted : false,
              ),
              onCompletedChanged: report.workOrderCreated
                  ? (value) => _updateWorkflow(
                      report,
                      workOrderCreated: true,
                      workCompleted: value,
                    )
                  : null,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  List<MaintenanceReportSummary> _filteredReports() {
    return _reports.where((report) {
      if (report.type != _selectedType) return false;
      final range = _dateRange;
      if (range == null) return true;
      final date = DateTime(
        report.createdAt.year,
        report.createdAt.month,
        report.createdAt.day,
      );
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
      helpText: 'Filtrar reportes por fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (!mounted || selected == null) return;
    setState(() => _dateRange = selected);
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    try {
      final reports = await widget.store.loadReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } on MaintenanceReportException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messageType = MessageType.warning;
        _message = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messageType = MessageType.error;
        _message = 'No fue posible cargar los reportes desde Firebase.';
      });
    }
  }

  Future<void> _updateWorkflow(
    MaintenanceReportSummary report, {
    required bool workOrderCreated,
    required bool workCompleted,
  }) async {
    if (_updatingId != null) return;
    setState(() {
      _updatingId = report.id;
      _message = '';
    });
    try {
      await widget.store.updateWorkflow(
        report: report,
        workOrderCreated: workOrderCreated,
        workCompleted: workCompleted,
      );
      if (!mounted) return;
      final status = workCompleted
          ? 'completed'
          : workOrderCreated
          ? 'work_order_created'
          : 'open';
      setState(() {
        _reports = _reports
            .map(
              (item) => item.id == report.id && item.type == report.type
                  ? item.copyWith(
                      workOrderCreated: workOrderCreated,
                      workCompleted: workOrderCreated && workCompleted,
                      status: status,
                    )
                  : item,
            )
            .toList();
        _updatingId = null;
        _messageType = MessageType.success;
        _message = 'Estado actualizado en Firebase.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _updatingId = null;
        _messageType = MessageType.error;
        _message = 'No fue posible actualizar el estado. Intenta otra vez.';
      });
    }
  }
}

class _MaintenanceReportCard extends StatelessWidget {
  const _MaintenanceReportCard({
    required this.report,
    required this.isUpdating,
    required this.onWorkOrderChanged,
    required this.onCompletedChanged,
  });

  final MaintenanceReportSummary report;
  final bool isUpdating;
  final ValueChanged<bool> onWorkOrderChanged;
  final ValueChanged<bool>? onCompletedChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      const SizedBox(height: 3),
                      Text(report.detail),
                      if (report.equipmentName.isNotEmpty)
                        Text(
                          report.equipmentName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${Formats.date(report.createdAt)} - ${report.createdByName}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            CheckboxListTile(
              value: report.workOrderCreated,
              onChanged: isUpdating
                  ? null
                  : (value) => onWorkOrderChanged(value ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('OT generada'),
            ),
            CheckboxListTile(
              value: report.workCompleted,
              onChanged: isUpdating || onCompletedChanged == null
                  ? null
                  : (value) => onCompletedChanged!(value ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Trabajo ejecutado'),
              subtitle: report.workOrderCreated
                  ? null
                  : const Text('Primero confirma que la OT fue generada.'),
            ),
            if (isUpdating) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

class _ReportThumbnail extends StatelessWidget {
  const _ReportThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 92,
        height: 78,
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xffedf2f3),
                child: Icon(Icons.image_not_supported_outlined),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xffedf2f3),
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
      ),
    );
  }
}
