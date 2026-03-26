import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'services.dart';
import 'firestore_service.dart';

import 'app_error.dart';
import 'app_theme.dart';
import 'app_locale.dart';
import 'bible_version_service.dart';
import 'verse_comparison_sheet.dart';

class ReaderPage extends StatefulWidget {
  final void Function(
      {required String url,
      required String title,
      String subtitle,
      bool isPodcast})? onPlayAudio;
  final VoidCallback? onStopAudio;
  final bool isGlobalAudioPlaying;

  const ReaderPage({
    super.key,
    this.onPlayAudio,
    this.onStopAudio,
    this.isGlobalAudioPlaying = false,
  });

  @override
  ReaderPageState createState() => ReaderPageState();
}

class ReaderPageState extends State<ReaderPage> {
  int currentBookIndex = 0;
  int currentChapterIndex = 0;

  // Search navigation state
  bool _fromSearch = false;
  int? _highlightVerseNumber;
  VoidCallback? _backToSearch;

  // Verse selection state
  final Set<int> _selectedVerses = {};
  bool get _isSelecting => _selectedVerses.isNotEmpty;
  bool _showColorPalette = false;

  // Podcast toggle
  bool _showPodcasts = false;

  // API-fetched chapter data (for non-local Bible versions)
  List<Verse>? _apiChapter;
  bool _apiLoading = false;

  /// Called from SearchPage via GlobalKey to navigate to a specific verse.
  void navigateToVerse({
    required int bookIndex,
    required int chapterIndex,
    required int verseNumber,
    VoidCallback? onBackToSearch,
  }) {
    setState(() {
      currentBookIndex = bookIndex;
      currentChapterIndex = chapterIndex;
      _highlightVerseNumber = verseNumber;
      _fromSearch = true;
      _backToSearch = onBackToSearch;
    });
    _apiChapter = null;
    _tryFetchApiChapter();
  }

  void _toggleVerseSelection(int verseNumber) {
    setState(() {
      if (_selectedVerses.contains(verseNumber)) {
        _selectedVerses.remove(verseNumber);
        if (_selectedVerses.isEmpty) _showColorPalette = false;
      } else {
        _selectedVerses.add(verseNumber);
      }
    });
  }

  void _selectAllVerses() {
    final book = DataService().books[currentBookIndex];
    final chapter = book.chapters[currentChapterIndex];
    setState(() {
      if (_selectedVerses.length == chapter.length) {
        _selectedVerses.clear();
        _showColorPalette = false;
      } else {
        _selectedVerses.clear();
        for (final v in chapter) {
          _selectedVerses.add(v.number);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedVerses.clear();
      _showColorPalette = false;
    });
  }

  String _getSelectedText() {
    final book = DataService().books[currentBookIndex];
    final chapter = book.chapters[currentChapterIndex];
    final sorted = _selectedVerses.toList()..sort();

    final List<List<int>> ranges = [];
    for (final vn in sorted) {
      if (ranges.isEmpty || vn != ranges.last.last + 1) {
        ranges.add([vn]);
      } else {
        ranges.last.add(vn);
      }
    }

    final buffer = StringBuffer();
    for (final range in ranges) {
      final texts = range.map((vn) {
        final verse = chapter.firstWhere((v) => v.number == vn);
        return verse.text;
      }).join(' ');

      final firstV = range.first;
      final lastV = range.last;
      final ref = firstV == lastV
          ? '${book.name} ${currentChapterIndex + 1}:$firstV'
          : '${book.name} ${currentChapterIndex + 1}:$firstV-$lastV';

      buffer.write('"$texts" - $ref');
      if (range != ranges.last) buffer.write('\n\n');
    }
    return buffer.toString().trim();
  }

  void _copySelected() {
    final text = _getSelectedText();
    Clipboard.setData(ClipboardData(text: text));
    AppFeedback.showSuccess(context, 'Copiado para a área de transferência!');
    _clearSelection();
  }

  void _shareSelected() {
    final text = _getSelectedText();
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      AppFeedback.showSuccess(
          context, 'Texto copiado. Cole em qualquer app para compartilhar!');
    }
    _clearSelection();
  }

  void _highlightSelectedVerses(int? colorValue) {
    final book = DataService().books[currentBookIndex];
    for (final vn in _selectedVerses) {
      final key = '${book.name}_${currentChapterIndex}_$vn';
      var userData = DataService().userVerseData[key] ?? UserVerseData();
      userData = UserVerseData(
          highlightColor: colorValue, personalNote: userData.personalNote);
      DataService().saveUserVerseData(key, userData);
    }
    setState(() {
      _showColorPalette = false;
    });
    _clearSelection();
  }

  void _addNoteToSelectedVerses() {
    final book = DataService().books[currentBookIndex];
    final sorted = _selectedVerses.toList()..sort();
    final key = '${book.name}_${currentChapterIndex}_${sorted.first}';
    final chapter = book.chapters[currentChapterIndex];
    final verse = chapter.firstWhere((v) => v.number == sorted.first);
    _clearSelection();
    _openPersonalNoteDialog(key, currentChapterIndex, verse);
  }

  void _toggleFavoriteSelected() {
    final book = DataService().books[currentBookIndex];
    // If any selected verse is NOT a favorite, toggle all ON; otherwise toggle all OFF
    bool isTogglingOn = _selectedVerses.any((vn) {
      final key = '${book.name}_${currentChapterIndex}_$vn';
      return !(DataService().userVerseData[key]?.isFavorite ?? false);
    });

    for (final vn in _selectedVerses) {
      final key = '${book.name}_${currentChapterIndex}_$vn';
      final userData = DataService().userVerseData[key] ?? UserVerseData();
      DataService().saveUserVerseData(key, userData.copyWith(isFavorite: isTogglingOn));
    }

    if (mounted) {
      AppFeedback.showSuccess(context,
          isTogglingOn ? 'Adicionado aos favoritos!' : 'Removido dos favoritos!');
    }
    _clearSelection();
  }

  @override
  void initState() {
    super.initState();
    AppTheme().addListener(_onRefresh);
    BibleVersionService().addListener(_onVersionChange);
    AppLocale().addListener(_onRefresh);
    _tryFetchApiChapter();
    _refreshAudioInBackground();
  }

  /// Silently refreshes chapter audio and podcasts from Firestore
  /// so newly uploaded content appears without restarting the app.
  void _refreshAudioInBackground() {
    final fs = FirestoreService();
    final ds = DataService();
    fs.loadChapterAudio().then((remote) {
      if (remote.isNotEmpty) {
        ds.chapterAudio = remote;
        if (mounted) setState(() {});
      }
    }).catchError((_) {});
    fs.loadPodcasts().then((remote) {
      if (remote.isNotEmpty) {
        ds.podcasts = remote;
        if (mounted) setState(() {});
      }
    }).catchError((_) {});
  }

  /// If the current chapter has no cached audio URL, try fetching from Firestore.
  void _refreshAudioIfMissing() {
    final ds = DataService();
    final book = ds.books[currentBookIndex];
    final key = '${book.name}_$currentChapterIndex';
    if (!ds.chapterAudio.containsKey(key)) {
      _refreshAudioInBackground();
    }
  }

  @override
  void dispose() {
    AppTheme().removeListener(_onRefresh);
    BibleVersionService().removeListener(_onVersionChange);
    AppLocale().removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    if (mounted) setState(() {});
  }

  void _onVersionChange() {
    _apiChapter = null;
    _tryFetchApiChapter();
    if (mounted) setState(() {});
  }

  void _tryFetchApiChapter() async {
    final bvs = BibleVersionService();
    if (bvs.isPrimaryLocal) {
      if (_apiChapter != null) {
        setState(() => _apiChapter = null);
      }
      return;
    }
    setState(() => _apiLoading = true);
    final book = DataService().books[currentBookIndex];
    final chapterNum = currentChapterIndex + 1;

    try {
      final verses = await bvs.fetchChapter(
        bookName: book.name,
        chapter: chapterNum,
      );
      if (mounted) {
        setState(() {
          _apiChapter = verses;
          _apiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiChapter = [];
          _apiLoading = false;
        });
      }
    }
  }

  void _showWordMeaning(String word, DictEntry entry) {
    final t = AppTheme();
    final refs = entry.references
        .expand((e) => e.split(RegExp(r'[,;]')))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: t.surface,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(word.toUpperCase(),
                      style: GoogleFonts.cinzel(
                          color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  if (entry.originalWord != null &&
                      entry.originalWord!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(entry.originalWord!,
                          style: GoogleFonts.lora(
                              color: t.textTertiary,
                              fontStyle: FontStyle.italic,
                              fontSize: 16)),
                    ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.meaning,
                        style: TextStyle(fontSize: 17, color: t.textSecondary)),
                    if (refs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Divider(color: t.divider),
                      const SizedBox(height: 8),
                      Text('Referências',
                          style: GoogleFonts.inter(
                              color: t.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: refs.map((ref) => GestureDetector(
                          onTap: () => _fetchAndShowReferenceText(ref),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.accent.withOpacity(0.3)),
                            ),
                            child: Text(ref,
                                style: GoogleFonts.inter(
                                    color: AppTheme.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar',
                      style: TextStyle(color: AppTheme.accent)),
                ),
              ],
            ));
  }
  void _showQuickVersionPicker() {
    final t = AppTheme();
    final bvs = BibleVersionService();
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (ctx, scrollCtrl) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: t.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text('Versão da Bíblia',
                        style: GoogleFonts.cinzel(
                            color: t.titleGold,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: t.textTertiary, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(color: t.divider, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: kBibleVersions.length,
                  itemBuilder: (c, i) {
                    final v = kBibleVersions[i];
                    final isSelected = v.id == bvs.primaryVersionId;
                    return ListTile(
                      leading: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accent.withOpacity(0.15)
                              : t.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accent.withOpacity(0.4)
                                : t.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            v.shortName.length > 4
                                ? v.shortName.substring(0, 3)
                                : v.shortName,
                            style: GoogleFonts.inter(
                              color: isSelected ? AppTheme.accent : t.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      title: Text(v.name,
                          style: GoogleFonts.inter(
                              color: t.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text('${v.language} • ${v.shortName}',
                          style: GoogleFonts.inter(
                              color: t.textQuaternary, fontSize: 12)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.accent, size: 22)
                          : null,
                      onTap: () async {
                        await bvs.setPrimaryVersion(v.id);
                        if (mounted) {
                          Navigator.pop(context);
                          _tryFetchApiChapter();
                          setState(() {});
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _prevChapter() {
    if (currentChapterIndex > 0) {
      currentChapterIndex--;
    } else if (currentBookIndex > 0) {
      currentBookIndex--;
      currentChapterIndex =
          DataService().books[currentBookIndex].chapters.length - 1;
    }
    _apiChapter = null;
    _selectedVerses.clear();
    _showColorPalette = false;
    _fromSearch = false;
    _highlightVerseNumber = null;
    setState(() {});
    _tryFetchApiChapter();
    _refreshAudioIfMissing();
  }

  void _nextChapter() {
    final maxChap = DataService().books[currentBookIndex].chapters.length - 1;
    if (currentChapterIndex < maxChap) {
      currentChapterIndex++;
    } else if (currentBookIndex < DataService().books.length - 1) {
      currentBookIndex++;
      currentChapterIndex = 0;
    }
    _apiChapter = null;
    _selectedVerses.clear();
    _showColorPalette = false;
    _fromSearch = false;
    _highlightVerseNumber = null;
    setState(() {});
    _tryFetchApiChapter();
    _refreshAudioIfMissing();
  }

  void _showVerseOptions(Book book, int chapterIndex, Verse verse) {
    final key = "${book.name}_${chapterIndex}_${verse.number}";
    final opts = DataService().verseOptions[key] ?? VerseOptions();
    final t = AppTheme();

    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                  'Opções: ${book.name} ${chapterIndex + 1}:${verse.number}',
                  style: GoogleFonts.cinzel(
                      fontSize: 18,
                      color: t.titleGold,
                      fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: Icon(Icons.comment,
                  color: opts.comments.isNotEmpty
                      ? t.textPrimary
                      : t.textQuaternary),
              title: Text('Ver Comentários',
                  style: TextStyle(
                      color: opts.comments.isNotEmpty
                          ? t.textPrimary
                          : t.textQuaternary)),
              enabled: opts.comments.isNotEmpty,
              onTap: opts.comments.isNotEmpty
                  ? () {
                      Navigator.pop(ctx);
                      _showComments(book, chapterIndex, verse, opts.comments);
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(Icons.image,
                  color: opts.images.isNotEmpty
                      ? t.textPrimary
                      : t.textQuaternary),
              title: Text('Ver Imagem',
                  style: TextStyle(
                      color: opts.images.isNotEmpty
                          ? t.textPrimary
                          : t.textQuaternary)),
              enabled: opts.images.isNotEmpty,
              onTap: opts.images.isNotEmpty
                  ? () {
                      Navigator.pop(ctx);
                      _showMedia(opts.images, "Imagens");
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(Icons.gif,
                  color:
                      opts.gifs.isNotEmpty ? t.textPrimary : t.textQuaternary),
              title: Text('Ver GIF',
                  style: TextStyle(
                      color: opts.gifs.isNotEmpty
                          ? t.textPrimary
                          : t.textQuaternary)),
              enabled: opts.gifs.isNotEmpty,
              onTap: opts.gifs.isNotEmpty
                  ? () {
                      Navigator.pop(ctx);
                      _showMedia(opts.gifs, "GIFs");
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(Icons.library_books,
                  color: opts.references.isNotEmpty
                      ? t.textPrimary
                      : t.textQuaternary),
              title: Text('Ver Referências Cruzadas',
                  style: TextStyle(
                      color: opts.references.isNotEmpty
                          ? t.textPrimary
                          : t.textQuaternary)),
              enabled: opts.references.isNotEmpty,
              onTap: opts.references.isNotEmpty
                  ? () {
                      Navigator.pop(ctx);
                      _showReferences(opts.references);
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(Icons.video_library,
                  color:
                      (opts.youtubeUrl != null && opts.youtubeUrl!.isNotEmpty)
                          ? t.textPrimary
                          : t.textQuaternary),
              title: Text('Ver Vídeo Explicativo',
                  style: TextStyle(
                      color: (opts.youtubeUrl != null &&
                              opts.youtubeUrl!.isNotEmpty)
                          ? t.textPrimary
                          : t.textQuaternary)),
              enabled: opts.youtubeUrl != null && opts.youtubeUrl!.isNotEmpty,
              onTap: (opts.youtubeUrl != null && opts.youtubeUrl!.isNotEmpty)
                  ? () {
                      Navigator.pop(ctx);
                      _showYoutubeDialog(opts.youtubeUrl!);
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(Icons.compare_arrows_rounded, color: t.textPrimary),
              title: Text('Comparar Versões',
                  style: TextStyle(color: t.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                VerseComparisonSheet.show(
                  context,
                  bookName: book.name,
                  chapter: chapterIndex + 1,
                  verse: verse.number,
                  primaryText: verse.text,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonalStudyOptions(Book book, int chapterIndex, Verse verse) {
    final key = "${book.name}_${chapterIndex}_${verse.number}";
    final t = AppTheme();
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text('BÍBLIA DE ESTUDO (${verse.number})',
                  style: GoogleFonts.cinzel(
                      fontSize: 16,
                      color: t.titleGold,
                      fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Cor de Destaque',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: t.textTertiary,
                      fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _colorButton(
                      key, null, Colors.transparent, Icons.format_color_reset),
                  _colorButton(key, 0xFFFDE047, const Color(0xFFFDE047)),
                  _colorButton(key, 0xFF86EFAC, const Color(0xFF86EFAC)),
                  _colorButton(key, 0xFF93C5FD, const Color(0xFF93C5FD)),
                  _colorButton(key, 0xFFF9A8D4, const Color(0xFFF9A8D4)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_note, color: t.textPrimary),
              title: Text('Minhas Anotações',
                  style: TextStyle(color: t.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _openPersonalNoteDialog(key, chapterIndex, verse);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveHighlightColor(String key, int? color) {
    var userData = DataService().userVerseData[key] ?? UserVerseData();
    userData = UserVerseData(
        highlightColor: color, personalNote: userData.personalNote);
    DataService().saveUserVerseData(key, userData);
    setState(() {});
  }

  void _openPersonalNoteDialog(String key, int chapterIndex, Verse verse) {
    var userData = DataService().userVerseData[key] ?? UserVerseData();
    TextEditingController ctrl =
        TextEditingController(text: userData.personalNote);
    final t = AppTheme();

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: t.surface,
              title: Text('Minha Anotação (${verse.number})',
                  style: GoogleFonts.cinzel(color: AppTheme.accent)),
              content: TextField(
                controller: ctrl,
                maxLines: 5,
                style: TextStyle(color: t.textPrimary),
                decoration: InputDecoration(
                  hintText: "Escreva suas anotações pessoais aqui...",
                  hintStyle: TextStyle(color: t.textQuaternary),
                  filled: true,
                  fillColor: t.cardBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancelar',
                        style: TextStyle(color: t.textTertiary))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black),
                  onPressed: () {
                    final newNote =
                        ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
                    userData = UserVerseData(
                        highlightColor: userData.highlightColor,
                        personalNote: newNote);
                    DataService().saveUserVerseData(key, userData);
                    setState(() {});
                    Navigator.pop(ctx);
                  },
                  child: const Text('Salvar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ));
  }

  Widget _colorButton(String key, int? colorValue, Color color,
      [IconData? icon]) {
    return GestureDetector(
      onTap: () {
        _saveHighlightColor(key, colorValue);
        Navigator.pop(context);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: icon != null ? Icon(icon, size: 20, color: Colors.white) : null,
      ),
    );
  }

  void _showComments(
      Book book, int chapterIndex, Verse verse, List<Comment> comments) {
    int selectedIndex = 0;
    final t = AppTheme();
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setState) {
              return AlertDialog(
                backgroundColor: t.surface,
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text(
                    'Comentários (${book.name} ${chapterIndex + 1}:${verse.number})',
                    style: GoogleFonts.cinzel(color: AppTheme.accent)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comments.length > 1) ...[
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            itemCount: comments.length,
                            itemBuilder: (c, i) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(comments[i].author,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                selected: selectedIndex == i,
                                onSelected: (val) {
                                  if (val) setState(() => selectedIndex = i);
                                },
                                selectedColor: AppTheme.accent,
                                backgroundColor: Colors.white10,
                                labelStyle: TextStyle(
                                    color: selectedIndex == i
                                        ? Colors.black
                                        : Colors.white70),
                              ),
                            ),
                          ),
                        ),
                        Divider(color: t.divider, height: 1),
                      ],
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (comments.length == 1)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(comments[0].author,
                                      style: TextStyle(
                                          color: AppTheme.accentLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                ),
                              Text(comments[selectedIndex].text,
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: t.textSecondary,
                                      height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar',
                          style: TextStyle(color: AppTheme.accent))),
                ],
              );
            }));
  }

  String _getDirectMediaUrl(String url) {
    if (url.contains('drive.google.com/file/d/')) {
      final idMatch = RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(url);
      if (idMatch != null && idMatch.groupCount >= 1) {
        return 'https://drive.google.com/uc?export=view&id=${idMatch.group(1)}';
      }
    }
    return url;
  }

  void _showMedia(List<String> urls, String title) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                      title: Text(title,
                          style: GoogleFonts.cinzel(color: AppTheme.accent)),
                      backgroundColor: Colors.black),
                  body: PageView.builder(
                    itemCount: urls.length,
                    itemBuilder: (ctx, i) => InteractiveViewer(
                        child: Image.network(_getDirectMediaUrl(urls[i]),
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppTheme.accent),
                                ),
                              );
                            },
                            errorBuilder: (c, e, s) => const Center(
                                child: Text("Erro ao carregar mídia.",
                                    style: TextStyle(color: Colors.red))))),
                  ),
                )));
  }

  void _showReferences(List<String> refs) {
    final safeRefs = refs
        .expand((e) => e.split(RegExp(r'[,;]')))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final t = AppTheme();

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: t.surface,
              title: Text('Referências Cruzadas',
                  style: GoogleFonts.cinzel(color: AppTheme.accent)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: safeRefs.length,
                  itemBuilder: (c, i) => ListTile(
                    title: Text(safeRefs[i],
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            decoration: TextDecoration.underline)),
                    onTap: () => _fetchAndShowReferenceText(safeRefs[i]),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fechar',
                        style: TextStyle(color: AppTheme.accent))),
              ],
            ));
  }

  Future<void> _fetchAndShowReferenceText(String ref) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final safeRef = Uri.encodeComponent(ref);
      final response = await http
          .get(Uri.parse('https://bible-api.com/$safeRef?translation=almeida'));
      if (mounted) Navigator.pop(context);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          final t = AppTheme();
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    backgroundColor: t.surface,
                    title: Text(data['reference'] ?? ref,
                        style: GoogleFonts.cinzel(color: AppTheme.accent)),
                    content: SingleChildScrollView(
                        child: Text(data['text'] ?? '',
                            style: TextStyle(
                                fontSize: 16, color: t.textSecondary))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Fechar',
                              style: TextStyle(color: AppTheme.accent))),
                    ],
                  ));
        }
      } else {
        throw Exception("Failed to load");
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        AppFeedback.showError(context,
            "Erro ao buscar referência. Verifique formato (ex: Genesis 1:1)");
      }
    }
  }

  void _showYoutubeDialog(String url) {
    String? videoId;
    if (url.contains('v=')) {
      videoId = url.split('v=')[1].split('&')[0];
    } else if (url.contains('youtu.be/')) {
      videoId = url.split('youtu.be/')[1].split('?')[0];
    }
    final thumbUrl =
        videoId != null ? "https://img.youtube.com/vi/$videoId/0.jpg" : "";
    final t = AppTheme();

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: t.surface,
              title: Text('Vídeo Explicativo',
                  style: GoogleFonts.cinzel(color: AppTheme.accent)),
              content: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _openYouTube(url);
                },
                child: videoId != null
                    ? Stack(alignment: Alignment.center, children: [
                        Image.network(thumbUrl, fit: BoxFit.cover),
                        const Icon(Icons.play_circle_fill,
                            size: 60, color: Colors.red),
                      ])
                    : Text("Tocar vídeo no YouTube",
                        style: TextStyle(color: t.textPrimary, fontSize: 16)),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar',
                        style: TextStyle(color: AppTheme.accent))),
              ],
            ));
  }

  void _openYouTube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted)
        AppFeedback.showError(context, 'Não foi possível abrir o link');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DataService().books.isEmpty)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final t = AppTheme();
    final loc = AppLocale();
    final book = DataService().books[currentBookIndex];
    final localChapter = book.chapters[currentChapterIndex];
    final chapter = _apiChapter ?? localChapter;
    final books = DataService().books;
    final bvs = BibleVersionService();

    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        decoration: BoxDecoration(
            gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.2,
          colors: [t.surface, t.bg],
        )),
        child: SafeArea(
          child: Column(
            children: [
              // ── App Title ──
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  loc.tr_appTitle,
                  style: GoogleFonts.cinzel(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: t.titleGold),
                ),
              ),

              // ── Top Nav (Book + Chapter) ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: t.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: currentBookIndex,
                            isExpanded: true,
                            dropdownColor: t.surface,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AppTheme.accent),
                            style: GoogleFonts.inter(
                                fontSize: 16, color: t.textPrimary),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  currentBookIndex = val;
                                  currentChapterIndex = 0;
                                });
                                _apiChapter = null;
                                _tryFetchApiChapter();
                                _refreshAudioIfMissing();
                              }
                            },
                            items: List.generate(books.length, (idx) {
                              return DropdownMenuItem(
                                  value: idx, child: Text(books[idx].name));
                            }),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: t.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: currentChapterIndex,
                            isExpanded: true,
                            dropdownColor: t.surface,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AppTheme.accent),
                            style: GoogleFonts.inter(
                                fontSize: 16, color: t.textPrimary),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  currentChapterIndex = val;
                                });
                                _apiChapter = null;
                                _tryFetchApiChapter();
                                _refreshAudioIfMissing();
                              }
                            },
                            items: List.generate(book.chapters.length, (idx) {
                              return DropdownMenuItem(
                                  value: idx,
                                  child: Text('${loc.tr_chapter} ${idx + 1}'));
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Chapter Title ──
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Column(
                  children: [
                    Text(
                      '${book.name} ${currentChapterIndex + 1}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    // Bible version badge — tappable to change version
                    GestureDetector(
                      onTap: () => _showQuickVersionPicker(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bvs.primaryVersion.shortName,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.expand_more, size: 14, color: AppTheme.accent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(color: t.divider),

              // ── Selection Toolbar ──
              if (_isSelecting)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: AppTheme.accent.withOpacity(0.1),
                  child: Row(
                    children: [
                      Text('${_selectedVerses.length} selecionados',
                          style: GoogleFonts.inter(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const Spacer(),
                      IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          color: AppTheme.accent,
                          onPressed: _copySelected,
                          tooltip: 'Copiar'),
                      IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          color: AppTheme.accent,
                          onPressed: _shareSelected,
                          tooltip: 'Compartilhar'),
                      // ── Favorite ──
                      Builder(builder: (ctx) {
                        final book = DataService().books[currentBookIndex];
                        final allFav = _selectedVerses.every((vn) {
                          final k = '${book.name}_${currentChapterIndex}_$vn';
                          return DataService().userVerseData[k]?.isFavorite ?? false;
                        });
                        return IconButton(
                          icon: Icon(
                            allFav ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: allFav ? Colors.redAccent : AppTheme.accent,
                          ),
                          onPressed: _toggleFavoriteSelected,
                          tooltip: allFav ? 'Remover favorito' : 'Favoritar',
                        );
                      }),
                      // ── Note (single verse only) ──
                      if (_selectedVerses.length == 1)
                        IconButton(
                            icon: const Icon(Icons.note_add, size: 20),
                            color: AppTheme.accent,
                            onPressed: _addNoteToSelectedVerses,
                            tooltip: 'Adicionar anotação'),
                      IconButton(
                          icon: Icon(
                              _showColorPalette
                                  ? Icons.palette
                                  : Icons.palette_outlined,
                              size: 20),
                          color: AppTheme.accent,
                          onPressed: () => setState(
                              () => _showColorPalette = !_showColorPalette),
                          tooltip: 'Destacar'),
                      IconButton(
                          icon: const Icon(Icons.select_all, size: 20),
                          color: AppTheme.accent,
                          onPressed: _selectAllVerses,
                          tooltip: 'Selecionar todos'),
                      IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: t.textTertiary,
                          onPressed: _clearSelection),
                    ],
                  ),
                ),
              if (_showColorPalette)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: AppTheme.accent.withOpacity(0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _selectionColorBtn(
                          null, Colors.transparent, Icons.format_color_reset),
                      _selectionColorBtn(0xFFFDE047, const Color(0xFFFDE047)),
                      _selectionColorBtn(0xFF86EFAC, const Color(0xFF86EFAC)),
                      _selectionColorBtn(0xFF93C5FD, const Color(0xFF93C5FD)),
                      _selectionColorBtn(0xFFF9A8D4, const Color(0xFFF9A8D4)),
                    ],
                  ),
                ),

              // ── Audio/Podcast icons row (TOP) ──
              Builder(builder: (_) {
                final chapterAudioUrl = DataService()
                    .getChapterAudio(book.name, currentChapterIndex);
                final hasPodcasts = DataService().podcasts.isNotEmpty;
                if (chapterAudioUrl == null && !hasPodcasts)
                  return const SizedBox.shrink();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Spacer(),
                          if (chapterAudioUrl != null)
                            _AudioIconButton(
                              icon: Icons.headphones_rounded,
                              label: 'Audio do cap.',
                              color: AppTheme.accent,
                              isActive:
                                  widget.isGlobalAudioPlaying && !_showPodcasts,
                              onTap: () {
                                if (widget.isGlobalAudioPlaying &&
                                    !_showPodcasts) {
                                  widget.onStopAudio?.call();
                                } else {
                                  widget.onPlayAudio?.call(
                                    url: chapterAudioUrl,
                                    title:
                                        '${book.name} ${currentChapterIndex + 1}',
                                    subtitle: 'Audio do capitulo',
                                  );
                                }
                                setState(() => _showPodcasts = false);
                              },
                            ),
                          if (chapterAudioUrl != null && hasPodcasts)
                            const SizedBox(width: 10),
                          if (hasPodcasts)
                            _AudioIconButton(
                              icon: Icons.podcasts_rounded,
                              label: 'Podcasts',
                              color: const Color(0xFF8B5CF6),
                              isActive: _showPodcasts,
                              onTap: () => setState(() {
                                _showPodcasts = !_showPodcasts;
                              }),
                            ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    // ── Podcast list ──
                    if (_showPodcasts && DataService().podcasts.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: DataService().podcasts.length,
                          itemBuilder: (ctx, i) {
                            final p = DataService().podcasts[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.play_circle_fill,
                                  color: Color(0xFF8B5CF6), size: 28),
                              title: Text(p['title'] ?? '',
                                  style: GoogleFonts.inter(
                                      color: t.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(p['description'] ?? '',
                                  style: GoogleFonts.inter(
                                      color: t.textTertiary, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              onTap: () {
                                widget.onPlayAudio?.call(
                                  url: p['url'] ?? '',
                                  title: p['title'] ?? 'Podcast',
                                  subtitle: p['description'] ?? '',
                                  isPodcast: true,
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              }),

              // ── Verses ──
              Expanded(
                child: _apiLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.accent))
                    : ListView(
                        padding: const EdgeInsets.all(20.0),
                        children: [
                          // Back to search button
                          if (_fromSearch && _backToSearch != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextButton.icon(
                                onPressed: _backToSearch,
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: Text(loc.tr_backToSearch,
                                    style: const TextStyle(fontSize: 13)),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.accent),
                              ),
                            ),

                          ...chapter.map((verse) {
                            final key =
                                "${book.name}_${currentChapterIndex}_${verse.number}";
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: VerseCard(
                                verseKey: key,
                                verse: verse,
                                isHighlightedFromSearch:
                                    _highlightVerseNumber == verse.number,
                                isSelected:
                                    _selectedVerses.contains(verse.number),
                                onTap: () =>
                                    _toggleVerseSelection(verse.number),
                                onShowWordMeaning: _showWordMeaning,
                                onOptionsTap: () => _showVerseOptions(
                                    book, currentChapterIndex, verse),
                                onLongPress: () => _isSelecting
                                    ? _toggleVerseSelection(verse.number)
                                    : _showPersonalStudyOptions(
                                        book, currentChapterIndex, verse),
                                onCompare: () {
                                  VerseComparisonSheet.show(
                                    context,
                                    bookName: book.name,
                                    chapter: currentChapterIndex + 1,
                                    verse: verse.number,
                                    primaryText: verse.text,
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ),
              ),

              // ── Bottom Nav ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.divider)),
                  color: t.appBar,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed:
                          (currentBookIndex == 0 && currentChapterIndex == 0)
                              ? null
                              : _prevChapter,
                      icon: const Icon(Icons.chevron_left),
                      label: Text(loc.tr_previous,
                          style: const TextStyle(fontSize: 14)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          disabledForegroundColor: t.textQuaternary),
                    ),
                    Text(
                      '${book.abbrev} ${currentChapterIndex + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: t.textTertiary,
                          fontWeight: FontWeight.w500),
                    ),
                    TextButton(
                      onPressed: (currentBookIndex == books.length - 1 &&
                              currentChapterIndex == book.chapters.length - 1)
                          ? null
                          : _nextChapter,
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          disabledForegroundColor: t.textQuaternary),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(loc.tr_next,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionColorBtn(int? colorValue, Color color, [IconData? icon]) {
    return GestureDetector(
      onTap: () => _highlightSelectedVerses(colorValue),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: icon != null ? Icon(icon, size: 20, color: Colors.white) : null,
      ),
    );
  }
}

// ─── Audio Icon Button ─────────────────────────────────────────────────────

class _AudioIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _AudioIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Verse Card ────────────────────────────────────────────────────────────

class VerseCard extends StatefulWidget {
  final String verseKey;
  final Verse verse;
  final Function(String, DictEntry) onShowWordMeaning;
  final VoidCallback onOptionsTap;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onCompare;
  final bool isHighlightedFromSearch;
  final bool isSelected;

  const VerseCard({
    super.key,
    required this.verseKey,
    required this.verse,
    required this.onShowWordMeaning,
    required this.onOptionsTap,
    required this.onLongPress,
    this.onTap,
    this.onCompare,
    this.isHighlightedFromSearch = false,
    this.isSelected = false,
  });

  @override
  State<VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<VerseCard> {
  bool isFlipped = false;

  List<TextSpan> _buildFrontSpans(String text) {
    final t = AppTheme();
    final regex = RegExp(r'([\w\u00C0-\u017F]+)|([^\w\u00C0-\u017F]+)');
    final parts = regex.allMatches(text);
    final dict = DataService().dictionary;

    return parts.map((match) {
      final part = match.group(0)!;
      final isWord = RegExp(r'^[\w\u00C0-\u017F]+$').hasMatch(part);

      if (isWord) {
        final cleanWord = part.toLowerCase();
        final hasMeaning = dict.containsKey(cleanWord);

        return TextSpan(
          text: part,
          style: GoogleFonts.lora(
            fontSize: 20 * t.fontSizeScale,
            color: hasMeaning ? AppTheme.accent : t.textPrimary,
            decoration:
                hasMeaning ? TextDecoration.underline : TextDecoration.none,
            decorationStyle: TextDecorationStyle.dashed,
          ),
          recognizer: hasMeaning
              ? (TapGestureRecognizer()
                ..onTap = () {
                  widget.onShowWordMeaning(part, dict[cleanWord]!);
                })
              : null,
        );
      } else {
        return TextSpan(
          text: part,
          style: GoogleFonts.lora(
              fontSize: 20 * t.fontSizeScale, color: t.textPrimary),
        );
      }
    }).toList();
  }

  List<TextSpan> _buildBackSpans(String text) {
    final t = AppTheme();
    final regex = RegExp(r'([\w\u00C0-\u017F]+)|([^\w\u00C0-\u017F]+)');
    final parts = regex.allMatches(text);
    final dict = DataService().dictionary;

    return parts.map((match) {
      final part = match.group(0)!;
      final isWord = RegExp(r'^[\w\u00C0-\u017F]+$').hasMatch(part);

      if (isWord) {
        final cleanWord = part.toLowerCase();
        final meaning = dict[cleanWord];

        if (meaning != null) {
          return TextSpan(
            text: meaning.meaning,
            style: GoogleFonts.lora(
              fontSize: 20 * t.fontSizeScale,
              color: AppTheme.accentLight,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          );
        } else {
          return TextSpan(
            text: part,
            style: GoogleFonts.lora(
                fontSize: 20 * t.fontSizeScale, color: t.textTertiary),
          );
        }
      } else {
        return TextSpan(
          text: part,
          style: GoogleFonts.lora(
              fontSize: 20 * t.fontSizeScale, color: t.textTertiary),
        );
      }
    }).toList();
  }

  Widget _buildCard(bool isBack) {
    final t = AppTheme();
    final userData = DataService().userVerseData[widget.verseKey];
    final hlColorValue = userData?.highlightColor;
    final hlColor = hlColorValue != null ? Color(hlColorValue) : null;
    final isLiteral = DataService().literalVerses.contains(widget.verseKey);

    Color bgColor;
    if (widget.isSelected) {
      bgColor = AppTheme.accent.withOpacity(0.12);
    } else if (widget.isHighlightedFromSearch) {
      bgColor = AppTheme.accent.withOpacity(0.08);
    } else if (hlColor != null) {
      bgColor = hlColor.withOpacity(0.15);
    } else if (isBack) {
      bgColor = t.cardBg;
    } else {
      bgColor = Colors.transparent;
    }

    return Container(
      key: ValueKey(isBack),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: widget.isSelected
            ? Border.all(color: AppTheme.accent.withOpacity(0.5), width: 2)
            : hlColor != null
                ? Border.all(color: hlColor.withOpacity(0.4), width: 1.5)
                : isBack
                    ? Border.all(color: AppTheme.accent.withOpacity(0.3))
                    : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.verse.number}  ',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent),
                        ),
                        ...isBack
                            ? _buildBackSpans(widget.verse.text)
                            : _buildFrontSpans(widget.verse.text),
                      ],
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.more_vert,
                          color: t.textQuaternary, size: 22),
                      onPressed: widget.onOptionsTap,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Opções',
                    ),
                    const SizedBox(height: 10),
                    IconButton(
                      icon: Icon(
                        isFlipped ? Icons.flip_to_front : Icons.flip_to_back,
                        color: isLiteral
                            ? const Color(0xFF22C55E)
                            : (isFlipped ? AppTheme.accent : t.textQuaternary),
                        size: 20,
                      ),
                      onPressed: () => _toggleInterpretation(isLiteral),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: isLiteral
                          ? 'Verso literal'
                          : (isFlipped ? 'Ver original' : 'Interpretar'),
                    ),
                    const SizedBox(height: 10),
                    IconButton(
                      icon: Icon(Icons.compare_arrows,
                          color: t.textQuaternary, size: 20),
                      onPressed: widget.onCompare,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Comparar',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isLiteral)
            Container(
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('✓ Verso literal',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF22C55E),
                      fontWeight: FontWeight.w600)),
            ),
          if (userData?.personalNote != null &&
              userData!.personalNote!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(
                  top: 4, bottom: 12, left: 12, right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                      left: BorderSide(color: AppTheme.accent, width: 2))),
              child: Text(userData.personalNote!,
                  style: GoogleFonts.lora(
                      fontSize: 15,
                      color: t.textSecondary,
                      fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  void _toggleInterpretation(bool isLiteral) {
    if (isLiteral) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Este verso é literal — não possui interpretação profética.'),
          backgroundColor: const Color(0xFF22C55E),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => isFlipped = !isFlipped);
  }

  @override
  Widget build(BuildContext context) {
    final isLiteral = DataService().literalVerses.contains(widget.verseKey);
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: () => _toggleInterpretation(isLiteral),
      onLongPress: widget.onLongPress,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        layoutBuilder: (currentChild, previousChildren) => Stack(children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ]),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotate = Tween(begin: math.pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, child) {
              final isUnder = (ValueKey(isFlipped) != child?.key);
              var value = rotate.value;
              if (isUnder) value += math.pi;
              return Transform(
                transform: Matrix4.rotationX(value),
                alignment: Alignment.center,
                child: (value <= (math.pi / 2) || value >= (math.pi * 1.5))
                    ? child
                    : const SizedBox.shrink(),
              );
            },
          );
        },
        child: _buildCard(isFlipped),
      ),
    );
  }
}
