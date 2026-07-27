part of '../main.dart';

class PressureEntryTab extends StatefulWidget {
  const PressureEntryTab({
    required this.store,
    required this.operatorSession,
    super.key,
  });

  final PressureReadingStore store;
  final OperatorSession operatorSession;

  @override
  State<PressureEntryTab> createState() => _PressureEntryTabState();
}

class _PressureEntryTabState extends State<PressureEntryTab> {
  late final Map<String, TextEditingController> _controllers = {
    for (final point in steamPressurePoints) point.id: TextEditingController(),
  };
  String _message = '';
  MessageType _messageType = MessageType.info;
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroup(
          title: 'Presiones distribuidor Cleaver',
          points: cleaverDistributorPressurePoints,
        ),
        const SizedBox(height: 14),
        _buildGroup(
          title: 'Presiones distribuidor 900',
          points: distral900DistributorPressurePoints,
        ),
        const SizedBox(height: 16),
        EeActionButton(
          icon: Icons.fact_check_outlined,
          label: _isSubmitting ? 'Guardando presiones...' : 'Revisar presiones',
          onPressed: _isSubmitting ? null : _reviewAndSave,
        ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 12),
          MessageBox(type: _messageType, message: _message),
        ],
      ],
    );
  }

  Widget _buildGroup({
    required String title,
    required List<PressurePointDefinition> points,
  }) {
    return InfoPanel(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMediumBold),
        const SizedBox(height: 14),
        for (var index = 0; index < points.length; index++) ...[
          _buildPressureField(points[index]),
          if (index < points.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildPressureField(PressurePointDefinition point) {
    return TextField(
      controller: _controllers[point.id],
      enabled: !_isSubmitting,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(labelText: point.label, suffixText: 'PSI'),
    );
  }

  Future<void> _reviewAndSave() async {
    FocusScope.of(context).unfocus();
    AuthenticatedOperator? operator;
    try {
      operator = await widget.operatorSession.currentOperator();
    } catch (_) {
      _setMessage(
        MessageType.error,
        'No fue posible verificar la sesion del usuario.',
      );
      return;
    }
    if (!mounted) return;
    if (operator == null) {
      _setMessage(
        MessageType.warning,
        'Inicia sesion como usuario antes de guardar presiones.',
      );
      return;
    }

    final values = <String, double>{};
    for (final point in steamPressurePoints) {
      final value = _parsePressure(point);
      if (value == null) {
        return;
      }
      values[point.id] = value;
    }

    final now = DateTime.now().toUtc();
    final reading = SteamPressureReading(
      id: 'pressure_${now.microsecondsSinceEpoch}',
      recordedAt: now,
      cleaverDistributorPsi: {
        for (final point in cleaverDistributorPressurePoints)
          point.id: values[point.id]!,
      },
      distral900DistributorPsi: {
        for (final point in distral900DistributorPressurePoints)
          point.id: values[point.id]!,
      },
    );

    final confirmed = await _confirmReading(reading, operator);
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _messageType = MessageType.info;
      _message = 'Guardando y esperando confirmacion de la nube...';
    });
    try {
      await widget.store.saveReading(reading);
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.clear();
      }
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.success;
        _message = 'Presiones guardadas correctamente.';
      });
    } on PressureReadingStoreException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.warning;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _messageType = MessageType.error;
        _message = 'No fue posible guardar las presiones.';
      });
    }
  }

  double? _parsePressure(PressurePointDefinition point) {
    final raw = _controllers[point.id]!.text.replaceAll(',', '.').trim();
    final value = double.tryParse(raw);
    if (value == null || value < 0) {
      _setMessage(
        MessageType.error,
        '${point.label} debe ser un numero mayor o igual a cero.',
      );
      return null;
    }
    return value;
  }

  Future<bool?> _confirmReading(
    SteamPressureReading reading,
    AuthenticatedOperator operator,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar presiones'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryGroup(
                  'Distribuidor Cleaver',
                  cleaverDistributorPressurePoints,
                  reading.cleaverDistributorPsi,
                ),
                const SizedBox(height: 14),
                _buildSummaryGroup(
                  'Distribuidor 900',
                  distral900DistributorPressurePoints,
                  reading.distral900DistributorPsi,
                ),
                const SizedBox(height: 14),
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
              label: const Text('Confirmar y guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryGroup(
    String title,
    List<PressurePointDefinition> points,
    Map<String, double> values,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMediumBold),
        const SizedBox(height: 6),
        for (final point in points)
          Text('${point.label}: ${Formats.two(values[point.id]!)} PSI'),
      ],
    );
  }

  void _setMessage(MessageType type, String message) {
    setState(() {
      _messageType = type;
      _message = message;
    });
  }
}
