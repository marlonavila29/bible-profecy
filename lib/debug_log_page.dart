import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';

class DebugLogPage extends StatelessWidget {
  const DebugLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = AuthService().errorLog.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log de Autenticação'),
        backgroundColor: const Color(0x990F172A),
        elevation: 0,
      ),
      body: logs.isEmpty
          ? const Center(child: Text('Nenhum log registrado.', style: TextStyle(color: Colors.white70)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (_, i) => Text(
                logs[i],
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}
