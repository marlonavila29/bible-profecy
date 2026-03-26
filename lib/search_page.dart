import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'services.dart';
import 'app_theme.dart';

class SearchPage extends StatefulWidget {
  /// Callback when a search result is tapped: (bookIndex, chapterIndex, verseNumber)
  final void Function(int bookIndex, int chapterIndex, int verseNumber)? onResultTap;

  const SearchPage({super.key, this.onResultTap});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchResult {
  final int bookIndex;
  final Book book;
  final int chapterIndex;
  final Verse verse;
  _SearchResult(this.bookIndex, this.book, this.chapterIndex, this.verse);
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  List<_SearchResult> _results = [];
  bool _searched = false;
  bool _matchCase = false;
  bool _wholeWord = false;
  String _selectedBookFilter = 'Todos';

  void _search(String query) {
    final raw = query.trim();
    if (raw.isEmpty) return;

    final results = <_SearchResult>[];
    final books = DataService().books;
    for (int bi = 0; bi < books.length; bi++) {
      final book = books[bi];
      if (_selectedBookFilter != 'Todos' && book.name != _selectedBookFilter) {
        continue;
      }
      for (int ci = 0; ci < book.chapters.length; ci++) {
        for (final verse in book.chapters[ci]) {
          if (_matches(verse.text, raw)) {
            results.add(_SearchResult(bi, book, ci, verse));
          }
        }
      }
    }
    setState(() {
      _results = results;
      _searched = true;
    });
  }

  bool _matches(String text, String query) {
    final t = _matchCase ? text : text.toLowerCase();
    final q = _matchCase ? query : query.toLowerCase();
    if (_wholeWord) {
      try {
        final pattern = RegExp(r'\b' + RegExp.escape(q) + r'\b',
            caseSensitive: _matchCase);
        return pattern.hasMatch(text);
      } catch (_) {
        return t.contains(q);
      }
    }
    return t.contains(q);
  }

  List<TextSpan> _buildHighlightSpans(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }
    final spans = <TextSpan>[];
    final t = _matchCase ? text : text.toLowerCase();
    final q = _matchCase ? query : query.toLowerCase();

    final List<(int, int)> matches = [];
    if (_wholeWord) {
      try {
        final pattern = RegExp(r'\b' + RegExp.escape(q) + r'\b',
            caseSensitive: _matchCase);
        for (final m in pattern.allMatches(text)) {
          matches.add((m.start, m.end));
        }
      } catch (_) {}
    } else {
      int start = 0;
      while (true) {
        final idx = t.indexOf(q, start);
        if (idx == -1) break;
        matches.add((idx, idx + q.length));
        start = idx + q.length;
      }
    }

    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    int cursor = 0;
    for (final (start, end) in matches) {
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: const TextStyle(
          color: Color(0xFFF59E0B),
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0x22F59E0B),
        ),
      ));
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final query = _ctrl.text.trim();
    final t = AppTheme();
    return Scaffold(
      appBar: AppBar(
        title: Text('Pesquisa',
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
        child: Column(
          children: [
            // ── Search bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.border),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        style: GoogleFonts.inter(
                            color: t.textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Buscar palavra nos livros…',
                          hintStyle: GoogleFonts.inter(
                              color: t.textQuaternary, fontSize: 15),
                          prefixIcon: Icon(Icons.search,
                              color: t.textQuaternary),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          suffixIcon: _ctrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close,
                                      color: t.textQuaternary, size: 18),
                                  onPressed: () {
                                    _ctrl.clear();
                                    setState(() {
                                      _results = [];
                                      _searched = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _search(_ctrl.text),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  const Color(0xFFF59E0B).withOpacity(0.3),
                              blurRadius: 10)
                        ],
                      ),
                      child: const Icon(Icons.search,
                          color: Color(0xFF0B0F19), size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search options (Cc / W / Filter) ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _SearchToggle(
                    label: 'Cc',
                    tooltip: 'Diferenciar maiúsculas',
                    active: _matchCase,
                    onTap: () {
                      setState(() => _matchCase = !_matchCase);
                      if (_searched) _search(_ctrl.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  _SearchToggle(
                    label: 'W',
                    tooltip: 'Palavra inteira',
                    active: _wholeWord,
                    onTap: () {
                      setState(() => _wholeWord = !_wholeWord);
                      if (_searched) _search(_ctrl.text);
                    },
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _selectedBookFilter == 'Todos'
                          ? t.cardBg
                          : t.accentOnBg.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedBookFilter == 'Todos'
                            ? t.border
                            : t.accentOnBg.withOpacity(0.4),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBookFilter,
                        dropdownColor: t.modalBg,
                        icon: Icon(Icons.keyboard_arrow_down,
                            size: 16,
                            color: _selectedBookFilter == 'Todos'
                                ? t.textQuaternary
                                : t.accentOnBg),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedBookFilter == 'Todos'
                              ? t.textSecondary
                              : t.accentOnBg,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedBookFilter = newValue);
                            if (_searched) _search(_ctrl.text);
                          }
                        },
                        items: ['Todos', 'Daniel', 'Apocalipse']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_searched)
                    Text(
                      '${_results.length} res.',
                      style: GoogleFonts.inter(
                          color: t.textQuaternary, fontSize: 13),
                    ),
                ],
              ),
            ),

            Divider(color: t.divider, height: 1),

            // ── Results list ──────────────────────────────────
            Expanded(
              child: !_searched
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 64, color: t.textMinimal),
                          const SizedBox(height: 16),
                          Text('Pesquise por palavras em',
                              style: GoogleFonts.inter(
                                  color: t.textQuaternary, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Daniel & Apocalipse',
                              style: GoogleFonts.cinzel(
                                  color: t.accentOnBg.withOpacity(0.6),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 56, color: t.textMinimal),
                              const SizedBox(height: 16),
                              Text('Nenhum resultado encontrado.',
                                  style: GoogleFonts.inter(
                                      color: t.textQuaternary,
                                      fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final r = _results[i];
                            return GestureDetector(
                              onTap: () => widget.onResultTap?.call(
                                  r.bookIndex,
                                  r.chapterIndex,
                                  r.verse.number),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: t.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: t.border),
                                  boxShadow: t.isDark ? null : [
                                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFF59E0B)
                                                          .withOpacity(0.4)),
                                            ),
                                            child: Text(
                                              '${r.book.name} ${r.chapterIndex + 1}:${r.verse.number}',
                                              style: GoogleFonts.inter(
                                                color:
                                                    const Color(0xFFF59E0B),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                      Icon(Icons.arrow_forward_ios,
                                          color: t.textQuaternary,
                                          size: 14),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text.rich(
                                    TextSpan(
                                      children: _buildHighlightSpans(
                                          r.verse.text, query),
                                      style: GoogleFonts.lora(
                                          color: t.textSecondary,
                                          fontSize: 15,
                                          height: 1.5),
                                    ),
                                  ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchToggle extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _SearchToggle({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? t.accentOnBg.withOpacity(0.2)
                : t.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? t.accentOnBg.withOpacity(0.6)
                  : t.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? t.accentOnBg : t.textQuaternary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
