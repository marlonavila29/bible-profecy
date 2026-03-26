import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'bible_version_service.dart';

/// Bottom sheet that shows a verse compared across multiple Bible versions.
class VerseComparisonSheet extends StatefulWidget {
  final String bookName;
  final int chapter; // 1-based
  final int verse;   // 1-based
  final String primaryText;

  const VerseComparisonSheet({
    super.key,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.primaryText,
  });

  static Future<void> show(BuildContext context, {
    required String bookName,
    required int chapter,
    required int verse,
    required String primaryText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseComparisonSheet(
        bookName: bookName,
        chapter: chapter,
        verse: verse,
        primaryText: primaryText,
      ),
    );
  }

  @override
  State<VerseComparisonSheet> createState() => _VerseComparisonSheetState();
}

class _VerseComparisonSheetState extends State<VerseComparisonSheet> {
  final svc = BibleVersionService();
  final Map<BibleVersion, String> _results = {};
  final Map<BibleVersion, bool> _loading = {};
  List<BibleVersion> _selectedVersions = [];

  @override
  void initState() {
    super.initState();
    _initVersions();
  }

  void _initVersions() {
    // Default: all compare versions, or show all if none configured
    final ids = svc.compareVersionIds.isNotEmpty
        ? svc.compareVersionIds
        : kBibleVersions
            .where((v) => v.id != svc.primaryVersionId)
            .take(3)
            .map((v) => v.id)
            .toList();

    _selectedVersions = ids
        .map((id) => kBibleVersions.firstWhere((v) => v.id == id,
            orElse: () => kBibleVersions.first))
        .toList();

    _fetchAll();
  }

  void _fetchAll() {
    for (final version in _selectedVersions) {
      _fetchVersion(version);
    }
  }

  void _fetchVersion(BibleVersion version) async {
    setState(() => _loading[version] = true);
    final text = await svc.fetchVerse(
      versionId: version.id,
      bookName: widget.bookName,
      chapter: widget.chapter,
      verse: widget.verse,
    );
    if (mounted) {
      setState(() {
        _results[version] = text;
        _loading[version] = false;
      });
    }
  }

  void _toggleVersion(BibleVersion version) {
    setState(() {
      if (_selectedVersions.any((v) => v.id == version.id)) {
        _selectedVersions.removeWhere((v) => v.id == version.id);
        _results.remove(version);
      } else {
        _selectedVersions.add(version);
        _fetchVersion(version);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    final ref = '${widget.bookName} ${widget.chapter}:${widget.verse}';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.compare_arrows_rounded,
                          color: AppTheme.accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Comparar Versões',
                              style: GoogleFonts.cinzel(
                                color: t.titleGold,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              )),
                          Text(ref,
                              style: GoogleFonts.inter(
                                color: t.textTertiary,
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showVersionPicker(context),
                      icon: Icon(Icons.tune, size: 16, color: AppTheme.accent),
                      label: Text('Versões',
                          style: GoogleFonts.inter(
                              color: AppTheme.accent, fontSize: 13)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: t.textTertiary, size: 22),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: t.divider, height: 1),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Primary version card
                    _VersionCard(
                      version: svc.primaryVersion,
                      text: widget.primaryText,
                      isPrimary: true,
                      isLoading: false,
                    ),
                    // Compare versions
                    if (_selectedVersions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.library_books_outlined,
                                  color: t.textQuaternary, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'Toque em "Versões" para\nselecionar traduções para comparar',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    color: t.textTertiary, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._selectedVersions.map((version) {
                        final isLoading = _loading[version] ?? false;
                        final text = _results[version];
                        return _VersionCard(
                          version: version,
                          text: text ?? '',
                          isPrimary: false,
                          isLoading: isLoading,
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVersionPicker(BuildContext context) {
    final t = AppTheme();
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setInnerState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, scrollCtrl) => Column(
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
                        Text('Selecionar Traduções',
                            style: GoogleFonts.cinzel(
                                color: t.titleGold,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Divider(color: t.divider),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      children: [
                        ..._buildGroupedVersionList(setInnerState, t),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildGroupedVersionList(StateSetter setInner, AppTheme t) {
    final groups = <String, List<BibleVersion>>{};
    for (final v in kBibleVersions) {
      if (v.id == svc.primaryVersionId) continue; // skip primary
      (groups[v.language] ??= []).add(v);
    }

    final widgets = <Widget>[];
    for (final lang in groups.keys) {
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(lang.toUpperCase(),
            style: GoogleFonts.inter(
                color: AppTheme.accent.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
      ));
      for (final version in groups[lang]!) {
        final isSelected = _selectedVersions.any((v) => v.id == version.id);
        widgets.add(ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accent.withOpacity(0.15)
                  : t.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.accent.withOpacity(0.4) : t.border,
              ),
            ),
            child: Center(
              child: Text(version.shortName.length > 4
                  ? version.shortName.substring(0, 3)
                  : version.shortName,
                style: GoogleFonts.inter(
                  color: isSelected ? AppTheme.accent : t.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          title: Text(version.name,
              style: GoogleFonts.inter(
                  color: t.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          subtitle: Text(version.shortName,
              style: GoogleFonts.inter(color: t.textQuaternary, fontSize: 12)),
          trailing: Checkbox(
            value: isSelected,
            activeColor: AppTheme.accent,
            checkColor: Colors.black,
            side: BorderSide(color: t.textTertiary),
            onChanged: (_) {
              _toggleVersion(version);
              setInner(() {});
            },
          ),
          onTap: () {
            _toggleVersion(version);
            setInner(() {});
          },
        ));
      }
    }
    return widgets;
  }
}

// ─── Individual Version Card ─────────────────────────────────────────────────

class _VersionCard extends StatelessWidget {
  final BibleVersion version;
  final String text;
  final bool isPrimary;
  final bool isLoading;

  const _VersionCard({
    required this.version,
    required this.text,
    required this.isPrimary,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppTheme.accent.withOpacity(0.06)
            : t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary
              ? AppTheme.accent.withOpacity(0.3)
              : t.border,
          width: isPrimary ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version label header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? AppTheme.accent
                        : t.isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    version.shortName,
                    style: GoogleFonts.inter(
                      color: isPrimary ? Colors.black : t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    version.name,
                    style: GoogleFonts.inter(
                      color: t.textTertiary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Principal',
                        style: GoogleFonts.inter(
                            color: AppTheme.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                if (!isLoading && text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Texto (${version.shortName}) copiado!'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.accent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.copy_outlined,
                          size: 16, color: t.textQuaternary),
                    ),
                  ),
              ],
            ),
          ),
          // Verse text
          Padding(
            padding: const EdgeInsets.all(14),
            child: isLoading
                ? Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Carregando...',
                          style: GoogleFonts.inter(
                              color: t.textQuaternary, fontSize: 13)),
                    ],
                  )
                : version.isRtl
                    // Hebrew/Aramaic: RTL layout with bigger noto serif font
                    ? Directionality(
                        textDirection: TextDirection.rtl,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text.isEmpty ? '(Texto não disponível)' : text,
                              textDirection: TextDirection.rtl,
                              style: GoogleFonts.notoSerifHebrew(
                                color: text.isEmpty ? t.textQuaternary : t.textPrimary,
                                fontSize: 18,
                                height: 1.8,
                                fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                            if (text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  version.id == 'heb'
                                      ? '⚠️ Daniel 1-2:3 e 8-12 em Hebraico; 2:4-7:28 em Aramaico'
                                      : 'αβ Grego Koinê (manuscrito Tyndale House)',
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.inter(
                                      color: t.textQuaternary,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      )
                    // Standard LTR text
                    : Text(
                        text.isEmpty ? '(Versículo não disponível)' : text,
                        style: GoogleFonts.inter(
                          color: text.isEmpty ? t.textQuaternary : t.textPrimary,
                          fontSize: 15,
                          height: 1.65,
                          fontStyle:
                              text.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
