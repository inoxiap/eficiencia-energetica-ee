part of '../main.dart';

class SteamTrapModuleScreen extends StatefulWidget {
  const SteamTrapModuleScreen({
    required this.store,
    required this.cloudinaryService,
    required this.operatorSession,
    required this.operatorAuthService,
    super.key,
  });

  final SteamTrapStore store;
  final CloudinaryService cloudinaryService;
  final OperatorSession operatorSession;
  final OperatorAuthService operatorAuthService;

  @override
  State<SteamTrapModuleScreen> createState() => _SteamTrapModuleScreenState();
}

class _SteamTrapModuleScreenState extends State<SteamTrapModuleScreen> {
  AuthenticatedOperator? _user;
  SteamTrapRecord? _editing;
  var _tab = 0;
  var _loading = true;
  var _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await widget.operatorSession.currentOperator();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _openAccess() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OperatorAccessScreen(
          authService: widget.operatorAuthService,
          operatorSession: widget.operatorSession,
        ),
      ),
    );
    await _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_business_outlined),
            selectedIcon: Icon(Icons.add_business),
            label: 'Ingresar trampa',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search),
            label: 'Consulta',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      key: const Key('steam-trap-home-button'),
                      tooltip: 'Volver a casa',
                      onPressed: () => returnToHome(context),
                      icon: const Icon(Icons.home_outlined),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: EeHeader(
                        title: 'Trampas de vapor',
                        subtitle: 'Inventario y levantamiento fotografico.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_user == null)
                  InfoPanel(
                    children: [
                      const Text(
                        'Este modulo requiere una sesion activa para proteger los levantamientos.',
                      ),
                      const SizedBox(height: 14),
                      EeActionButton(
                        icon: Icons.login,
                        label: 'Ingresar como usuario',
                        onPressed: _openAccess,
                      ),
                    ],
                  )
                else if (_tab == 0)
                  SteamTrapEntryPanel(
                    key: ValueKey(_editing?.id ?? 'new-$_refreshToken'),
                    store: widget.store,
                    cloudinaryService: widget.cloudinaryService,
                    operator: _user!,
                    initialRecord: _editing,
                    onCompleted: () => setState(() {
                      _editing = null;
                      _refreshToken++;
                      _tab = 1;
                    }),
                  )
                else
                  SteamTrapQueryPanel(
                    key: ValueKey(_refreshToken),
                    store: widget.store,
                    isAdmin: _user!.role == 'admin',
                    companyName: _user!.companyName,
                    onEdit: (record) => setState(() {
                      _editing = record;
                      _tab = 0;
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SteamTrapEntryPanel extends StatefulWidget {
  const SteamTrapEntryPanel({
    required this.store,
    required this.cloudinaryService,
    required this.operator,
    required this.onCompleted,
    this.initialRecord,
    super.key,
  });

  final SteamTrapStore store;
  final CloudinaryService cloudinaryService;
  final AuthenticatedOperator operator;
  final SteamTrapRecord? initialRecord;
  final VoidCallback onCompleted;

  @override
  State<SteamTrapEntryPanel> createState() => _SteamTrapEntryPanelState();
}

class _SteamTrapEntryPanelState extends State<SteamTrapEntryPanel> {
  final _picker = ImagePicker();
  final _zone = TextEditingController();
  final _equipment = TextEditingController();
  final _serviceOther = TextEditingController();
  final _trapOther = TextEditingController();
  final _diameterOther = TextEditingController();
  final _comments = TextEditingController();
  Uint8List? _closeBytes;
  Uint8List? _generalBytes;
  SteamTrapPhoto? _closePhoto;
  SteamTrapPhoto? _generalPhoto;
  SteamTrapEntryMode _mode = SteamTrapEntryMode.newEntry;
  String _sectionCode = '';
  String _serviceId = '';
  String _diameter = '';
  String _trapTypeId = '';
  String _recovery = 'to_confirm';
  String _diagnosis = 'pending';
  String? _recordId;
  String? _tag;
  var _busy = false;
  var _reviewed = false;
  String _message = '';
  MessageType _messageType = MessageType.info;

  static const _diameters = [
    '1/2 in',
    '3/4 in',
    '1 in',
    '1 1/4 in',
    '1 1/2 in',
    '2 in',
    '2 1/2 in',
    '3 in',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    if (record != null) {
      _recordId = record.id;
      _tag = record.tag;
      _sectionCode = record.sectionCode;
      _zone.text = record.zone;
      _equipment.text = record.equipmentName;
      _serviceId = SteamTrapService.values.any((v) => v.id == record.serviceId)
          ? record.serviceId
          : 'other';
      if (_serviceId == 'other') _serviceOther.text = record.serviceName;
      _diameter = _diameters.contains(record.diameter)
          ? record.diameter
          : 'Otro';
      if (_diameter == 'Otro') _diameterOther.text = record.diameter;
      _trapTypeId = SteamTrapType.values.any((v) => v.id == record.trapTypeId)
          ? record.trapTypeId
          : 'other';
      if (_trapTypeId == 'other') _trapOther.text = record.trapTypeName;
      _recovery = record.condensateRecoveryId.isEmpty
          ? 'to_confirm'
          : record.condensateRecoveryId;
      _diagnosis = record.diagnosisStatus;
      _comments.text = record.comments;
      _closePhoto = record.closePhoto;
      _generalPhoto = record.generalPhoto;
      _mode = SteamTrapEntryMode.inventoryValidation;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _zone,
      _equipment,
      _serviceOther,
      _trapOther,
      _diameterOther,
      _comments,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectionLocked = _tag != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<SteamTrapEntryMode>(
          segments: const [
            ButtonSegment(
              value: SteamTrapEntryMode.newEntry,
              icon: Icon(Icons.add),
              label: Text('Nueva'),
            ),
            ButtonSegment(
              value: SteamTrapEntryMode.inventoryValidation,
              icon: Icon(Icons.fact_check_outlined),
              label: Text('Validar inventario'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: sectionLocked
              ? null
              : (value) => setState(() => _mode = value.first),
        ),
        if (_tag != null) ...[
          const SizedBox(height: 12),
          InfoPanel(
            children: [
              TwoColumnInfo(
                leftLabel: 'TAG asignado',
                leftValue: _tag!,
                rightLabel: 'Estado',
                rightValue: widget.initialRecord?.status == 'complete'
                    ? 'Completo'
                    : 'Borrador',
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '1. Evidencia fotografica',
          style: Theme.of(context).textTheme.titleMediumBold,
        ),
        const SizedBox(height: 6),
        const Text(
          'Toma primero las dos fotos. Podras cambiarlas antes de guardar.',
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final vertical = constraints.maxWidth < 520;
            final cards = [
              Expanded(
                child: _photoCard(
                  type: 'close',
                  title: 'Foto cercana',
                  subtitle: 'Trampa y conexiones',
                  bytes: _closeBytes,
                  photo: _closePhoto,
                ),
              ),
              Expanded(
                child: _photoCard(
                  type: 'general',
                  title: 'Foto general',
                  subtitle: 'Equipo o ubicacion',
                  bytes: _generalBytes,
                  photo: _generalPhoto,
                ),
              ),
            ];
            return vertical
                ? Column(
                    children: [
                      SizedBox(width: double.infinity, child: cards[0].child),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: cards[1].child),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [cards[0], const SizedBox(width: 10), cards[1]],
                  );
          },
        ),
        const SizedBox(height: 18),
        Text(
          '2. Identificacion',
          style: Theme.of(context).textTheme.titleMediumBold,
        ),
        const SizedBox(height: 10),
        Text('Seccion *', style: Theme.of(context).textTheme.labelBold),
        const SizedBox(height: 6),
        AbsorbPointer(
          absorbing: sectionLocked,
          child: Opacity(
            opacity: sectionLocked ? 0.72 : 1,
            child: EmbeddedWheelPicker<String>(
              value: _sectionCode,
              height: 112,
              options: [
                const PickerOption('', 'Selecciona una seccion'),
                ...plantSections.map(
                  (s) => PickerOption(
                    s.code,
                    '${s.code} - ${s.displayName.toUpperCase()}',
                  ),
                ),
              ],
              onSelected: (value) => setState(() {
                _sectionCode = value;
                _invalidate();
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _zone,
          decoration: const InputDecoration(labelText: 'Zona *'),
          onChanged: (_) => setState(_invalidate),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _equipment,
          decoration: const InputDecoration(labelText: 'Equipo o sistema *'),
          onChanged: (_) => setState(_invalidate),
        ),
        const SizedBox(height: 14),
        _wheelLabel('Servicio o aplicacion *'),
        EmbeddedWheelPicker<String>(
          value: _serviceId,
          height: 112,
          options: [
            const PickerOption('', 'Selecciona el servicio'),
            ...SteamTrapService.values.map((v) => PickerOption(v.id, v.label)),
          ],
          onSelected: (value) => setState(() {
            _serviceId = value;
            _invalidate();
          }),
        ),
        if (_serviceId == 'other') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _serviceOther,
            decoration: const InputDecoration(
              labelText: 'Especifica el servicio *',
            ),
            onChanged: (_) => setState(_invalidate),
          ),
        ],
        const SizedBox(height: 14),
        _wheelLabel('Diametro *'),
        EmbeddedWheelPicker<String>(
          value: _diameter,
          height: 112,
          options: [
            const PickerOption('', 'Selecciona el diametro'),
            ..._diameters.map((v) => PickerOption(v, v)),
          ],
          onSelected: (value) => setState(() {
            _diameter = value;
            _invalidate();
          }),
        ),
        if (_diameter == 'Otro') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _diameterOther,
            decoration: const InputDecoration(
              labelText: 'Especifica diametro y unidad *',
            ),
            onChanged: (_) => setState(_invalidate),
          ),
        ],
        const SizedBox(height: 14),
        _wheelLabel('Tipo de trampa *'),
        EmbeddedWheelPicker<String>(
          value: _trapTypeId,
          height: 112,
          options: [
            const PickerOption('', 'Selecciona el tipo'),
            ...SteamTrapType.values.map((v) => PickerOption(v.id, v.label)),
          ],
          onSelected: (value) => setState(() {
            _trapTypeId = value;
            _invalidate();
          }),
        ),
        if (_trapTypeId == 'other') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _trapOther,
            decoration: const InputDecoration(
              labelText: 'Especifica el tipo de trampa *',
            ),
            onChanged: (_) => setState(_invalidate),
          ),
        ],
        const SizedBox(height: 14),
        _wheelLabel('Recuperacion de condensado *'),
        EmbeddedWheelPicker<String>(
          value: _recovery,
          height: 112,
          options: CondensateRecovery.values
              .map((v) => PickerOption(v.id, v.label))
              .toList(),
          onSelected: (value) => setState(() {
            _recovery = value;
            _invalidate();
          }),
        ),
        const SizedBox(height: 14),
        _wheelLabel('Estado del diagnostico'),
        EmbeddedWheelPicker<String>(
          value: _diagnosis,
          height: 112,
          options: const [
            PickerOption('pending', 'Pendiente'),
            PickerOption('operational', 'Operativa'),
            PickerOption('requires_attention', 'Requiere atencion'),
            PickerOption('out_of_service', 'Fuera de servicio'),
          ],
          onSelected: (value) => setState(() {
            _diagnosis = value;
            _invalidate();
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _comments,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Comentarios (opcional)',
          ),
          onChanged: (_) => setState(_invalidate),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar borrador'),
        ),
        const SizedBox(height: 10),
        EeActionButton(
          icon: Icons.fact_check_outlined,
          label: 'Revisar levantamiento',
          onPressed: _busy ? null : _review,
        ),
        if (_reviewed) ...[
          const SizedBox(height: 14),
          _summary(),
          const SizedBox(height: 10),
          EeActionButton(
            icon: Icons.cloud_upload_outlined,
            label: _busy ? 'Guardando...' : 'Confirmar y guardar',
            onPressed: _busy ? null : _complete,
          ),
        ],
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
      ],
    );
  }

  Widget _wheelLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelBold),
  );

  Widget _photoCard({
    required String type,
    required String title,
    required String subtitle,
    required Uint8List? bytes,
    required SteamTrapPhoto? photo,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: _busy ? null : () => _pickPhoto(type),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7),
                ),
                child: bytes != null
                    ? Image.memory(bytes, fit: BoxFit.cover)
                    : photo != null
                    ? Image.network(
                        photo.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined, size: 42),
                      )
                    : const ColoredBox(
                        color: Color(0xffedf1f2),
                        child: Center(
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 42,
                            color: tealColor,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: mutedColor,
                          ),
                        ),
                      ],
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

  Widget _summary() {
    final section = plantSectionByCode(_sectionCode);
    return InfoPanel(
      children: [
        Text('Resumen', style: Theme.of(context).textTheme.titleMediumBold),
        const SizedBox(height: 10),
        TwoColumnInfo(
          leftLabel: 'TAG',
          leftValue: _tag ?? 'Se asigna al guardar',
          rightLabel: 'Seccion',
          rightValue: section?.displayName ?? '',
        ),
        const SizedBox(height: 10),
        TwoColumnInfo(
          leftLabel: 'Zona',
          leftValue: _zone.text.trim(),
          rightLabel: 'Equipo',
          rightValue: _equipment.text.trim(),
        ),
        const SizedBox(height: 10),
        TwoColumnInfo(
          leftLabel: 'Servicio',
          leftValue: _serviceName,
          rightLabel: 'Tipo de trampa',
          rightValue: _trapName,
        ),
        const SizedBox(height: 10),
        TwoColumnInfo(
          leftLabel: 'Diametro',
          leftValue: _diameterValue,
          rightLabel: 'Usuario',
          rightValue: widget.operator.displayName,
        ),
        const SizedBox(height: 10),
        const LabelValue(
          label: 'Evidencias',
          value: 'Foto cercana y foto general listas',
        ),
      ],
    );
  }

  String get _serviceName => _serviceId == 'other'
      ? _serviceOther.text.trim()
      : SteamTrapService.values
                .where((v) => v.id == _serviceId)
                .map((v) => v.label)
                .firstOrNull ??
            '';
  String get _trapName => _trapTypeId == 'other'
      ? _trapOther.text.trim()
      : SteamTrapType.values
                .where((v) => v.id == _trapTypeId)
                .map((v) => v.label)
                .firstOrNull ??
            '';
  String get _diameterValue =>
      _diameter == 'Otro' ? _diameterOther.text.trim() : _diameter;

  Future<void> _pickPhoto(String type) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } catch (_) {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (type == 'close') {
        _closeBytes = bytes;
      } else {
        _generalBytes = bytes;
      }
      _invalidate();
    });
  }

  String? _validationError({required bool complete}) {
    if (_sectionCode.isEmpty) return 'Selecciona la seccion.';
    if (!complete) return null;
    if (_closeBytes == null && _closePhoto == null) {
      return 'Captura la foto cercana.';
    }
    if (_generalBytes == null && _generalPhoto == null) {
      return 'Captura la foto general.';
    }
    if (_zone.text.trim().isEmpty) return 'Ingresa la zona.';
    if (_equipment.text.trim().isEmpty) return 'Ingresa el equipo o sistema.';
    if (_serviceName.isEmpty) return 'Selecciona o especifica el servicio.';
    if (_diameterValue.isEmpty) return 'Selecciona o especifica el diametro.';
    if (_trapName.isEmpty) return 'Selecciona o especifica el tipo de trampa.';
    return null;
  }

  Future<void> _ensureReservation() async {
    if (_recordId != null && _tag != null) return;
    final section = plantSectionByCode(_sectionCode)!;
    final recordId = _recordId ??
        '${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(1 << 31).toRadixString(16)}';
    final record = await widget.store.reserveTag(
      recordId: recordId,
      section: section,
    );
    _recordId = recordId;
    _tag = record.tag;
  }

  Future<void> _saveDraft() async {
    final error = _validationError(complete: false);
    if (error != null) {
      _setMessage(MessageType.error, error);
      return;
    }
    await _persist('draft');
  }

  void _review() {
    final error = _validationError(complete: true);
    if (error != null) {
      _setMessage(MessageType.error, error);
      return;
    }
    setState(() {
      _reviewed = true;
      _message = 'Verifica el resumen antes de guardar.';
      _messageType = MessageType.info;
    });
  }

  Future<void> _complete() async {
    if (!_reviewed) return;
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar levantamiento'),
            content: Text(
              'Se guardara la trampa ${_tag ?? 'con un TAG nuevo'} a nombre de ${widget.operator.displayName}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Corregir'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted) return;
    await _persist('complete');
  }

  Future<void> _persist(String status) async {
    setState(() {
      _busy = true;
      _message = status == 'complete'
          ? 'Preparando registro...'
          : 'Guardando borrador...';
      _messageType = MessageType.info;
    });
    try {
      await _ensureReservation();
      if (status == 'complete') {
        _closePhoto = await _uploadIfNeeded('close', _closeBytes, _closePhoto);
        if (mounted) {
          setState(
            () => _message = 'Foto cercana lista. Procesando foto general...',
          );
        }
        _generalPhoto = await _uploadIfNeeded(
          'general',
          _generalBytes,
          _generalPhoto,
        );
      }
      await widget.store.saveRecord(_input(status));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messageType = MessageType.success;
        _message = status == 'complete'
            ? 'Trampa $_tag guardada correctamente.'
            : 'Borrador $_tag guardado.';
        _closeBytes = null;
        _generalBytes = null;
      });
      if (status == 'complete') widget.onCompleted();
    } catch (error) {
      if (_recordId != null && _tag != null && status == 'complete') {
        try {
          await widget.store.saveRecord(_input('upload_failed'));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messageType = MessageType.error;
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<SteamTrapPhoto?> _uploadIfNeeded(
    String type,
    Uint8List? bytes,
    SteamTrapPhoto? existing,
  ) async {
    if (bytes == null) return existing;
    final suffix = type == 'close' ? 'CERCA' : 'GENERAL';
    final fileName = '${_tag}_$suffix.jpg';
    final upload = await widget.cloudinaryService.uploadEvidence(
      bytes: bytes,
      reportId: _recordId!,
      fileName: fileName,
      publicId: '${_tag}_$suffix',
    );
    return SteamTrapPhoto(
      type: type,
      url: upload.secureUrl,
      publicId: upload.publicId,
      fileName: fileName,
      uploadedAt: DateTime.now(),
      ownerUid: widget.operator.uid,
      tag: _tag!,
    );
  }

  SteamTrapRecordInput _input(String status) => SteamTrapRecordInput(
    id: _recordId!,
    zone: _zone.text,
    equipmentName: _equipment.text,
    serviceId: _serviceId,
    serviceName: _serviceName,
    diameter: _diameterValue,
    trapTypeId: _trapTypeId,
    trapTypeName: _trapName,
    condensateRecoveryId: _recovery,
    comments: _comments.text,
    diagnosisStatus: _diagnosis,
    status: status,
    mode: _mode,
    closePhoto: _closePhoto,
    generalPhoto: _generalPhoto,
  );

  void _invalidate() {
    _reviewed = false;
    _message = '';
  }

  void _setMessage(MessageType type, String message) => setState(() {
    _messageType = type;
    _message = message;
  });
}

class SteamTrapQueryPanel extends StatefulWidget {
  const SteamTrapQueryPanel({
    required this.store,
    required this.isAdmin,
    required this.companyName,
    required this.onEdit,
    super.key,
  });
  final SteamTrapStore store;
  final bool isAdmin;
  final String companyName;
  final ValueChanged<SteamTrapRecord> onEdit;

  @override
  State<SteamTrapQueryPanel> createState() => _SteamTrapQueryPanelState();
}

class _SteamTrapQueryPanelState extends State<SteamTrapQueryPanel> {
  final _search = TextEditingController();
  final _export = const SteamTrapExportService();
  List<SteamTrapRecord> _records = const [];
  final Set<String> _selected = {};
  String _section = '';
  String _type = '';
  String _diagnosis = '';
  String _status = '';
  String _sort = 'date';
  DateTimeRange? _dates;
  var _visible = 15;
  var _loading = true;
  var _exporting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SteamTrapRecord> get _filtered {
    final needle = normalizeEquipmentName(_search.text);
    final values = _records.where((record) {
      final matchesText =
          needle.isEmpty ||
          normalizeEquipmentName(
            '${record.tag} ${record.zone} ${record.equipmentName}',
          ).contains(needle);
      final matchesDate =
          _dates == null ||
          (!record.createdAt.isBefore(
                DateTime(
                  _dates!.start.year,
                  _dates!.start.month,
                  _dates!.start.day,
                ),
              ) &&
              record.createdAt.isBefore(
                DateTime(
                  _dates!.end.year,
                  _dates!.end.month,
                  _dates!.end.day,
                ).add(const Duration(days: 1)),
              ));
      return matchesText &&
          matchesDate &&
          (_section.isEmpty || record.sectionCode == _section) &&
          (_type.isEmpty || record.trapTypeId == _type) &&
          (_diagnosis.isEmpty || record.diagnosisStatus == _diagnosis) &&
          (_status.isEmpty || record.status == _status);
    }).toList();
    values.sort(
      (a, b) => _sort == 'tag'
          ? a.tag.compareTo(b.tag)
          : b.updatedAt.compareTo(a.updatedAt),
    );
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final visible = filtered.take(_visible).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.isAdmin
              ? 'Todos los levantamientos'
              : widget.companyName.isEmpty
              ? 'Mis levantamientos'
              : 'Levantamientos de ${widget.companyName}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Buscar TAG, zona o equipo',
          ),
          onChanged: (_) => setState(() => _visible = 15),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterButton(
              'Seccion',
              _section,
              () => _choose(
                'Seccion',
                ['', ...plantSections.map((s) => s.code)],
                [
                  '',
                  ...plantSections.map((s) => '${s.code} - ${s.displayName}'),
                ],
                (v) => _section = v,
              ),
            ),
            _filterButton(
              'Tipo',
              _type,
              () => _choose(
                'Tipo de trampa',
                ['', ...SteamTrapType.values.map((v) => v.id)],
                ['Todos', ...SteamTrapType.values.map((v) => v.label)],
                (v) => _type = v,
              ),
            ),
            _filterButton(
              'Diagnostico',
              _diagnosis,
              () => _choose(
                'Diagnostico',
                const [
                  '',
                  'pending',
                  'operational',
                  'requires_attention',
                  'out_of_service',
                ],
                const [
                  'Todos',
                  'Pendiente',
                  'Operativa',
                  'Requiere atencion',
                  'Fuera de servicio',
                ],
                (v) => _diagnosis = v,
              ),
            ),
            _filterButton(
              'Estado',
              _status,
              () => _choose(
                'Estado',
                const ['', 'draft', 'complete', 'upload_failed'],
                const ['Todos', 'Borrador', 'Completo', 'Carga pendiente'],
                (v) => _status = v,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(
                _dates == null
                    ? 'Fecha'
                    : '${DateFormat('dd/MM').format(_dates!.start)} - ${DateFormat('dd/MM').format(_dates!.end)}',
              ),
              onPressed: _pickDates,
            ),
            ActionChip(
              avatar: const Icon(Icons.sort, size: 18),
              label: Text(_sort == 'date' ? 'Fecha reciente' : 'TAG'),
              onPressed: () =>
                  setState(() => _sort = _sort == 'date' ? 'tag' : 'date'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                '${filtered.length} registro(s)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            PopupMenuButton<String>(
              enabled: !_exporting && filtered.isNotEmpty,
              tooltip: 'Exportar',
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              onSelected: _runExport,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'xlsx', child: Text('Excel (.xlsx)')),
                PopupMenuItem(
                  value: 'photos',
                  child: Text('Fotografias (.zip)'),
                ),
                PopupMenuItem(
                  value: 'combined',
                  child: Text('Excel y fotografias'),
                ),
              ],
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error.isNotEmpty)
          MessageBox(type: MessageType.error, message: _error)
        else if (visible.isEmpty)
          const InfoPanel(
            children: [Text('No hay levantamientos con estos filtros.')],
          )
        else ...[
          ...visible.map(_recordCard),
          if (visible.length < filtered.length)
            TextButton.icon(
              onPressed: () => setState(() => _visible += 15),
              icon: const Icon(Icons.expand_more),
              label: const Text('Cargar 15 mas'),
            ),
        ],
      ],
    );
  }

  Widget _filterButton(String label, String value, VoidCallback onPressed) =>
      ActionChip(
        avatar: Icon(
          value.isEmpty ? Icons.filter_alt_outlined : Icons.filter_alt,
          size: 18,
        ),
        label: Text(value.isEmpty ? label : '$label activo'),
        onPressed: onPressed,
      );

  Widget _recordCard(SteamTrapRecord record) {
    final checked = _selected.contains(record.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              onChanged: (value) => setState(() {
                if (value == true) {
                  _selected.add(record.id);
                } else {
                  _selected.remove(record.id);
                }
              }),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 76,
                height: 76,
                child: record.closePhoto == null
                    ? const ColoredBox(
                        color: Color(0xffedf1f2),
                        child: Icon(Icons.image_not_supported_outlined),
                      )
                    : Image.network(
                        record.closePhoto!.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.tag,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (record.isDemo) ...[
                        _demoBadge(),
                        const SizedBox(width: 6),
                      ],
                      _statusBadge(record.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.sectionCode} - ${record.sectionName}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${record.zone} | ${record.equipmentName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${record.trapTypeName} | ${_diagnosisLabel(record.diagnosisStatus)}',
                    style: const TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  Text(
                    DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(_guayaquil(record.updatedAt)),
                    style: const TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => widget.onEdit(record),
                      icon: Icon(
                        record.isDraft
                            ? Icons.edit_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      label: Text(record.isDraft ? 'Continuar' : 'Abrir'),
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

  Widget _statusBadge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: status == 'complete'
          ? const Color(0xffdff3e7)
          : const Color(0xffffeed1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      status == 'complete'
          ? 'Completo'
          : status == 'draft'
          ? 'Borrador'
          : 'Pendiente',
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );

  Widget _demoBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xffffe1e4),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'DEMO',
      style: TextStyle(
        color: brandRed,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
  String _diagnosisLabel(String value) =>
      const {
        'pending': 'Pendiente',
        'operational': 'Operativa',
        'requires_attention': 'Requiere atencion',
        'out_of_service': 'Fuera de servicio',
      }[value] ??
      value;

  DateTime _guayaquil(DateTime value) =>
      value.toUtc().subtract(const Duration(hours: 5));

  Future<void> _load() async {
    try {
      final records = await widget.store.loadRecords();
      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _choose(
    String title,
    List<String> values,
    List<String> labels,
    ValueChanged<String> apply,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMediumBold,
              ),
            ),
            for (var i = 0; i < values.length; i++)
              ListTile(
                title: Text(labels[i]),
                onTap: () => Navigator.pop(context, values[i]),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        apply(selected);
        _visible = 15;
      });
    }
  }

  Future<void> _pickDates() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dates,
    );
    if (result != null) {
      setState(() {
        _dates = result;
        _visible = 15;
      });
    }
  }

  Future<void> _runExport(String type) async {
    final chosen = _selected.isEmpty
        ? _filtered
        : _filtered.where((r) => _selected.contains(r.id)).toList();
    setState(() => _exporting = true);
    try {
      if (type == 'xlsx') await _export.shareExcel(chosen);
      if (type == 'photos') await _export.sharePhotoZip(chosen);
      if (type == 'combined') await _export.shareCombined(chosen);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible exportar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
