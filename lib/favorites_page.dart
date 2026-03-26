import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'services.dart';
import 'app_theme.dart';

class FavoritesPage extends StatefulWidget {
  final void Function(int bookIndex, int chapterIndex, int verseNumber)?
      onNavigateToVerse;

  const FavoritesPage({super.key, this.onNavigateToVerse});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<_FavEntry> _favorites = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ds = DataService();
    final favs = <_FavEntry>[];
    ds.userVerseData.forEach((key, data) {
      if (data.isFavorite) {
        final parts = key.split('_');
        if (parts.length >= 3) {
          final bookName = parts[0];
          final chapterIndex = int.tryParse(parts[1]) ?? 0;
          final verseNumber = int.tryParse(parts[2]) ?? 0;
          final bookIndex = ds.books.indexWhere((b) => b.name == bookName);
          if (bookIndex >= 0 &&
              chapterIndex < ds.books[bookIndex].chapters.length) {
            final chapter = ds.books[bookIndex].chapters[chapterIndex];
            final verse =
                chapter.where((v) => v.number == verseNumber).firstOrNull;
            if (verse != null) {
              favs.add(_FavEntry(
                bookName: bookName,
                bookIndex: bookIndex,
                chapterIndex: chapterIndex,
                verse: verse,
                key: key,
                highlightColor: data.highlightColor,
              ));
            }
          }
        }
      }
    });
    favs.sort((a, b) {
      final cmp = a.bookIndex.compareTo(b.bookIndex);
      if (cmp != 0) return cmp;
      final cmp2 = a.chapterIndex.compareTo(b.chapterIndex);
      if (cmp2 != 0) return cmp2;
      return a.verse.number.compareTo(b.verse.number);
    });
    setState(() => _favorites = favs);
  }

  void _removeFavorite(_FavEntry fav) {
    var data = DataService().userVerseData[fav.key] ?? UserVerseData();
    data = data.copyWith(isFavorite: false);
    DataService().saveUserVerseData(fav.key, data);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Versículos Favoritos',
            style: GoogleFonts.cinzel(
                color: t.titleGold, fontSize: 18)),
        backgroundColor: t.appBar,
        foregroundColor: t.textPrimary,
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
        child: _favorites.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_border,
                        size: 56, color: Colors.white12),
                    const SizedBox(height: 16),
                    Text('Nenhum versículo favoritado',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione versículos na Bíblia e\ntoque em Favorito para salvar aqui.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: Colors.white24, fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _favorites.length,
                itemBuilder: (ctx, i) {
                  final fav = _favorites[i];
                  final hlColor = fav.highlightColor != null
                      ? Color(fav.highlightColor!)
                      : null;
                  return Dismissible(
                    key: ValueKey(fav.key),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                    onDismissed: (_) => _removeFavorite(fav),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: hlColor != null
                            ? hlColor.withOpacity(0.08)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hlColor != null
                              ? hlColor.withOpacity(0.3)
                              : Colors.white10,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bookmark,
                              color: Color(0xFFF59E0B), size: 22),
                        ),
                        title: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${fav.bookName} ${fav.chapterIndex + 1}:${fav.verse.number}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            fav.verse.text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lora(
                                color: Colors.white60,
                                fontSize: 14,
                                height: 1.5),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: Colors.white30, size: 20),
                          color: const Color(0xFF1E293B),
                          onSelected: (val) {
                            if (val == 'go') {
                              widget.onNavigateToVerse?.call(
                                  fav.bookIndex,
                                  fav.chapterIndex,
                                  fav.verse.number);
                              Navigator.pop(context);
                            } else if (val == 'remove') {
                              _removeFavorite(fav);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'go',
                              child: Row(
                                children: [
                                  Icon(Icons.menu_book,
                                      color: Color(0xFFF59E0B), size: 18),
                                  SizedBox(width: 10),
                                  Text('Ir para o versículo',
                                      style:
                                          TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.bookmark_remove,
                                      color: Colors.redAccent, size: 18),
                                  SizedBox(width: 10),
                                  Text('Remover favorito',
                                      style: TextStyle(
                                          color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          widget.onNavigateToVerse?.call(fav.bookIndex,
                              fav.chapterIndex, fav.verse.number);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _FavEntry {
  final String bookName;
  final int bookIndex;
  final int chapterIndex;
  final Verse verse;
  final String key;
  final int? highlightColor;

  _FavEntry({
    required this.bookName,
    required this.bookIndex,
    required this.chapterIndex,
    required this.verse,
    required this.key,
    this.highlightColor,
  });
}
