part of '../main.dart';

class LeakReportScreen extends StatefulWidget {
  const LeakReportScreen({
    required this.store,
    required this.cloudinaryService,
    required this.operatorSession,
    this.destinationCatalog,
    super.key,
  });

  final MaintenanceReportStore store;
  final CloudinaryService cloudinaryService;
  final OperatorSession operatorSession;
  final DestinationCatalog? destinationCatalog;

  @override
  State<LeakReportScreen> createState() => _LeakReportScreenState();
}

class _LeakReportScreenState extends State<LeakReportScreen> {
  final _picker = ImagePicker();
  final _referenceController = TextEditingController();
  Uint8List? _photoBytes;
  CloudinaryUpload? _uploadedEvidence;
  DestinationCatalog? _catalog;
  String _catalogError = '';
  String _sectionCode = '';
  String _processCode = '';
  String _equipmentCode = '';
  String _systemCode = '';
  String _leakTypeId = '';
  String? _reportId;
  bool _reviewReady = false;
  bool _isSubmitting = false;
  String _message = '';
  MessageType _messageType = MessageType.info;

  @override
  void initState() {
    super.initState();
    _catalog = widget.destinationCatalog;
    if (_catalog == null) _loadCatalog();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leakType = leakTypeById(_leakTypeId);
    final destination = _currentDestination;
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        const EeHeader(
          title: 'Reportar fugas',
          subtitle: 'Registra la evidencia para gestionar su correccion.',
        ),
        const SizedBox(height: 14),
        EeActionButton(
          icon: Icons.photo_camera_outlined,
          label: _photoBytes == null
              ? 'Capturar evidencia'
              : 'Cambiar evidencia',
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
          'Seleccione el destino hasta donde lo conozca',
          style: Theme.of(context).textTheme.labelBold,
        ),
        const SizedBox(height: 8),
        if (_catalog == null && _catalogError.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_catalogError.isNotEmpty) ...[
          MessageBox(type: MessageType.error, message: _catalogError),
          const SizedBox(height: 8),
          EeActionButton(
            icon: Icons.refresh,
            label: 'Reintentar catalogo',
            onPressed: _loadCatalog,
          ),
        ] else
          _buildDestinationSelectors(_catalog!),
        const SizedBox(height: 14),
        TextField(
          controller: _referenceController,
          enabled: !_isSubmitting,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Referencia adicional (opcional)',
            hintText: 'Ej. Linea de tracing junto al tanque 4',
          ),
          onChanged: (_) => setState(_invalidateReview),
        ),
        const SizedBox(height: 14),
        Text(
          'Indique el tipo de fuga',
          style: Theme.of(context).textTheme.labelBold,
        ),
        const SizedBox(height: 8),
        EmbeddedWheelPicker<String>(
          value: _leakTypeId,
          options: [
            const PickerOption('', 'Selecciona el tipo'),
            ...LeakType.values.map(
              (type) => PickerOption(type.id, type.displayName),
            ),
          ],
          onSelected: (value) => setState(() {
            _leakTypeId = value;
            _invalidateReview();
          }),
        ),
        const SizedBox(height: 16),
        EeActionButton(
          icon: Icons.fact_check_outlined,
          label: 'Revisar reporte',
          onPressed: _isSubmitting ? null : _review,
        ),
        if (_reviewReady && leakType != null && destination != null) ...[
          const SizedBox(height: 14),
          InfoPanel(
            children: [
              Text(
                'Resumen del reporte',
                style: Theme.of(context).textTheme.titleMediumBold,
              ),
              const SizedBox(height: 12),
              LabelValue(
                label: 'Destino',
                value: _destinationSummary(destination),
              ),
              const SizedBox(height: 10),
              TwoColumnInfo(
                leftLabel: 'Tipo de fuga',
                leftValue: leakType.displayName,
                rightLabel: 'Identificacion',
                rightValue: 'Se asigna al guardar',
              ),
              if (_referenceController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                LabelValue(
                  label: 'Referencia adicional',
                  value: _referenceController.text.trim(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          EeActionButton(
            icon: _uploadedEvidence == null
                ? Icons.cloud_upload_outlined
                : Icons.sync_outlined,
            label: _isSubmitting
                ? 'Guardando reporte...'
                : _uploadedEvidence == null
                ? 'Confirmar y subir'
                : 'Reintentar guardado',
            onPressed: _isSubmitting ? null : _save,
          ),
        ],
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
      ],
    );
  }

  Widget _buildDestinationSelectors(DestinationCatalog catalog) {
    final section = catalog.sectionByCode(_sectionCode);
    final process = section?.processByCode(_processCode);
    final equipment = process?.equipmentByCode(_equipmentCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _destinationPicker(
          label: 'Macroarea',
          value: _sectionCode,
          emptyLabel: 'Sin macroarea',
          options: catalog.sections
              .map((item) => PickerOption(item.code, item.name))
              .toList(growable: false),
          onSelected: (value) => setState(() {
            _sectionCode = value;
            _processCode = '';
            _equipmentCode = '';
            _systemCode = '';
            _invalidateReview();
          }),
        ),
        if (section != null) ...[
          const SizedBox(height: 12),
          _destinationPicker(
            label: 'Proceso o destino general',
            value: _processCode,
            emptyLabel: 'Finalizar en ${section.name}',
            options: section.processes
                .map((item) => PickerOption(item.code, item.name))
                .toList(growable: false),
            onSelected: (value) => setState(() {
              _processCode = value;
              _equipmentCode = '';
              _systemCode = '';
              _invalidateReview();
            }),
          ),
        ],
        if (process != null) ...[
          const SizedBox(height: 12),
          _destinationPicker(
            label: 'Equipo',
            value: _equipmentCode,
            emptyLabel: 'Finalizar en ${process.name}',
            options: process.equipment
                .map(
                  (item) =>
                      PickerOption(item.code, '${item.code} - ${item.name}'),
                )
                .toList(growable: false),
            onSelected: (value) => setState(() {
              _equipmentCode = value;
              _systemCode = '';
              _invalidateReview();
            }),
          ),
        ],
        if (equipment != null && equipment.systems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _destinationPicker(
            label: 'Sistema o subsistema',
            value: _systemCode,
            emptyLabel: 'Finalizar en ${equipment.name}',
            options: equipment.systems
                .map(
                  (item) =>
                      PickerOption(item.code, '${item.code} - ${item.name}'),
                )
                .toList(growable: false),
            onSelected: (value) => setState(() {
              _systemCode = value;
              _invalidateReview();
            }),
          ),
        ],
      ],
    );
  }

  Widget _destinationPicker({
    required String label,
    required String value,
    required String emptyLabel,
    required List<PickerOption<String>> options,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelBold),
        const SizedBox(height: 6),
        EmbeddedWheelPicker<String>(
          value: value,
          height: 112,
          options: [PickerOption('', emptyLabel), ...options],
          onSelected: onSelected,
        ),
      ],
    );
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _catalogError = '';
      _catalog = null;
    });
    try {
      final catalog = await const DestinationCatalogLoader().load();
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogError =
            'No fue posible cargar el catalogo de destinos. Reintenta.';
      });
    }
  }

  DestinationSelection? get _currentDestination {
    final catalog = _catalog;
    if (catalog == null) return null;
    try {
      return catalog.selection(
        sectionCode: _sectionCode,
        processCode: _processCode,
        equipmentCode: _equipmentCode,
        systemCode: _systemCode,
      );
    } on FormatException {
      return null;
    }
  }

  String _destinationSummary(DestinationSelection destination) {
    final labels = [
      destination.sectionName,
      destination.processName,
      destination.equipmentName,
      destination.systemName,
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return labels.isEmpty ? 'Sin especificar' : labels.join(' > ');
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
      _invalidateReview();
    });
  }

  void _review() {
    if (_photoBytes == null) {
      _setMessage(MessageType.error, 'Captura una foto de la fuga.');
      return;
    }
    if (_catalog == null || _currentDestination == null) {
      _setMessage(
        MessageType.error,
        'Espera a que el catalogo de destinos este disponible.',
      );
      return;
    }
    if (leakTypeById(_leakTypeId) == null) {
      _setMessage(MessageType.error, 'Selecciona el tipo de fuga.');
      return;
    }
    setState(() {
      _reviewReady = true;
      _reportId = _createReportId();
      _uploadedEvidence = null;
      _messageType = MessageType.success;
      _message = 'Revisa el resumen antes de subir el reporte.';
    });
  }

  Future<void> _save() async {
    final photoBytes = _photoBytes;
    final destination = _currentDestination;
    final leakType = leakTypeById(_leakTypeId);
    final reportId = _reportId;
    if (!_reviewReady ||
        photoBytes == null ||
        destination == null ||
        leakType == null ||
        reportId == null ||
        _isSubmitting) {
      _setMessage(MessageType.error, 'Revisa el reporte antes de guardarlo.');
      return;
    }

    final operator = await widget.operatorSession.currentOperator();
    if (!mounted) return;
    if (operator == null) {
      _setMessage(
        MessageType.warning,
        'Inicia sesion como usuario antes de guardar en la nube.',
      );
      return;
    }

    final confirmed = await _confirmSave(operator, destination, leakType);
    if (!mounted || confirmed != true) return;
    setState(() {
      _isSubmitting = true;
      _messageType = MessageType.info;
      _message = _uploadedEvidence == null
          ? 'Subiendo evidencia...'
          : 'Confirmando el reporte en Firebase...';
    });

    try {
      final upload =
          _uploadedEvidence ??
          await widget.cloudinaryService.uploadEvidence(
            bytes: photoBytes,
            reportId: 'leak-$reportId',
          );
      if (!mounted) return;
      setState(() {
        _uploadedEvidence = upload;
        _message = 'Evidencia subida. Confirmando el reporte en Firebase...';
      });
      final tag = await widget.store.saveLeakReport(
        LeakReport(
          id: reportId,
          createdAt: DateTime.now(),
          destination: destination,
          leakType: leakType,
          locationReference: _referenceController.text.trim(),
          photoUrl: upload.secureUrl,
          photoPublicId: upload.publicId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _resetForm();
        _messageType = MessageType.success;
        _message = 'Fuga $tag guardada correctamente.';
      });
    } on MaintenanceReportException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
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

  Future<bool?> _confirmSave(
    AuthenticatedOperator operator,
    DestinationSelection destination,
    LeakType leakType,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar reporte'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_photoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _photoBytes!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              Text('Destino: ${_destinationSummary(destination)}'),
              Text('Tipo: ${leakType.displayName}'),
              const Text('Identificacion: se asigna automaticamente'),
              if (_referenceController.text.trim().isNotEmpty)
                Text('Referencia: ${_referenceController.text.trim()}'),
              Text('Usuario: ${operator.displayName}'),
              Text(
                'Fecha y hora: '
                '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              ),
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
            label: const Text('Confirmar y subir'),
          ),
        ],
      ),
    );
  }

  void _invalidateReview() {
    _reviewReady = false;
    _reportId = null;
    _uploadedEvidence = null;
    _message = '';
  }

  void _resetForm() {
    _isSubmitting = false;
    _photoBytes = null;
    _uploadedEvidence = null;
    _sectionCode = '';
    _processCode = '';
    _equipmentCode = '';
    _systemCode = '';
    _leakTypeId = '';
    _reportId = null;
    _reviewReady = false;
    _referenceController.clear();
  }

  void _setMessage(MessageType type, String message) {
    setState(() {
      _messageType = type;
      _message = message;
    });
  }

  String _createReportId() {
    final random = math.Random().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().millisecondsSinceEpoch}-$random';
  }
}
