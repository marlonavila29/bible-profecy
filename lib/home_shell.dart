import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'search_page.dart';
import 'study_page.dart';
import 'reader_page.dart';
import 'settings_page.dart';
import 'app_theme.dart';
import 'app_locale.dart';
import 'audio_player_widget.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0; // Start on Bíblia tab (index 0)
  final GlobalKey<ReaderPageState> _readerKey = GlobalKey<ReaderPageState>();
  final GlobalKey<StudyPageState> _studyKey = GlobalKey<StudyPageState>();

  // ── Global Audio State ──────────────────────────────────────────────────────
  String? _globalAudioUrl;
  String _globalAudioTitle = '';
  String _globalAudioSubtitle = '';
  bool _globalAudioIsPodcast = false;
  Key? _globalAudioKey;

  void _playGlobalAudio({
    required String url,
    required String title,
    String subtitle = '',
    bool isPodcast = false,
  }) {
    setState(() {
      _globalAudioUrl = url;
      _globalAudioTitle = title;
      _globalAudioSubtitle = subtitle;
      _globalAudioIsPodcast = isPodcast;
      _globalAudioKey = ValueKey('global_audio_${url.hashCode}_${DateTime.now().millisecondsSinceEpoch}');
    });
  }

  void _stopGlobalAudio() {
    setState(() {
      _globalAudioUrl = null;
      _globalAudioKey = null;
    });
  }

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

  void _onSearchResultTap(int bookIndex, int chapterIndex, int verseNumber) {
    _readerKey.currentState?.navigateToVerse(
      bookIndex: bookIndex,
      chapterIndex: chapterIndex,
      verseNumber: verseNumber,
      onBackToSearch: () => setState(() => _currentIndex = 2),
    );
    setState(() => _currentIndex = 0);
  }

  void _onTabChange(int i) {
    setState(() => _currentIndex = i);
    if (i == 1) {
      _studyKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                ReaderPage(
                  key: _readerKey,
                  onPlayAudio: _playGlobalAudio,
                  onStopAudio: _stopGlobalAudio,
                  isGlobalAudioPlaying: _globalAudioUrl != null,
                ),
                StudyPage(key: _studyKey, onNavigateToVerse: _onSearchResultTap),
                SearchPage(onResultTap: _onSearchResultTap),
                const SettingsPage(),
              ],
            ),
          ),
          // ── Global Audio Player (visible on all tabs) ──
          if (_globalAudioUrl != null)
            AudioPlayerWidget(
              key: _globalAudioKey,
              audioUrl: _globalAudioUrl!,
              title: _globalAudioTitle,
              subtitle: _globalAudioSubtitle,
              isPodcast: _globalAudioIsPodcast,
              onClose: _stopGlobalAudio,
            ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabChange,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    final loc = AppLocale();
    final items = [
      _NavItem(icon: Icons.menu_book_rounded, label: loc.tr_bible),
      _NavItem(icon: Icons.school_rounded, label: loc.tr_studies),
      _NavItem(icon: Icons.search_rounded, label: loc.tr_search),
      _NavItem(icon: Icons.settings_rounded, label: loc.tr_config),
    ];

    return Container(
      decoration: BoxDecoration(
        color: t.isDark ? const Color(0xFF0A0E1A) : Colors.white,
        border: Border(top: BorderSide(color: t.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.5 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                            horizontal: selected ? 16 : 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.accent.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          items[i].icon,
                          size: 22,
                          color: selected
                              ? AppTheme.accent
                              : t.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected
                              ? AppTheme.accent
                              : t.textQuaternary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
