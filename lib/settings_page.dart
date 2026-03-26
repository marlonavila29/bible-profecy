import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'app_locale.dart';
import 'services.dart';
import 'bible_version_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    AppTheme().addListener(_refresh);
    AppLocale().addListener(_refresh);
  }

  @override
  void dispose() {
    AppTheme().removeListener(_refresh);
    AppLocale().removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocale().tr_settings,
            style: GoogleFonts.cinzel(color: t.titleGold)),
        backgroundColor: t.appBar,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.5,
            colors: t.bgGradient,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // App Identity
            _SectionHeader(title: AppLocale().tr_theApp),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: AppLocale().tr_about,
              subtitle: AppLocale().tr_aboutSubtitle,
              onTap: () => _showAbout(context),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.people_outline_rounded,
              label: AppLocale().tr_whoWeAre,
              subtitle: AppLocale().tr_whoWeAreSub,
              comingSoon: true,
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.favorite_outline_rounded,
              label: AppLocale().tr_support,
              subtitle: AppLocale().tr_supportSub,
              comingSoon: true,
            ),

            const SizedBox(height: 28),
            // Preferences
            _SectionHeader(title: AppLocale().tr_preferences),

            // ── Theme Toggle ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      t.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                          'Modo ${t.isDark ? AppLocale().tr_darkMode.split(' ').last : AppLocale().tr_lightMode.split(' ').last}',
                          style: GoogleFonts.inter(
                            color: t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          t.isDark ? AppLocale().tr_darkModeActive : AppLocale().tr_lightModeActive,
                          style: GoogleFonts.inter(
                              color: t.textQuaternary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Animated toggle
                  GestureDetector(
                    onTap: () => AppTheme().toggle(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 56,
                      height: 30,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: t.isDark
                            ? AppTheme.accent.withOpacity(0.3)
                            : const Color(0xFFE0DDD8),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: t.isDark
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.isDark ? AppTheme.accent : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            t.isDark ? Icons.nightlight_round : Icons.wb_sunny,
                            size: 14,
                            color: t.isDark ? Colors.black : AppTheme.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Language Selector ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.language_rounded,
                        color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocale().tr_language,
                          style: GoogleFonts.inter(
                            color: t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${AppLocale().current.flag} ${AppLocale().current.label}',
                          style: GoogleFonts.inter(
                              color: t.textQuaternary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: AppLocale().currentCode,
                    dropdownColor: t.surface,
                    underline: const SizedBox.shrink(),
                    icon: Icon(Icons.expand_more, color: t.textTertiary),
                    items: AppLocale.supportedLocales.map((loc) {
                      return DropdownMenuItem(
                        value: loc.code,
                        child: Text(
                          '${loc.flag} ${loc.label}',
                          style: GoogleFonts.inter(
                            color: t.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (code) async {
                      if (code == null) return;
                      final changed = await AppLocale().setLocale(code);
                      if (changed) {
                        // Reload all data for the new locale
                        await DataService().init();
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Font Size Control ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.text_fields_rounded,
                            color: AppTheme.accent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          AppLocale().tr_textSize,
                          style: GoogleFonts.inter(
                            color: t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${(t.fontSizeScale * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          color: t.textTertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('A', style: TextStyle(color: t.textQuaternary, fontSize: 12)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.accent,
                            inactiveTrackColor: t.divider,
                            thumbColor: AppTheme.accent,
                            overlayColor: AppTheme.accent.withOpacity(0.2),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: t.fontSizeScale,
                            min: AppTheme.minFontScale,
                            max: AppTheme.maxFontScale,
                            divisions: 8,
                            onChanged: (val) {
                              AppTheme().setFontSizeScale(val);
                            },
                          ),
                        ),
                      ),
                      Text('A', style: TextStyle(color: t.textQuaternary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: AppLocale().tr_notifications,
              subtitle: AppLocale().tr_notifSub,
              comingSoon: true,
            ),

            const SizedBox(height: 8),
            // ── Bible Version Selector ──
            _BibleVersionTile(onRefresh: () => setState(() {})),



            const SizedBox(height: 40),
            Center(
              child: Text(
                'A Revelação • Daniel & Apocalipse\nv1.0.0',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: t.textMinimal, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final t = AppTheme();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('A Revelação',
            style: GoogleFonts.cinzel(
                color: t.titleGold, fontWeight: FontWeight.bold)),
        content: Text(
          'Bíblia de estudo focada nos livros de Daniel e Apocalipse.\n\nExplore, pesquise e aprofunde-se nas profecias bíblicas com ferramentas estudadas e interativas.',
          style: GoogleFonts.inter(color: t.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppTheme.accent.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool comingSoon;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: comingSoon ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: comingSoon ? t.textQuaternary : AppTheme.accent,
                    size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                          color: comingSoon ? t.textTertiary : t.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        )),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: GoogleFonts.inter(
                              color: t.textQuaternary, fontSize: 12)),
                  ],
                ),
              ),
              if (comingSoon)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(AppLocale().tr_comingSoon,
                      style:
                          GoogleFonts.inter(color: t.textQuaternary, fontSize: 10)),
                )
              else if (onTap != null)
                Icon(Icons.chevron_right, color: t.textQuaternary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bible Version Tile ───────────────────────────────────────────────────────

class _BibleVersionTile extends StatefulWidget {
  final VoidCallback onRefresh;
  const _BibleVersionTile({required this.onRefresh});

  @override
  State<_BibleVersionTile> createState() => _BibleVersionTileState();
}

class _BibleVersionTileState extends State<_BibleVersionTile> {
  final svc = BibleVersionService();

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return GestureDetector(
      onTap: () => _showVersionSettings(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_outlined,
                  color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocale().tr_bibleVersion,
                      style: GoogleFonts.inter(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      )),
                  Text(svc.primaryVersion.name,
                      style: GoogleFonts.inter(
                          color: AppTheme.accent, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textQuaternary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showVersionSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VersionSettingsSheet(
        onChanged: () {
          setState(() {});
          widget.onRefresh();
        },
      ),
    );
  }
}

class _VersionSettingsSheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _VersionSettingsSheet({required this.onChanged});

  @override
  State<_VersionSettingsSheet> createState() => _VersionSettingsSheetState();
}

class _VersionSettingsSheetState extends State<_VersionSettingsSheet> {
  final svc = BibleVersionService();
  late String _primaryId;
  late List<String> _compareIds;

  @override
  void initState() {
    super.initState();
    _primaryId = svc.primaryVersionId;
    _compareIds = List.from(svc.compareVersionIds);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Versões da Bíblia',
                          style: GoogleFonts.cinzel(
                              color: t.titleGold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await svc.setPrimaryVersion(_primaryId);
                        await svc.setCompareVersions(_compareIds);
                        widget.onChanged();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text('Salvar',
                          style: GoogleFonts.inter(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Divider(color: t.divider, height: 1),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Primary version
                    Text('VERSÃO PRINCIPAL',
                        style: GoogleFonts.inter(
                            color: AppTheme.accent.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    ...kBibleVersions.map((v) {
                      final selected = v.id == _primaryId;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _primaryId = v.id;
                          _compareIds.remove(v.id);
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.accent.withOpacity(0.08)
                                : t.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.accent.withOpacity(0.4)
                                  : t.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.accent
                                      : t.isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(v.shortName,
                                    style: GoogleFonts.inter(
                                        color: selected
                                            ? Colors.black
                                            : t.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.name,
                                        style: GoogleFonts.inter(
                                            color: t.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    Text(v.language,
                                        style: GoogleFonts.inter(
                                            color: t.textQuaternary,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(Icons.check_circle,
                                    color: AppTheme.accent, size: 20),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    Text('VERSÕES PARA COMPARAR',
                        style: GoogleFonts.inter(
                            color: AppTheme.accent.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(
                      'Selecione as versões que aparecerão na comparação de versículos.',
                      style: GoogleFonts.inter(
                          color: t.textTertiary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ...kBibleVersions
                        .where((v) => v.id != _primaryId)
                        .map((v) {
                      final selected = _compareIds.contains(v.id);
                      return CheckboxListTile(
                        value: selected,
                        activeColor: AppTheme.accent,
                        checkColor: Colors.black,
                        side: BorderSide(color: t.textTertiary),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${v.shortName} · ${v.name}',
                          style: GoogleFonts.inter(
                              color: t.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(v.language,
                            style: GoogleFonts.inter(
                                color: t.textQuaternary, fontSize: 12)),
                        onChanged: (_) => setState(() {
                          if (selected) {
                            _compareIds.remove(v.id);
                          } else {
                            _compareIds.add(v.id);
                          }
                        }),
                      );
                    }),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
