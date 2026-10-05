part of '../main.dart';

class MaintenanceWeekScreen extends StatelessWidget {
  const MaintenanceWeekScreen({required this.operator, super.key});

  final AuthenticatedOperator operator;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activeWeek = _maintenanceWeekFor(now);
    final weeks = List.generate(5, (index) => activeWeek + index);
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Mi semana de auditoría',
          subtitle: 'Asignaciones cruzadas sin autoauditoría.',
        ),
        const SizedBox(height: 14),
        MessageBox(
          type: MessageType.info,
          message:
              'La semana activa cambia el viernes a las 16:00. Tus zonas nunca auditarán una zona que tengas a tu cargo.',
        ),
        const SizedBox(height: 12),
        for (final week in weeks) _weekCard(context, week, activeWeek),
      ],
    );
  }

  Widget _weekCard(BuildContext context, int weekNumber, int activeWeek) {
    final isActive = weekNumber == activeWeek;
    final assignments = operator.maintenanceZoneNumbers.map((source) {
      final target = _targetZone(source, weekNumber);
      return (source: source, target: target);
    }).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isActive ? const Color(0xfffff4f4) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Semana $weekNumber${isActive ? ' · ACTUAL' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final assignment in assignments)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _assignmentDetails(assignment.target),
              ),
          ],
        ),
      ),
    );
  }

  Widget _assignmentDetails(int target) {
    final zone = maintenanceZoneByNumber(target);
    if (zone == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Auditar: ${zone.process}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Text('Sección: ${zone.section} · Zona ${zone.number}'),
        Text('Responsable(s): ${zone.responsibles.join(', ')}', softWrap: true),
      ],
    );
  }

  int _targetZone(int source, int weekNumber) {
    final ownZones = operator.maintenanceZoneNumbers.toSet();
    final offset = ((weekNumber - 1) % (maintenanceZones.length - 1)) + 1;
    var candidate = ((source + offset - 1) % maintenanceZones.length) + 1;
    for (var attempt = 0; attempt < maintenanceZones.length; attempt += 1) {
      if (!ownZones.contains(candidate)) return candidate;
      candidate = candidate % maintenanceZones.length + 1;
    }
    return source;
  }
}

int _maintenanceWeekFor(DateTime date) {
  final localDate = DateTime(date.year, date.month, date.day);
  final thursday = localDate.add(Duration(days: 4 - localDate.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeekStart = firstThursday.subtract(
    Duration(days: firstThursday.weekday - 1),
  );
  return thursday.difference(firstWeekStart).inDays ~/ 7 + 1;
}
