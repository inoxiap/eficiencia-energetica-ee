part of '../main.dart';

class MaintenanceRegistrationScreen extends StatefulWidget {
  const MaintenanceRegistrationScreen({required this.authService, super.key});

  final OperatorAuthService authService;

  @override
  State<MaintenanceRegistrationScreen> createState() =>
      _MaintenanceRegistrationScreenState();
}

class _MaintenanceRegistrationScreenState
    extends State<MaintenanceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nationalId = TextEditingController();
  final _pin = TextEditingController();
  final _pinConfirmation = TextEditingController();
  final _selectedZones = <int>[];
  int? _zoneToAdd;
  bool _isSubmitting = false;
  String _message = '';
  MessageType _messageType = MessageType.info;

  @override
  void dispose() {
    _name.dispose();
    _nationalId.dispose();
    _pin.dispose();
    _pinConfirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableZones = maintenanceZones
        .where((zone) => !_selectedZones.contains(zone.number))
        .toList();
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Registro de mantenimiento',
          subtitle: 'Crea tu acceso y selecciona las zonas a tu cargo.',
        ),
        const SizedBox(height: 14),
        InfoPanel(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_isSubmitting,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                    ),
                    validator: (value) => (value ?? '').trim().length < 3
                        ? 'Ingresa tu nombre completo.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nationalId,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Cédula',
                      counterText: '',
                    ),
                    validator: (value) =>
                        !RegExp(r'^\d{10}$').hasMatch((value ?? '').trim())
                        ? 'La cédula debe tener 10 dígitos.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pin,
                    enabled: !_isSubmitting,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'PIN de 4 a 6 dígitos',
                      counterText: '',
                    ),
                    validator: (value) =>
                        !RegExp(r'^\d{4,6}$').hasMatch(value ?? '')
                        ? 'Usa entre 4 y 6 dígitos.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pinConfirmation,
                    enabled: !_isSubmitting,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Repite el PIN',
                      counterText: '',
                    ),
                    validator: (value) =>
                        value != _pin.text ? 'Los PINes no coinciden.' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_zoneToAdd),
                    initialValue: _zoneToAdd,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Selecciona una zona',
                      helperText: 'Puedes agregar más de una zona.',
                    ),
                    items: availableZones
                        .map(
                          (zone) => DropdownMenuItem<int>(
                            value: zone.number,
                            child: Text(
                              'Zona ${zone.number} - ${zone.section} - ${zone.process}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => availableZones
                        .map(
                          (zone) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Zona ${zone.number} - ${zone.section} - ${zone.process}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _zoneToAdd = value),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting || _zoneToAdd == null
                          ? null
                          : _addZone,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar zona'),
                    ),
                  ),
                  if (_selectedZones.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Zonas seleccionadas',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final number in _selectedZones)
                      _selectedZoneTile(number),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            EeActionButton(
              icon: Icons.person_add_alt_1,
              label: _isSubmitting ? 'Registrando...' : 'Crear acceso',
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
      ],
    );
  }

  Widget _selectedZoneTile(int number) {
    final zone = maintenanceZoneByNumber(number)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(child: Text('$number')),
        title: Text(zone.process),
        subtitle: Text(zone.section),
        trailing: IconButton(
          tooltip: 'Quitar zona',
          onPressed: _isSubmitting
              ? null
              : () => setState(() => _selectedZones.remove(number)),
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ),
    );
  }

  void _addZone() {
    final selected = _zoneToAdd;
    if (selected == null) return;
    if (_selectedZones.contains(selected)) {
      setState(() {
        _messageType = MessageType.warning;
        _message = 'Esa zona ya está seleccionada.';
      });
      return;
    }
    setState(() {
      _selectedZones.add(selected);
      _selectedZones.sort();
      _zoneToAdd = null;
      _message = '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedZones.isEmpty) {
      setState(() {
        _messageType = MessageType.warning;
        _message = 'Agrega al menos una zona a tu cargo.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _message = '';
    });
    try {
      await widget.authService.register(
        fullName: _name.text,
        nationalId: _nationalId.text,
        pin: _pin.text,
        maintenanceZoneNumbers: _selectedZones,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.success;
        _message = 'Registro creado. Ya puedes usar los módulos asignados.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    } on OperatorAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.error;
        _message = error.message;
      });
    }
  }
}

class MaintenanceAddZoneScreen extends StatefulWidget {
  const MaintenanceAddZoneScreen({
    required this.operator,
    required this.authService,
    super.key,
  });

  final AuthenticatedOperator operator;
  final OperatorAuthService authService;

  @override
  State<MaintenanceAddZoneScreen> createState() =>
      _MaintenanceAddZoneScreenState();
}

class _MaintenanceAddZoneScreenState extends State<MaintenanceAddZoneScreen> {
  late final List<int> _zones;
  int? _zoneToAdd;
  bool _isSubmitting = false;
  String _message = '';
  MessageType _messageType = MessageType.info;

  @override
  void initState() {
    super.initState();
    _zones = [...widget.operator.maintenanceZoneNumbers]..sort();
  }

  @override
  Widget build(BuildContext context) {
    final availableZones = maintenanceZones
        .where((zone) => !_zones.contains(zone.number))
        .toList();
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Agregar zona',
          subtitle: 'Completa las zonas que tienes a tu cargo.',
        ),
        const SizedBox(height: 14),
        InfoPanel(
          children: [
            Text(
              'Tus zonas actuales',
              style: Theme.of(context).textTheme.titleMediumBold,
            ),
            const SizedBox(height: 8),
            if (_zones.isEmpty)
              const Text('Todavia no tienes zonas registradas.')
            else
              for (final number in _zones) _zoneSummary(number),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(_zoneToAdd),
              initialValue: _zoneToAdd,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Selecciona la zona que falta',
                helperText: 'No puedes agregar una zona repetida.',
              ),
              items: availableZones
                  .map(
                    (zone) => DropdownMenuItem<int>(
                      value: zone.number,
                      child: Text(
                        zone.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _zoneToAdd = value),
            ),
            const SizedBox(height: 12),
            EeActionButton(
              icon: Icons.add_location_alt_outlined,
              label: _isSubmitting ? 'Agregando zona...' : 'Agregar zona',
              onPressed: _isSubmitting || _zoneToAdd == null ? null : _addZone,
            ),
          ],
        ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
      ],
    );
  }

  Widget _zoneSummary(int number) {
    final zone = maintenanceZoneByNumber(number);
    if (zone == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('Zona $number · ${zone.section} · ${zone.process}'),
    );
  }

  Future<void> _addZone() async {
    final number = _zoneToAdd;
    if (number == null) return;
    setState(() {
      _isSubmitting = true;
      _message = '';
    });
    try {
      await widget.authService.addMaintenanceZone(zoneNumber: number);
      if (!mounted) return;
      setState(() {
        _zones.add(number);
        _zones.sort();
        _zoneToAdd = null;
        _isSubmitting = false;
        _messageType = MessageType.success;
        _message = 'Zona agregada correctamente a tu perfil.';
      });
    } on OperatorAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.error;
        _message = error.message;
      });
    }
  }
}
