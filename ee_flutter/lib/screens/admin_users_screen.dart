part of '../main.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({required this.adminUid, super.key});

  final String adminUid;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  final _service = FirebaseOperatorAdminService();
  List<OperatorAdminUser> _users = const [];
  String _search = '';
  String _message = '';
  MessageType _messageType = MessageType.info;
  var _isLoading = true;
  var _busyUid = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _service.listUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _message = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messageType = MessageType.error;
        _message = 'No fue posible consultar los usuarios. Revisa tu conexión.';
      });
    }
  }

  List<OperatorAdminUser> get _filteredUsers {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((user) {
      final haystack = [
        user.displayName,
        user.nationalId,
        user.role,
        user.maintenanceZoneNumbers.join(' '),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _confirmDeactivate(OperatorAdminUser user) async {
    if (user.uid == widget.adminUid || !user.active) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text(
          'Se bloqueará el acceso de ${user.displayName.isEmpty ? 'este usuario' : user.displayName}. '
          'Sus registros históricos se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyUid = user.uid);
    try {
      await _service.deactivateUser(uid: user.uid, adminUid: widget.adminUid);
      if (!mounted) return;
      setState(() {
        _busyUid = '';
        _users = _users
            .map(
              (item) => item.uid == user.uid
                  ? OperatorAdminUser(
                      uid: item.uid,
                      displayName: item.displayName,
                      nationalId: item.nationalId,
                      role: item.role,
                      active: false,
                      maintenanceZoneNumbers: item.maintenanceZoneNumbers,
                    )
                  : item,
            )
            .toList();
        _messageType = MessageType.success;
        _message = 'Usuario desactivado. Sus reportes se conservaron.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busyUid = '';
        _messageType = MessageType.error;
        _message = 'No fue posible desactivar el usuario.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    return AppShell(
      bottomNavigationBar: const HomeNavigationBar(),
      children: [
        Row(
          children: [
            Expanded(
              child: const EeHeader(
                title: 'Usuarios',
                subtitle: 'Consulta y administra los accesos registrados.',
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _isLoading ? null : _loadUsers,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
            labelText: 'Buscar usuario',
            hintText: 'Nombre, cédula, rol o zona',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (_message.isNotEmpty)
          MessageBox(type: _messageType, message: _message),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (users.isEmpty)
          const Card(
            child: ListTile(title: Text('No hay usuarios que coincidan.')),
          )
        else
          ...users.map(_userCard),
      ],
    );
  }

  Widget _userCard(OperatorAdminUser user) {
    final isBusy = _busyUid == user.uid;
    final zones = user.maintenanceZoneNumbers.isEmpty
        ? 'Sin zonas asignadas'
        : 'Zonas: ${user.maintenanceZoneNumbers.join(', ')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.active
              ? brandRed.withValues(alpha: .12)
              : Colors.grey.shade200,
          child: Icon(
            user.active ? Icons.person_outline : Icons.person_off_outlined,
            color: user.active ? brandRed : mutedColor,
          ),
        ),
        title: Text(user.displayName.isEmpty ? 'Sin nombre' : user.displayName),
        subtitle: Text('${user.nationalId}\n${user.role} · $zones'),
        isThreeLine: true,
        trailing: user.active
            ? IconButton(
                tooltip: user.uid == widget.adminUid
                    ? 'Tu cuenta no se puede desactivar'
                    : 'Desactivar usuario',
                onPressed: user.uid == widget.adminUid || isBusy
                    ? null
                    : () => _confirmDeactivate(user),
                icon: isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.block_outlined),
              )
            : const Chip(label: Text('Inactivo')),
      ),
    );
  }
}
