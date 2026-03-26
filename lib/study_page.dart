import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services.dart';
import 'favorites_page.dart';
import 'notes_page.dart';
import 'app_theme.dart';

class StudyPage extends StatefulWidget {
  final void Function(int bookIndex, int chapterIndex, int verseNumber)?
      onNavigateToVerse;

  const StudyPage({super.key, this.onNavigateToVerse});

  @override
  State<StudyPage> createState() => StudyPageState();
}

class StudyPageState extends State<StudyPage> {
  int _favCount = 0;
  int _noteCount = 0;

  @override
  void initState() {
    super.initState();
    AppTheme().addListener(_onTheme);
    refresh();
  }

  @override
  void dispose() {
    AppTheme().removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() => setState(() {});

  void refresh() {
    final ds = DataService();
    int favs = 0;
    int notes = 0;
    ds.userVerseData.forEach((_, data) {
      if (data.isFavorite) favs++;
      if (data.personalNote != null && data.personalNote!.isNotEmpty) notes++;
    });
    setState(() {
      _favCount = favs;
      _noteCount = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return Scaffold(
      appBar: AppBar(
        title: Text('Central de Estudo',
            style: GoogleFonts.cinzel(color: t.titleGold)),
        backgroundColor: t.appBar,
        elevation: t.isDark ? 0 : 0.5,
        shadowColor: t.isDark ? Colors.transparent : Colors.black12,
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
          padding: const EdgeInsets.all(24),
          children: [
            // ── Active Features ──────────────────────────────
            _StudyCard(
              icon: Icons.bookmark_rounded,
              title: 'Versículos Favoritos',
              description:
                  'Seus versículos marcados como favoritos para acesso rápido.',
              badge: _favCount > 0 ? '$_favCount' : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FavoritesPage(
                        onNavigateToVerse: widget.onNavigateToVerse),
                  ),
                ).then((_) => refresh());
              },
            ),
            const SizedBox(height: 16),
            _StudyCard(
              icon: Icons.edit_note_rounded,
              title: 'Minhas Anotações',
              description:
                  'Anotações pessoais que você adicionou aos versículos.',
              badge: _noteCount > 0 ? '$_noteCount' : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NotesPage(onNavigateToVerse: widget.onNavigateToVerse),
                  ),
                ).then((_) => refresh());
              },
            ),

            const SizedBox(height: 32),
            Divider(color: t.divider),
            const SizedBox(height: 24),

            // ── Coming Soon Features ─────────────────────────
            _StudyCard(
              icon: Icons.quiz_outlined,
              title: 'Quiz Bíblico',
              description:
                  'Teste seu conhecimento sobre Daniel e Apocalipse com perguntas e respostas interativas.',
              comingSoon: true,
            ),
            const SizedBox(height: 16),
            _StudyCard(
              icon: Icons.timeline,
              title: 'Linha do Tempo',
              description:
                  'Visualize eventos proféticos e históricos em uma linha do tempo interativa.',
              comingSoon: true,
            ),
            const SizedBox(height: 16),
            _StudyCard(
              icon: Icons.bar_chart_rounded,
              title: 'Gráficos Proféticos',
              description:
                  'Análises visuais de períodos proféticos, impérios e profecias cumpridas.',
              comingSoon: true,
            ),
            const SizedBox(height: 16),
            _StudyCard(
              icon: Icons.school_outlined,
              title: 'Estudos Guiados',
              description:
                  'Planos de leitura e estudos temáticos sobre os grandes temas proféticos.',
              comingSoon: true,
            ),
            const SizedBox(height: 16),
            _StudyCard(
              icon: Icons.compare_arrows_rounded,
              title: 'Paralelos Proféticos',
              description:
                  'Compare passagens de Daniel com Apocalipse e entenda as conexões entre os livros.',
              comingSoon: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool comingSoon;
  final String? badge;
  final VoidCallback? onTap;

  const _StudyCard({
    required this.icon,
    required this.title,
    required this.description,
    this.comingSoon = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return GestureDetector(
      onTap: comingSoon ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: comingSoon
                ? t.border
                : t.accentOnBg.withOpacity(0.25),
          ),
          boxShadow: t.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: t.accentOnBg.withOpacity(comingSoon ? 0.06 : 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: t.accentOnBg
                        .withOpacity(comingSoon ? 0.12 : 0.25)),
              ),
              child: Icon(icon,
                  color: comingSoon
                      ? t.iconInactive
                      : t.accentOnBg,
                  size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: GoogleFonts.inter(
                                color: comingSoon
                                    ? t.textTertiary
                                    : t.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (comingSoon)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.chipBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Em breve',
                              style: GoogleFonts.inter(
                                  color: t.textQuaternary, fontSize: 10)),
                        ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.accentOnBg.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(badge!,
                              style: GoogleFonts.inter(
                                  color: t.accentOnBg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(description,
                      style: GoogleFonts.inter(
                          color: comingSoon
                              ? t.textQuaternary
                              : t.textTertiary,
                          fontSize: 13,
                          height: 1.5)),
                ],
              ),
            ),
            if (!comingSoon) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: t.textQuaternary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
