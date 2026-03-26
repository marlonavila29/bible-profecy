import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'app_error.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onGuestMode;
  const LoginPage({super.key, this.onGuestMode});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePass = true;

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _emailCtrl.clear();
      _passCtrl.clear();
      _nameCtrl.clear();
    });
  }

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      AppFeedback.showError(context, 'Preencha o e-mail e a senha para continuar.');
      return;
    }
    if (!_isLogin && name.isEmpty) {
      AppFeedback.showError(context, 'Digite seu nome completo para criar a conta.');
      return;
    }
    if (!_isLogin && pass.length < 6) {
      AppFeedback.showError(context, 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }

    setState(() => _isLoading = true);

    String? error;
    if (_isLogin) {
      error = await AuthService().loginWithEmail(email, pass);
    } else {
      error = await AuthService().registerWithEmail(email, pass, name);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      AppFeedback.showError(context, error);
    } else if (!_isLogin) {
      AppFeedback.showSuccess(context, 'Conta criada com sucesso! Bem-vindo(a)! 🎉');
    }
  }

  Future<void> _loginGoogle() async {
    setState(() => _isLoading = true);
    final error = await AuthService().loginWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      AppFeedback.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [Color(0xFF1E293B), Color(0xFF0B0F19)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Title
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2),
                      ],
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        size: 40, color: Color(0xFF0B0F19)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'A Revelação',
                    style: GoogleFonts.cinzel(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFCD34D)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bíblia de Estudo',
                    style:
                        GoogleFonts.inter(fontSize: 16, color: Colors.white54),
                  ),
                  const SizedBox(height: 48),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isLogin ? 'Entrar' : 'Criar Conta',
                          style: GoogleFonts.cinzel(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Name field (register only)
                        if (!_isLogin) ...[
                          TextField(
                            controller: _nameCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                                'Nome Completo', Icons.person_outline),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email field
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              _inputDecoration('E-mail', Icons.email_outlined),
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscurePass,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              _inputDecoration('Senha', Icons.lock_outline)
                                  .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white30),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black))
                                : Text(
                                    _isLogin ? 'Entrar' : 'Cadastrar',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Toggle login/register
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(
                            _isLogin
                                ? 'Não tem conta? Cadastre-se'
                                : 'Já tem conta? Faça login',
                            style: const TextStyle(color: Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                          child: Container(height: 1, color: Colors.white10)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('ou',
                            style: GoogleFonts.inter(color: Colors.white30)),
                      ),
                      Expanded(
                          child: Container(height: 1, color: Colors.white10)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Google Sign-In Button
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loginGoogle,
                      icon: const Text('G',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      label: const Text('Continuar com Google',
                          style: TextStyle(color: Colors.white, fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Apple Sign-In Button (future)
                  // SizedBox(
                  //   height: 52,
                  //   width: double.infinity,
                  //   child: OutlinedButton.icon(
                  //     onPressed: _isLoading ? null : _loginApple,
                  //     icon: const Icon(Icons.apple, color: Colors.white),
                  //     label: const Text('Continuar com Apple', style: TextStyle(color: Colors.white, fontSize: 15)),
                  //     style: OutlinedButton.styleFrom(
                  //       side: const BorderSide(color: Colors.white24),
                  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  //     ),
                  //   ),
                  // ),

                  // ── Guest Mode ────────────────────────────────────
                  if (widget.onGuestMode != null) ...[
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(child: Container(height: 1, color: Colors.white10)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('ou', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ),
                      Expanded(child: Container(height: 1, color: Colors.white10)),
                    ]),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: widget.onGuestMode,
                      icon: const Icon(Icons.person_outline, color: Colors.white38, size: 18),
                      label: const Text(
                        'Continuar sem criar conta',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'Suas anotações ficam salvas localmente no dispositivo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white30),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF59E0B)),
      ),
    );
  }
}
