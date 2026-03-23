import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'services.dart';
import 'admin_page.dart';
import 'auth_service.dart';
import 'user_management_page.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({Key? key}) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  int currentBookIndex = 0;
  int currentChapterIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  void _navAdmin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage()))
      .then((_) => setState(() {}));
  }

  void _showWordMeaning(String word, DictEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(word.toUpperCase(), style: GoogleFonts.cinzel(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
            if (entry.originalWord != null && entry.originalWord!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(entry.originalWord!, style: GoogleFonts.lora(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 16)),
              ),
          ],
        ),
        content: Text(entry.meaning, style: const TextStyle(fontSize: 17, color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: Color(0xFFF59E0B))),
          ),
        ],
      )
    );
  }

  void _prevChapter() {
    if (currentChapterIndex > 0) {
      currentChapterIndex--;
    } else if (currentBookIndex > 0) {
      currentBookIndex--;
      currentChapterIndex = DataService().books[currentBookIndex].chapters.length - 1;
    }
    setState(() {});
  }

  void _nextChapter() {
    final maxChap = DataService().books[currentBookIndex].chapters.length - 1;
    if (currentChapterIndex < maxChap) {
      currentChapterIndex++;
    } else if (currentBookIndex < DataService().books.length - 1) {
      currentBookIndex++;
      currentChapterIndex = 0;
    }
    setState(() {});
  }

  void _showVerseOptions(Book book, int chapterIndex, Verse verse) {
    final key = "${book.name}_${chapterIndex}_${verse.number}";
    final opts = DataService().verseOptions[key] ?? VerseOptions();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Opções: ${book.name} ${chapterIndex+1}:${verse.number}',
                style: GoogleFonts.cinzel(fontSize: 18, color: const Color(0xFFFCD34D), fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: Icon(Icons.comment, color: opts.comments.isNotEmpty ? Colors.white : Colors.white30),
              title: Text('Ver Comentários', style: TextStyle(color: opts.comments.isNotEmpty ? Colors.white : Colors.white30)),
              enabled: opts.comments.isNotEmpty,
              onTap: opts.comments.isNotEmpty ? () { Navigator.pop(ctx); _showComments(book, chapterIndex, verse, opts.comments); } : null,
            ),
            ListTile(
              leading: Icon(Icons.image, color: opts.images.isNotEmpty ? Colors.white : Colors.white30),
              title: Text('Ver Imagem', style: TextStyle(color: opts.images.isNotEmpty ? Colors.white : Colors.white30)),
              enabled: opts.images.isNotEmpty,
              onTap: opts.images.isNotEmpty ? () { Navigator.pop(ctx); _showMedia(opts.images, "Imagens"); } : null,
            ),
            ListTile(
              leading: Icon(Icons.gif, color: opts.gifs.isNotEmpty ? Colors.white : Colors.white30),
              title: Text('Ver GIF', style: TextStyle(color: opts.gifs.isNotEmpty ? Colors.white : Colors.white30)),
              enabled: opts.gifs.isNotEmpty,
              onTap: opts.gifs.isNotEmpty ? () { Navigator.pop(ctx); _showMedia(opts.gifs, "GIFs"); } : null,
            ),
            ListTile(
              leading: Icon(Icons.library_books, color: opts.references.isNotEmpty ? Colors.white : Colors.white30),
              title: Text('Ver Referências Cruzadas', style: TextStyle(color: opts.references.isNotEmpty ? Colors.white : Colors.white30)),
              enabled: opts.references.isNotEmpty,
              onTap: opts.references.isNotEmpty ? () { Navigator.pop(ctx); _showReferences(opts.references); } : null,
            ),
            ListTile(
              leading: Icon(Icons.video_library, color: (opts.youtubeUrl != null && opts.youtubeUrl!.isNotEmpty) ? Colors.white : Colors.white30),
              title: Text('Ver Vídeo Explicativo', style: TextStyle(color: (opts.youtubeUrl != null && opts.youtubeUrl!.isNotEmpty) ? Colors.white : Colors.white30)),
              enabled: opts.youtubeUrl != null && opts.youtubeUrl!.isNotEmpty,
              onTap: (opts.youtubeUrl != null && opts.youtubeUrl!.isNotEmpty) ? () { Navigator.pop(ctx); _showYoutubeDialog(opts.youtubeUrl!); } : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonalStudyOptions(Book book, int chapterIndex, Verse verse) {
    final key = "${book.name}_${chapterIndex}_${verse.number}";
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text('BÍBLIA DE ESTUDO (${verse.number})', style: GoogleFonts.cinzel(fontSize: 16, color: const Color(0xFFFCD34D), fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Cor de Destaque', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _colorButton(key, null, Colors.transparent, Icons.format_color_reset),
                  _colorButton(key, 0xFFFDE047, const Color(0xFFFDE047)), // Yellow
                  _colorButton(key, 0xFF86EFAC, const Color(0xFF86EFAC)), // Green
                  _colorButton(key, 0xFF93C5FD, const Color(0xFF93C5FD)), // Blue
                  _colorButton(key, 0xFFF9A8D4, const Color(0xFFF9A8D4)), // Pink
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.white),
              title: const Text('Minhas Anotações', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _openPersonalNoteDialog(key, chapterIndex, verse); },
            ),
          ],
        ),
      ),
    );
  }

  void _saveHighlightColor(String key, int? color) {
    var userData = DataService().userVerseData[key] ?? UserVerseData();
    userData = UserVerseData(highlightColor: color, personalNote: userData.personalNote);
    DataService().saveUserVerseData(key, userData);
    setState(() {});
  }

  void _openPersonalNoteDialog(String key, int chapterIndex, Verse verse) {
    var userData = DataService().userVerseData[key] ?? UserVerseData();
    TextEditingController ctrl = TextEditingController(text: userData.personalNote);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Minha Anotação (${verse.number})', style: GoogleFonts.cinzel(color: const Color(0xFFF59E0B))),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Escreva suas anotações pessoais aqui...",
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black),
            onPressed: () {
              final newNote = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
              userData = UserVerseData(highlightColor: userData.highlightColor, personalNote: newNote);
              DataService().saveUserVerseData(key, userData);
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  Widget _colorButton(String key, int? colorValue, Color color, [IconData? icon]) {
    return GestureDetector(
      onTap: () {
        _saveHighlightColor(key, colorValue);
        Navigator.pop(context);
      },
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: icon != null ? Icon(icon, size: 20, color: Colors.white) : null,
      ),
    );
  }

  void _showComments(Book book, int chapterIndex, Verse verse, List<Comment> comments) {
    int selectedIndex = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Comentários (${book.name} ${chapterIndex+1}:${verse.number})', style: GoogleFonts.cinzel(color: const Color(0xFFF59E0B))),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: comments.length,
                        itemBuilder: (c, i) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(comments[i].author, style: const TextStyle(fontWeight: FontWeight.bold)),
                            selected: selectedIndex == i,
                            onSelected: (val) {
                              if (val) setState(() => selectedIndex = i);
                            },
                            selectedColor: const Color(0xFFF59E0B),
                            backgroundColor: Colors.white10,
                            labelStyle: TextStyle(color: selectedIndex == i ? Colors.black : Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
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
                              child: Text(comments[0].author, style: const TextStyle(color: Color(0xFFFCD34D), fontWeight: FontWeight.bold, fontSize: 18)),
                            ),
                          Text(comments[selectedIndex].text, style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar', style: TextStyle(color: Color(0xFFF59E0B)))),
            ],
          );
        }
      )
    );
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title, style: GoogleFonts.cinzel(color: const Color(0xFFF59E0B))), backgroundColor: Colors.black),
      body: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (ctx, i) => InteractiveViewer(
          child: Image.network(
            _getDirectMediaUrl(urls[i]),
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                ),
              );
            },
            errorBuilder: (c, e, s) => const Center(child: Text("Erro ao carregar mídia. Verifique o link.", style: TextStyle(color: Colors.red)))
          )
        ),
      ),
    )));
  }

  void _showReferences(List<String> refs) {
    final safeRefs = refs.expand((e) => e.split(RegExp(r'[,;]'))).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Referências Cruzadas', style: GoogleFonts.cinzel(color: const Color(0xFFF59E0B))),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: safeRefs.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(safeRefs[i], style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
              onTap: () => _fetchAndShowReferenceText(safeRefs[i]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar', style: TextStyle(color: Color(0xFFF59E0B)))),
        ],
      )
    );
  }

  Future<void> _fetchAndShowReferenceText(String ref) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final safeRef = Uri.encodeComponent(ref);
      final response = await http.get(Uri.parse('https://bible-api.com/$safeRef?translation=almeida'));
      if (mounted) Navigator.pop(context); // close loading
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(data['reference'] ?? ref, style: GoogleFonts.cinzel(color: const Color(0xFFF59E0B))),
              content: SingleChildScrollView(child: Text(data['text'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.white70))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar', style: TextStyle(color: Color(0xFFF59E0B)))),
              ],
            )
          );
        }
      } else {
        throw Exception("Failed to load");
      }
    } catch (_) {
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao buscar referência. Verifique formato (ex: Genesis 1:1)")));
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
    final thumbUrl = videoId != null ? "https://img.youtube.com/vi/$videoId/0.jpg" : "";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Vídeo Explicativo', style: GoogleFonts.cinzel(color: const Color(0xFFF59E0B))),
        content: GestureDetector(
          onTap: () {
            Navigator.pop(ctx);
            _openYouTube(url);
          },
          child: videoId != null 
            ? Stack(
                alignment: Alignment.center,
                children: [
                   Image.network(thumbUrl, fit: BoxFit.cover),
                   const Icon(Icons.play_circle_fill, size: 60, color: Colors.red),
                ])
            : const Text("Tocar vídeo no YouTube", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Color(0xFFF59E0B)))),
        ],
      )
    );
  }

  void _openYouTube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if(DataService().books.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final book = DataService().books[currentBookIndex];
    final chapter = book.chapters[currentChapterIndex];
    final books = DataService().books;

    final isAdmin = AuthService().currentUser?.isAdmin ?? false;
    final isMaster = AuthService().currentUser?.isMaster ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('A Revelação', style: GoogleFonts.cinzel(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFFCD34D))),
        actions: [
          if (isMaster)
            IconButton(
              icon: const Icon(Icons.people, color: Color(0xFFF59E0B)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementPage())),
              tooltip: 'Gerenciar Usuários',
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFFF59E0B)),
              onPressed: _navAdmin,
              tooltip: 'Admin',
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () => AuthService().logout(),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0B0F19),
            ],
          )
        ),
        child: Column(
          children: [
            // Top Nav
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white.withOpacity(0.02),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: DropdownButton<int>(
                          value: currentBookIndex,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFF59E0B)),
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                currentBookIndex = val;
                                currentChapterIndex = 0;
                              });
                            }
                          },
                          items: List.generate(books.length, (idx) {
                            return DropdownMenuItem(
                              value: idx,
                              child: Text(books[idx].name),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: DropdownButton<int>(
                          value: currentChapterIndex,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFF59E0B)),
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                currentChapterIndex = val;
                              });
                            }
                          },
                          items: List.generate(book.chapters.length, (idx) {
                            return DropdownMenuItem(
                              value: idx,
                              child: Text('Capítulo ${idx + 1}'),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Reader Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  Text(
                    '${book.name} ${currentChapterIndex + 1}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),
                  
                  ...chapter.map((verse) {
                    final key = "${book.name}_${currentChapterIndex}_${verse.number}";
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: VerseCard(
                        verseKey: key,
                        verse: verse,
                        onShowWordMeaning: _showWordMeaning,
                        onOptionsTap: () => _showVerseOptions(book, currentChapterIndex, verse),
                        onLongPress: () => _showPersonalStudyOptions(book, currentChapterIndex, verse),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            
            // Bottom Nav
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10)),
                color: Color(0x990F172A),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: (currentBookIndex == 0 && currentChapterIndex == 0) ? null : _prevChapter,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Anterior', style: TextStyle(fontSize: 14)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B), disabledForegroundColor: Colors.white24),
                  ),
                  Text(
                    '${book.abbrev} ${currentChapterIndex + 1}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500),
                  ),
                  TextButton(
                    onPressed: (currentBookIndex == books.length - 1 && currentChapterIndex == book.chapters.length - 1) ? null : _nextChapter,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B), disabledForegroundColor: Colors.white24),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Próximo', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VerseCard extends StatefulWidget {
  final String verseKey;
  final Verse verse;
  final Function(String, DictEntry) onShowWordMeaning;
  final VoidCallback onOptionsTap;
  final VoidCallback onLongPress;

  const VerseCard({
    Key? key,
    required this.verseKey,
    required this.verse,
    required this.onShowWordMeaning,
    required this.onOptionsTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  State<VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<VerseCard> {
  bool isFlipped = false;

  List<TextSpan> _buildFrontSpans(String text) {
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
            fontSize: 20,
            color: hasMeaning ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            decoration: hasMeaning ? TextDecoration.underline : TextDecoration.none,
            decorationStyle: TextDecorationStyle.dashed,
          ),
          recognizer: hasMeaning ? (TapGestureRecognizer()..onTap = () {
             widget.onShowWordMeaning(part, dict[cleanWord]!);
          }) : null,
        );
      } else {
        return TextSpan(
          text: part,
          style: GoogleFonts.lora(fontSize: 20, color: const Color(0xFFE2E8F0)),
        );
      }
    }).toList();
  }

  List<TextSpan> _buildBackSpans(String text) {
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
              fontSize: 20,
              color: const Color(0xFFFCD34D),
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          );
        } else {
          return TextSpan(
            text: part,
            style: GoogleFonts.lora(fontSize: 20, color: const Color(0xFF94A3B8)),
          );
        }
      } else {
        return TextSpan(
          text: part,
          style: GoogleFonts.lora(fontSize: 20, color: const Color(0xFF94A3B8)),
        );
      }
    }).toList();
  }

  Widget _buildCard(bool isBack) {
    final userData = DataService().userVerseData[widget.verseKey];
    final hlColorValue = userData?.highlightColor;
    final hlColor = hlColorValue != null ? Color(hlColorValue) : null;

    return Container(
      key: ValueKey(isBack),
      width: double.infinity,
      decoration: BoxDecoration(
        color: hlColor != null ? hlColor.withOpacity(0.15) : (isBack ? Colors.white.withOpacity(0.05) : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: hlColor != null ? Border.all(color: hlColor.withOpacity(0.4), width: 1.5) : (isBack ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)) : null),
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
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                        ),
                        ...isBack ? _buildBackSpans(widget.verse.text) : _buildFrontSpans(widget.verse.text),
                      ],
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  onPressed: widget.onOptionsTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Opções Adicionais',
                ),
              ],
            ),
          ),
          if (userData?.personalNote != null && userData!.personalNote!.isNotEmpty)
             Container(
               margin: const EdgeInsets.only(top: 4, bottom: 12, left: 12, right: 12),
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.05),
                 borderRadius: BorderRadius.circular(8),
                 border: const Border(left: BorderSide(color: Color(0xFFF59E0B), width: 2))
               ),
               child: Text(userData!.personalNote!, style: GoogleFonts.lora(fontSize: 15, color: Colors.white70, fontStyle: FontStyle.italic)),
             )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => setState(() => isFlipped = !isFlipped),
      onLongPress: widget.onLongPress,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ]
        ),
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
                child: (value <= (math.pi / 2) || value >= (math.pi * 1.5)) ? child : const SizedBox.shrink(),
              );
            },
          );
        },
        child: _buildCard(isFlipped),
      ),
    );
  }
}
