import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme extends ChangeNotifier {
  static final AppTheme _instance = AppTheme._internal();
  factory AppTheme() => _instance;
  AppTheme._internal();

  bool _isDark = true;
  bool get isDark => _isDark;

  double _fontSizeScale = 1.0;
  double get fontSizeScale => _fontSizeScale;

  // Limites da fonte (ex: 80% a 160% do tamanho original)
  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.6;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('isDarkMode') ?? true;
    _fontSizeScale = prefs.getDouble('fontSizeScale') ?? 1.0;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDark);
    notifyListeners();
  }

  Future<void> setFontSizeScale(double scale) async {
    if (scale < minFontScale) scale = minFontScale;
    if (scale > maxFontScale) scale = maxFontScale;
    
    if (_fontSizeScale != scale) {
      _fontSizeScale = scale;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('fontSizeScale', _fontSizeScale);
      notifyListeners();
    }
  }

  // ── Core Palette ────────────────────────────────────────
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFCD34D);

  // ── Dark palette ────────────────────────────────────────
  static const Color _darkBg = Color(0xFF0B0F19);
  static const Color _darkSurface = Color(0xFF1E293B);
  static const Color _darkAppBar = Color(0x990F172A);

  // ── Light palette ───────────────────────────────────────
  static const Color _lightBg = Color(0xFFF8F6F1);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightAppBar = Color(0xFFFAF8F5);

  // Backgrounds
  Color get bg => _isDark ? _darkBg : _lightBg;
  Color get surface => _isDark ? _darkSurface : _lightSurface;
  Color get appBar => _isDark ? _darkAppBar : _lightAppBar;

  // Text hierarchy
  Color get textPrimary =>
      _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1A1A2E);
  Color get textSecondary =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151);
  Color get textTertiary =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get textQuaternary =>
      _isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);
  Color get textMinimal =>
      _isDark ? const Color(0xFF334155) : const Color(0xFFD1D5DB);

  // Borders & dividers
  Color get divider =>
      _isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E2DD);
  Color get border =>
      _isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE8E5E0);

  // Card backgrounds
  Color get cardBg =>
      _isDark ? Colors.white.withOpacity(0.04) : Colors.white;
  Color get cardBgElevated =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF5F3EE);

  // Icon colors (inactive)
  Color get iconInactive =>
      _isDark ? const Color(0xFF64748B) : const Color(0xFFADB5BD);

  // Verse text on the bible reader
  Color get verseText =>
      _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748);
  Color get verseTextBack =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF4A5568);

  // Modal / bottom sheet background
  Color get modalBg =>
      _isDark ? const Color(0xFF1E293B) : Colors.white;

  // Chip / tag backgrounds
  Color get chipBg =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF0EDE8);

  Brightness get brightness => _isDark ? Brightness.dark : Brightness.light;

  List<Color> get bgGradient => _isDark
      ? [_darkSurface, _darkBg]
      : [_lightBg, const Color(0xFFF0EDE7)];

  // ── Accent on light / dark contexts ─────────────────────
  Color get accentOnBg => _isDark ? accent : const Color(0xFFD97706);
  Color get titleGold => _isDark ? accentLight : const Color(0xFFB45309);

  ThemeData get themeData {
    final base = _isDark ? ThemeData.dark() : ThemeData.light();
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.black,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: appBar,
        elevation: _isDark ? 0 : 0.5,
        shadowColor: _isDark ? Colors.transparent : Colors.black12,
        titleTextStyle: GoogleFonts.cinzel(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: titleGold,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
    );
  }
}
