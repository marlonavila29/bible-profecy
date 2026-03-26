import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central error handler for the entire app.
/// Translates Firebase/Dart exceptions into friendly Portuguese messages.
class AppErrorHandler {
  /// Translate any exception to a user-friendly message.
  static String translate(dynamic error) {
    if (error is FirebaseAuthException) {
      return _translateFirebaseAuth(error);
    }
    final msg = error.toString().toLowerCase();

    // Network
    if (msg.contains('network') || msg.contains('socketexception') || msg.contains('failed host lookup')) {
      return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
    }
    // Timeout
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'A operação demorou muito. Verifique sua conexão e tente novamente.';
    }
    // Firebase generic
    if (msg.contains('firebase') || msg.contains('firestore')) {
      return 'Erro de conexão com o servidor. Tente novamente em instantes.';
    }
    // Permission
    if (msg.contains('permission') || msg.contains('unauthorized') || msg.contains('permission-denied')) {
      return 'Você não tem permissão para realizar esta ação.';
    }
    // Not found
    if (msg.contains('not-found') || msg.contains('not found')) {
      return 'Recurso não encontrado. Por favor, atualize e tente novamente.';
    }
    // JSON/parse
    if (msg.contains('formatexception') || msg.contains('json') || msg.contains('parse')) {
      return 'Erro ao processar os dados. Por favor, contate o suporte.';
    }

    return 'Algo deu errado. Por favor, tente novamente.';
  }

  static String _translateFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      // Registration
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres, incluindo letras e números.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado. Tente fazer login ou use outro e-mail.';
      case 'invalid-email':
        return 'E-mail inválido. Verifique o formato (ex: nome@email.com).';
      // Login
      case 'user-not-found':
        return 'Nenhuma conta encontrada com este e-mail. Verifique ou crie uma nova conta.';
      case 'wrong-password':
        return 'Senha incorreta. Tente novamente ou use "Esqueci a senha".';
      case 'invalid-credential':
        return 'E-mail ou senha incorretos. Verifique os dados e tente novamente.';
      case 'user-disabled':
        return 'Esta conta foi desativada. Entre em contato com o suporte.';
      case 'too-many-requests':
        return 'Muitas tentativas seguidas. Aguarde alguns minutos e tente novamente.';
      // Google Sign-In
      case 'account-exists-with-different-credential':
        return 'Já existe uma conta com este e-mail usando outro método de login.';
      case 'popup-blocked':
        return 'O popup de login foi bloqueado pelo navegador. Permita popups para este site.';
      case 'popup-closed-by-user':
        return 'A janela de login foi fechada antes de concluir. Tente novamente.';
      case 'cancelled-popup-request':
        return 'Uma solicitação de login já está em andamento.';
      // Configuration
      case 'operation-not-allowed':
        return 'Este método de login não está habilitado. Entre em contato com o suporte.';
      case 'configuration-not-found':
        return 'Configuração do serviço de login não encontrada. Contate o suporte.';
      // Network
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
      default:
        return 'Erro de autenticação: ${e.message ?? e.code}';
    }
  }
}

/// A beautiful, non-intrusive error/success notification widget.
class AppFeedback {
  /// Show a styled error snackbar.
  static void showError(BuildContext context, String message, {Duration duration = const Duration(seconds: 4)}) {
    _show(context, message: message, isError: true, duration: duration);
  }

  /// Show a styled success snackbar.
  static void showSuccess(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    _show(context, message: message, isError: false, duration: duration);
  }

  /// Show a styled info snackbar.
  static void showInfo(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    _show(context, message: message, isError: false, isInfo: true, duration: duration);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required bool isError,
    bool isInfo = false,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isError
                ? const Color(0xFF1A0A0A)
                : isInfo
                    ? const Color(0xFF0A1020)
                    : const Color(0xFF0A1A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isError
                  ? const Color(0xFFEF4444).withOpacity(0.4)
                  : isInfo
                      ? const Color(0xFF60A5FA).withOpacity(0.4)
                      : const Color(0xFF22C55E).withOpacity(0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isError ? const Color(0xFFEF4444) : isInfo ? const Color(0xFF60A5FA) : const Color(0xFF22C55E))
                    .withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isError
                          ? const Color(0xFFEF4444)
                          : isInfo
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF22C55E))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : isInfo
                          ? Icons.info_outline_rounded
                          : Icons.check_circle_outline_rounded,
                  color: isError
                      ? const Color(0xFFEF4444)
                      : isInfo
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF22C55E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: isError
                        ? const Color(0xFFFCA5A5)
                        : isInfo
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF86EFAC),
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
