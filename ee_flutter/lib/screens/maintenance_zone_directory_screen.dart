part of '../main.dart';

class MaintenanceZoneDirectoryScreen extends StatefulWidget {
  const MaintenanceZoneDirectoryScreen({super.key});

  @override
  State<MaintenanceZoneDirectoryScreen> createState() =>
      _MaintenanceZoneDirectoryScreenState();
}

class _MaintenanceZoneDirectoryScreenState
    extends State<MaintenanceZoneDirectoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = maintenanceZones.where((zone) {
      if (query.isEmpty) return true;
      return zone.number.toString() == query ||
          zone.section.toLowerCase().contains(query) ||
          zone.process.toLowerCase().contains(query) ||
          zone.responsibles.any(
            (responsible) => responsible.toLowerCase().contains(query),
          );
    }).toList();
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Zonas y responsables',
          subtitle: 'Consulta la distribución de la matriz de mantenimiento.',
        ),
        const SizedBox(height: 14),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar zona, proceso o responsable',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        Text(
          '${filtered.length} zonas',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final zone in filtered) ...[
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(child: Text('${zone.number}')),
              title: Text(zone.process),
              subtitle: Text(
                '${zone.section}\nResponsables: ${zone.responsibles.join(', ')}',
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 7),
        ],
        if (filtered.isEmpty)
          const EmptyState(text: 'No encontramos zonas con ese criterio.'),
      ],
    );
  }
}
