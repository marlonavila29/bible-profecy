import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'services.dart';
import 'app_error.dart';
import 'app_theme.dart';

class NotesPage extends StatefulWidget {
  final void Function(int bookIndex, int chapterIndex, int verseNumber)?
      onNavigateToVerse;

  const NotesPage({super.key, this.onNavigateToVerse});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<_NoteEntry> _notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ds = DataService();
    final notes = <_NoteEntry>[];
    ds.userVerseData.forEach((key, data) {
      if (data.personalNote != null && data.personalNote!.isNotEmpty) {
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
              notes.add(_NoteEntry(
                bookName: bookName,
                bookIndex: bookIndex,
                chapterIndex: chapterIndex,
                verse: verse,
                key: key,
                note: data.personalNote!,
              ));
            }
          }
        }
      }
    });
    notes.sort((a, b) {
      final cmp = a.bookIndex.compareTo(b.bookIndex);
      if (cmp != 0) return cmp;
      final cmp2 = a.chapterIndex.compareTo(b.chapterIndex);
      if (cmp2 != 0) return cmp2;
      return a.verse.number.compareTo(b.verse.number);
    });
    setState(() => _notes = notes);
  }

  void _deleteNote(_NoteEntry entry) {
    var data = DataService().userVerseData[entry.key] ?? UserVerseData();
    data = UserVerseData(
        highlightColor: data.highlightColor,
        personalNote: null,
        isFavorite: data.isFavorite);
    DataService().saveUserVerseData(entry.key, data);
    _load();
    AppFeedback.showSuccess(context, 'Anotação apagada!');
  }

  void _editNote(_NoteEntry entry) {
    final ctrl = TextEditingController(text: entry.note);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          '${entry.bookName} ${entry.chapterIndex + 1}:${entry.verse.number}',
          style: GoogleFonts.cinzel(color: const Color(0xFFF59E0B)),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Escreva suas anotações pessoais aqui...',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteNote(entry);
            },
            child: const Text('Apagar',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black),
            onPressed: () {
              final newNote =
                  ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
              var data =
                  DataService().userVerseData[entry.key] ?? UserVerseData();
              data = UserVerseData(
                  highlightColor: data.highlightColor,
                  personalNote: newNote,
                  isFavorite: data.isFavorite);
              DataService().saveUserVerseData(entry.key, data);
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Salvar',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Minhas Anotações',
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
        child: _notes.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.note_alt_outlined,
                        size: 56, color: Colors.white12),
                    const SizedBox(height: 16),
                    Text('Nenhuma anotação registrada',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione versículos na Bíblia e\ntoque em Nota para anotar aqui.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: Colors.white24, fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _notes.length,
                itemBuilder: (ctx, i) {
                  final note = _notes[i];
                  return Dismissible(
                    key: ValueKey(note.key),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                    onDismissed: (_) => _deleteNote(note),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note,
                                  color: Color(0xFFF59E0B), size: 22),
                            ),
                            title: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${note.bookName} ${note.chapterIndex + 1}:${note.verse.number}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFF59E0B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white30, size: 20),
                              color: const Color(0xFF1E293B),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _editNote(note);
                                } else if (val == 'delete') {
                                  _deleteNote(note);
                                } else if (val == 'go') {
                                  widget.onNavigateToVerse?.call(
                                      note.bookIndex,
                                      note.chapterIndex,
                                      note.verse.number);
                                  Navigator.pop(context);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'go',
                                  child: Row(
                                    children: [
                                      Icon(Icons.menu_book,
                                          color: Color(0xFFF59E0B),
                                          size: 18),
                                      SizedBox(width: 10),
                                      Text('Ir para o versículo',
                                          style: TextStyle(
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit,
                                          color: Colors.white70,
                                          size: 18),
                                      SizedBox(width: 10),
                                      Text('Editar anotação',
                                          style: TextStyle(
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.redAccent,
                                          size: 18),
                                      SizedBox(width: 10),
                                      Text('Apagar anotação',
                                          style: TextStyle(
                                              color: Colors.redAccent)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _editNote(note),
                          ),
                          // Note text
                          Container(
                            margin: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(
                                left: BorderSide(
                                    color: Color(0xFFF59E0B), width: 2),
                              ),
                            ),
                            child: Text(
                              note.note,
                              style: GoogleFonts.lora(
                                fontSize: 14,
                                color: Colors.white60,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ),
                          // Original verse text
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 14),
                            child: Text(
                              '"${note.verse.text}"',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white24,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _NoteEntry {
  final String bookName;
  final int bookIndex;
  final int chapterIndex;
  final Verse verse;
  final String key;
  final String note;

  _NoteEntry({
    required this.bookName,
    required this.bookIndex,
    required this.chapterIndex,
    required this.verse,
    required this.key,
    required this.note,
  });
}
