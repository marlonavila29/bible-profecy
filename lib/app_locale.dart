import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported locales for the app.
class AppLocale extends ChangeNotifier {
  static final AppLocale _instance = AppLocale._internal();
  factory AppLocale() => _instance;
  AppLocale._internal();

  // ── Supported Languages ─────────────────────────────────────────────────────
  static const List<LocaleOption> supportedLocales = [
    LocaleOption(code: 'pt', label: 'Português', flag: '🇧🇷', bibleAsset: 'assets/bible-data.json'),
    LocaleOption(code: 'en', label: 'English', flag: '🇺🇸', bibleAsset: 'assets/bible-data-en.json'),
    LocaleOption(code: 'es', label: 'Español', flag: '🇪🇸', bibleAsset: 'assets/bible-data-es.json'),
  ];

  String _currentCode = 'pt';
  String get currentCode => _currentCode;

  LocaleOption get current =>
      supportedLocales.firstWhere((l) => l.code == _currentCode,
          orElse: () => supportedLocales.first);

  /// Initialize from persisted preferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentCode = prefs.getString('appLocale') ?? 'pt';
    notifyListeners();
  }

  /// Change the locale. Returns true if it actually changed.
  Future<bool> setLocale(String code) async {
    if (code == _currentCode) return false;
    if (!supportedLocales.any((l) => l.code == code)) return false;

    _currentCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLocale', code);
    notifyListeners();
    return true;
  }

  // ── Firestore Collection Helpers ─────────────────────────────────────────────
  // Language-specific collections get a prefix:
  //   pt_dictionary, en_dictionary, es_dictionary, etc.

  String dictionaryCollection() => '${_currentCode}_dictionary';
  String chapterAudioCollection() => '${_currentCode}_chapterAudio';
  String podcastsCollection() => '${_currentCode}_podcasts';

  // Verse options are SPLIT:
  //   - Comments are language-specific → {lang}_verseOptions
  //   - Images/Videos/YouTube/References are global → verseOptions (no prefix)
  String verseOptionsCollection() => '${_currentCode}_verseOptions';
  static String globalVerseOptionsCollection() => 'verseOptions';

  // ── Storage Path Helpers ─────────────────────────────────────────────────────
  String audioStoragePath(String bookName, int chapter, String filename) =>
      'audios/$_currentCode/$bookName/cap_${chapter + 1}_$filename';

  String podcastStoragePath(String filename) =>
      'podcasts/$_currentCode/${DateTime.now().millisecondsSinceEpoch}_$filename';

  // Images/Videos are global (no language prefix)
  static String imageStoragePath(String bookName, int chap, int verse, String baseName) =>
      'imagens_versos/$bookName/cap${chap + 1}_v${verse}_$baseName.jpg';

  static String videoStoragePath(String bookName, int chap, int verse, String filename) =>
      'videos_versos/$bookName/cap${chap + 1}_v${verse}_$filename';

  // ── UI Strings (simple i18n) ────────────────────────────────────────────────
  String get tr_settings => const {'pt': 'Configurações', 'en': 'Settings', 'es': 'Configuración'}[_currentCode] ?? 'Configurações';
  String get tr_bible => const {'pt': 'Bíblia', 'en': 'Bible', 'es': 'Biblia'}[_currentCode] ?? 'Bíblia';
  String get tr_search => const {'pt': 'Pesquisa', 'en': 'Search', 'es': 'Buscar'}[_currentCode] ?? 'Pesquisa';
  String get tr_studies => const {'pt': 'Estudos', 'en': 'Studies', 'es': 'Estudios'}[_currentCode] ?? 'Estudos';
  String get tr_config => const {'pt': 'Config.', 'en': 'Settings', 'es': 'Config.'}[_currentCode] ?? 'Config.';
  String get tr_chapter => const {'pt': 'Capítulo', 'en': 'Chapter', 'es': 'Capítulo'}[_currentCode] ?? 'Capítulo';
  String get tr_verse => const {'pt': 'Versículo', 'en': 'Verse', 'es': 'Versículo'}[_currentCode] ?? 'Versículo';
  String get tr_audioChapter => const {'pt': 'Áudio do cap.', 'en': 'Chapter Audio', 'es': 'Audio del cap.'}[_currentCode] ?? 'Áudio do cap.';
  String get tr_podcasts => const {'pt': 'Podcasts', 'en': 'Podcasts', 'es': 'Podcasts'}[_currentCode] ?? 'Podcasts';
  String get tr_dictionary => const {'pt': 'Dicionário', 'en': 'Dictionary', 'es': 'Diccionario'}[_currentCode] ?? 'Dicionário';
  String get tr_previous => const {'pt': 'Anterior', 'en': 'Previous', 'es': 'Anterior'}[_currentCode] ?? 'Anterior';
  String get tr_next => const {'pt': 'Próximo', 'en': 'Next', 'es': 'Siguiente'}[_currentCode] ?? 'Próximo';
  String get tr_copy => const {'pt': 'Copiar', 'en': 'Copy', 'es': 'Copiar'}[_currentCode] ?? 'Copiar';
  String get tr_share => const {'pt': 'Enviar', 'en': 'Share', 'es': 'Enviar'}[_currentCode] ?? 'Enviar';
  String get tr_highlight => const {'pt': 'Destaque', 'en': 'Highlight', 'es': 'Resaltar'}[_currentCode] ?? 'Destaque';
  String get tr_note => const {'pt': 'Nota', 'en': 'Note', 'es': 'Nota'}[_currentCode] ?? 'Nota';
  String get tr_selectAll => const {'pt': 'Tudo', 'en': 'All', 'es': 'Todo'}[_currentCode] ?? 'Tudo';
  String get tr_close => const {'pt': 'Fechar', 'en': 'Close', 'es': 'Cerrar'}[_currentCode] ?? 'Fechar';
  String get tr_language => const {'pt': 'Idioma', 'en': 'Language', 'es': 'Idioma'}[_currentCode] ?? 'Idioma';
  String get tr_about => const {'pt': 'Sobre A Revelação', 'en': 'About The Revelation', 'es': 'Sobre La Revelación'}[_currentCode] ?? 'Sobre';
  String get tr_darkMode => const {'pt': 'Modo Noturno', 'en': 'Dark Mode', 'es': 'Modo Oscuro'}[_currentCode] ?? 'Modo Noturno';
  String get tr_lightMode => const {'pt': 'Modo Claro', 'en': 'Light Mode', 'es': 'Modo Claro'}[_currentCode] ?? 'Modo Claro';
  String get tr_fontSize => const {'pt': 'Tamanho do Texto', 'en': 'Font Size', 'es': 'Tamaño de Texto'}[_currentCode] ?? 'Tamanho do Texto';
  String get tr_admin => const {'pt': 'Painel do Administrador', 'en': 'Admin Panel', 'es': 'Panel de Admin'}[_currentCode] ?? 'Admin';
  String get tr_preferences => const {'pt': 'Preferências', 'en': 'Preferences', 'es': 'Preferencias'}[_currentCode] ?? 'Preferências';
  String get tr_administration => const {'pt': 'Administração', 'en': 'Administration', 'es': 'Administración'}[_currentCode] ?? 'Administração';
  String get tr_copied => const {'pt': 'Copiado para a área de transferência!', 'en': 'Copied to clipboard!', 'es': '¡Copiado al portapapeles!'}[_currentCode] ?? 'Copiado!';
  String get tr_theApp => const {'pt': 'O App', 'en': 'The App', 'es': 'La App'}[_currentCode] ?? 'O App';
  String get tr_appTitle => const {'pt': 'A Revelação', 'en': 'The Revelation', 'es': 'La Revelación'}[_currentCode] ?? 'A Revelação';
  String get tr_aboutSubtitle => const {'pt': 'Versão 1.0.0 • Daniel & Apocalipse', 'en': 'Version 1.0.0 • Daniel & Revelation', 'es': 'Versión 1.0.0 • Daniel y Apocalipsis'}[_currentCode] ?? 'Versão 1.0.0';
  String get tr_whoWeAre => const {'pt': 'Quem somos', 'en': 'Who we are', 'es': 'Quiénes somos'}[_currentCode] ?? 'Quem somos';
  String get tr_whoWeAreSub => const {'pt': 'Conheça a equipe por trás do app', 'en': 'Meet the team behind the app', 'es': 'Conoce al equipo detrás de la app'}[_currentCode] ?? 'Conheça a equipe';
  String get tr_support => const {'pt': 'Apoie o Ministério', 'en': 'Support the Ministry', 'es': 'Apoya el Ministerio'}[_currentCode] ?? 'Apoie';
  String get tr_supportSub => const {'pt': 'Contribua com doação', 'en': 'Make a donation', 'es': 'Haz una donación'}[_currentCode] ?? 'Contribua';
  String get tr_darkModeActive => const {'pt': 'Tema escuro ativo', 'en': 'Dark theme active', 'es': 'Tema oscuro activo'}[_currentCode] ?? 'Tema escuro ativo';
  String get tr_lightModeActive => const {'pt': 'Tema claro ativo', 'en': 'Light theme active', 'es': 'Tema claro activo'}[_currentCode] ?? 'Tema claro ativo';
  String get tr_notifications => const {'pt': 'Notificações', 'en': 'Notifications', 'es': 'Notificaciones'}[_currentCode] ?? 'Notificações';
  String get tr_notifSub => const {'pt': 'Lembretes de leitura diária', 'en': 'Daily reading reminders', 'es': 'Recordatorios de lectura diaria'}[_currentCode] ?? 'Lembretes';
  String get tr_bibleVersion => const {'pt': 'Versão da Bíblia', 'en': 'Bible Version', 'es': 'Versión de la Biblia'}[_currentCode] ?? 'Versão da Bíblia';
  String get tr_comingSoon => const {'pt': 'Em breve', 'en': 'Coming soon', 'es': 'Próximamente'}[_currentCode] ?? 'Em breve';
  String get tr_textSize => const {'pt': 'Tamanho do Texto', 'en': 'Text Size', 'es': 'Tamaño del Texto'}[_currentCode] ?? 'Tamanho do Texto';
  String get tr_selectAll2 => const {'pt': 'Selecionar Todos', 'en': 'Select All', 'es': 'Seleccionar Todo'}[_currentCode] ?? 'Selecionar Todos';
  String get tr_deselect => const {'pt': 'Desmarcar', 'en': 'Deselect', 'es': 'Deseleccionar'}[_currentCode] ?? 'Desmarcar';
  String get tr_backToSearch => const {'pt': 'Voltar à pesquisa', 'en': 'Back to search', 'es': 'Volver a búsqueda'}[_currentCode] ?? 'Voltar à pesquisa';
}

class LocaleOption {
  final String code;
  final String label;
  final String flag;
  final String bibleAsset;

  const LocaleOption({
    required this.code,
    required this.label,
    required this.flag,
    required this.bibleAsset,
  });
}
