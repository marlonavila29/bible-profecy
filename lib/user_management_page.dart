import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'app_error.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<AppUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _users = await AuthService().getAllUsers();
    if (mounted) setState(() => _isLoading = false);
  }

  void _changeRole(AppUser user) {
    final currentRole = user.role;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Alterar Papel de ${user.displayName}',
                  style: GoogleFonts.cinzel(
                      fontSize: 16,
                      color: const Color(0xFFFCD34D),
                      fontWeight: FontWeight.bold)),
            ),
            _roleOption(ctx, user, 'user', 'Usuário Normal', Icons.person,
                currentRole == 'user'),
            _roleOption(ctx, user, 'admin', 'Administrador',
                Icons.admin_panel_settings, currentRole == 'admin'),
            if (user.email.toLowerCase() != AuthService.masterEmail)
              _roleOption(ctx, user, 'master', 'Admin Master', Icons.shield,
                  currentRole == 'master'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _roleOption(BuildContext ctx, AppUser user, String role, String label,
      IconData icon, bool isSelected) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFFF59E0B) : Colors.white54),
      title: Text(label,
          style: TextStyle(
              color: isSelected ? const Color(0xFFF59E0B) : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFFF59E0B))
          : null,
      onTap: isSelected
          ? null
          : () async {
              Navigator.pop(ctx);
              await AuthService().updateUserRole(user.uid, role);
              await _loadUsers();
              if (mounted) {
                AppFeedback.showSuccess(
                  context,
                  '${user.displayName} agora é ${_roleLabel(role)}! ✅',
                );
              }
            },
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'master':
        return 'Admin Master';
      case 'admin':
        return 'Administrador';
      default:
        return 'Usuário Normal';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'master':
        return Colors.redAccent;
      case 'admin':
        return const Color(0xFFF59E0B);
      default:
        return Colors.blueGrey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'master':
        return Icons.shield;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gerenciar Usuários', style: GoogleFonts.cinzel()),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : _users.isEmpty
              ? Center(
                  child: Text('Nenhum usuário encontrado.',
                      style: GoogleFonts.inter(color: Colors.white54)))
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  color: const Color(0xFFF59E0B),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (ctx, i) {
                      final user = _users[i];
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _roleColor(user.role).withOpacity(0.2),
                            child: Icon(_roleIcon(user.role),
                                color: _roleColor(user.role)),
                          ),
                          title: Text(user.displayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 13)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      _roleColor(user.role).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _roleColor(user.role)
                                          .withOpacity(0.4)),
                                ),
                                child: Text(
                                  _roleLabel(user.role),
                                  style: TextStyle(
                                      color: _roleColor(user.role),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          trailing: user.email.toLowerCase() ==
                                  AuthService.masterEmail
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.white54),
                                  onPressed: () => _changeRole(user),
                                ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
