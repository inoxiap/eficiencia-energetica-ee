part of '../main.dart';

class LeakReportScreen extends StatefulWidget {
  const LeakReportScreen({
    required this.store,
    required this.cloudinaryService,
    required this.operatorSession,
    super.key,
  });

  final MaintenanceReportStore store;
  final CloudinaryService cloudinaryService;
  final OperatorSession operatorSession;

  @override
  State<LeakReportScreen> createState() => _LeakReportScreenState();
}

class _LeakReportScreenState extends State<LeakReportScreen> {
  final _picker = ImagePicker();
  final _equipmentController = TextEditingController();
  final _tagController = TextEditingController();
  Uint8List? _photoBytes;
  CloudinaryUpload? _uploadedEvidence;
  String _sectionId = '';
  String _leakTypeId = '';
  String? _reportId;
  bool _reviewReady = false;
  bool _isSubmitting = false;
  String _message = '';
  MessageType _messageType = MessageType.info;

  @override
  void dispose() {
    _equipmentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leakType = leakTypeById(_leakTypeId);
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
          'Seleccione la seccion',
          style: Theme.of(context).textTheme.labelBold,
        ),
        const SizedBox(height: 8),
        EmbeddedWheelPicker<String>(
          value: _sectionId,
          options: [
            const PickerOption('', 'Selecciona una seccion'),
            ...plantSections.map(
              (section) => PickerOption(section.id, section.displayName),
            ),
          ],
          onSelected: (value) => setState(() {
            _sectionId = value;
            _invalidateReview();
          }),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _equipmentController,
          enabled: !_isSubmitting,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Equipo o ubicacion (opcional)',
            hintText: 'Ej. Linea de tracing del tanque 4',
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
        const SizedBox(height: 14),
        TextField(
          controller: _tagController,
          enabled: !_isSubmitting,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 12,
          decoration: const InputDecoration(
            labelText: 'Numero de identificacion de la fuga',
            hintText: 'Numero colocado en la latita',
            counterText: '',
          ),
          onChanged: (_) => setState(_invalidateReview),
        ),
        const SizedBox(height: 16),
        EeActionButton(
          icon: Icons.fact_check_outlined,
          label: 'Revisar reporte',
          onPressed: _isSubmitting ? null : _review,
        ),
        if (_reviewReady && leakType != null) ...[
          const SizedBox(height: 14),
          InfoPanel(
            children: [
              Text(
                'Resumen del reporte',
                style: Theme.of(context).textTheme.titleMediumBold,
              ),
              const SizedBox(height: 12),
              LabelValue(
                label: 'Seccion',
                value: plantSectionById(_sectionId)?.displayName ?? '',
              ),
              const SizedBox(height: 10),
              TwoColumnInfo(
                leftLabel: 'Tipo de fuga',
                leftValue: leakType.displayName,
                rightLabel: 'Identificacion',
                rightValue: _tagController.text.trim(),
              ),
              if (_equipmentController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                LabelValue(
                  label: 'Equipo o ubicacion',
                  value: _equipmentController.text.trim(),
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
    if (plantSectionById(_sectionId) == null) {
      _setMessage(MessageType.error, 'Selecciona la seccion.');
      return;
    }
    if (leakTypeById(_leakTypeId) == null) {
      _setMessage(MessageType.error, 'Selecciona el tipo de fuga.');
      return;
    }
    if (_tagController.text.trim().isEmpty) {
      _setMessage(
        MessageType.error,
        'Ingresa el numero de identificacion colocado en la fuga.',
      );
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
    final section = plantSectionById(_sectionId);
    final leakType = leakTypeById(_leakTypeId);
    final reportId = _reportId;
    if (!_reviewReady ||
        photoBytes == null ||
        section == null ||
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

    final confirmed = await _confirmSave(operator, section, leakType);
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
      await widget.store.saveLeakReport(
        LeakReport(
          id: reportId,
          createdAt: DateTime.now(),
          sectionId: section.id,
          sectionNameSnapshot: section.displayName,
          equipmentName: _equipmentController.text.trim(),
          equipmentNameNormalized: normalizeEquipmentName(
            _equipmentController.text,
          ),
          leakType: leakType,
          tagNumber: _tagController.text.trim(),
          photoUrl: upload.secureUrl,
          photoPublicId: upload.publicId,
        ),
      );
      if (!mounted) return;
      final tag = _tagController.text.trim();
      setState(() {
        _resetForm();
        _messageType = MessageType.success;
        _message = 'Fuga N. $tag guardada correctamente.';
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
    PlantSection section,
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
              Text('Seccion: ${section.displayName}'),
              Text('Tipo: ${leakType.displayName}'),
              Text('Identificacion: ${_tagController.text.trim()}'),
              if (_equipmentController.text.trim().isNotEmpty)
                Text('Ubicacion: ${_equipmentController.text.trim()}'),
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
    _sectionId = '';
    _leakTypeId = '';
    _reportId = null;
    _reviewReady = false;
    _equipmentController.clear();
    _tagController.clear();
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
