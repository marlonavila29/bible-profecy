import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'services.dart';
import 'models.dart';
import 'app_error.dart';
import 'app_locale.dart';
import 'image_compressor_web.dart';
import 'firestore_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();
  final TextEditingController _originalWordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Verse Options state
  int _selBook = 0;
  int _selChap = 0;
  int _selVerse = 1;
  final TextEditingController _commentAuthorCtrl = TextEditingController();
  final TextEditingController _commentTextCtrl = TextEditingController();
  List<Comment> _currentComments = [];
  final TextEditingController _imagesCtrl = TextEditingController();
  final TextEditingController _gifsCtrl = TextEditingController();
  final TextEditingController _refsCtrl = TextEditingController();
  final TextEditingController _ytCtrl = TextEditingController();

  // Backup state
  final TextEditingController _backupCtrl = TextEditingController();

  // Audio tab state
  int _audioSelBook = 0;
  int _audioSelChap = 0;

  // ── Tab Literais state ──
  int _litSelBook = 0;
  int _litSelChap = 0;
  final TextEditingController _audioUrlCtrl = TextEditingController();
  final TextEditingController _podTitleCtrl = TextEditingController();
  final TextEditingController _podUrlCtrl = TextEditingController();
  final TextEditingController _podDescCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Load current audio status for default selections
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentChapterAudio();
    });
  }

  void _loadDictionary() {
    setState(() {});
  }

  void _addWord() async {
    final word = _wordController.text;
    final meaning = _meaningController.text;
    final originalWord = _originalWordController.text;
    if (word.isEmpty || meaning.isEmpty) return;

    await DataService().saveDictionaryWord(
        word, meaning, originalWord.isNotEmpty ? originalWord : null);
    _wordController.clear();
    _meaningController.clear();
    _originalWordController.clear();
    _loadDictionary();

    if (mounted) {
      AppFeedback.showSuccess(
          context, 'Palavra "$word" salva no dicionário e na nuvem! ☁️');
    }
  }

  void _deleteWord(String word) async {
    await DataService().removeDictionaryWord(word);
    _loadDictionary();
    if (mounted) {
      AppFeedback.showSuccess(context, 'Palavra removida da nuvem.');
    }
  }

  void _editWord(String word, DictEntry entry) {
    _wordController.text = word;
    _meaningController.text = entry.meaning;
    _originalWordController.text = entry.originalWord ?? '';
    _scrollController.animateTo(0.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _saveVerseOptions() async {
    final bookName = DataService().books[_selBook].name;
    final key = "${bookName}_${_selChap}_$_selVerse";

    final opts = VerseOptions(
      comments: _currentComments.toList(),
      images: _imagesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      gifs: _gifsCtrl.text
          .split(RegExp(r'[,;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      references: _refsCtrl.text
          .split(RegExp(r'[,;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      youtubeUrl: _ytCtrl.text.trim().isNotEmpty ? _ytCtrl.text.trim() : null,
    );

    await DataService().saveVerseOptions(key, opts);
    if (mounted) {
      AppFeedback.showSuccess(
          context, 'Opções do versículo salvas na nuvem! ☁️');
    }
  }

  void _loadVerseOptionsForCurrent() {
    final bookName = DataService().books[_selBook].name;
    final key = "${bookName}_${_selChap}_$_selVerse";
    final existing = DataService().verseOptions[key];

    setState(() {
      if (existing != null) {
        _currentComments = existing.comments.toList();
        _imagesCtrl.text = existing.images.join(', ');
        _gifsCtrl.text = existing.gifs.join(', ');
        _refsCtrl.text = existing.references.join(', ');
        _ytCtrl.text = existing.youtubeUrl ?? '';
      } else {
        _currentComments = [];
        _imagesCtrl.clear();
        _gifsCtrl.clear();
        _refsCtrl.clear();
        _ytCtrl.clear();
      }
    });
  }

  void _exportData() {
    final data = DataService().exportAll();
    _backupCtrl.text = data;
    Clipboard.setData(ClipboardData(text: data));
    if (mounted) {
      AppFeedback.showSuccess(
          context, 'Dados exportados e copiados para a área de transferência!');
    }
  }

  void _importData() async {
    try {
      final data = _backupCtrl.text;
      if (data.isEmpty) return;
      await DataService().importAll(data);
      if (mounted) {
        AppFeedback.showSuccess(
            context, 'Dados importados e sincronizados com a nuvem! ✅');
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context,
            'Formato inválido. Verifique se o JSON está correto e tente novamente.');
      }
    }
  }

  Widget _buildTextField(TextEditingController ctrl, String label,
      {int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dictKeys = DataService().dictionary.keys.toList()..sort();
    final books = DataService().books;

    if (books.isEmpty) return const Scaffold();

    final currentBook = books[_selBook];
    final currentChapVerses = currentBook.chapters[_selChap];

    return Scaffold(
      appBar: AppBar(
        title: Text('Painel de Admin', style: GoogleFonts.cinzel()),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Dicionário"),
            Tab(text: "Opções"),
            Tab(text: "Backup"),
            Tab(text: "Áudio"),
            Tab(text: "Literais"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: Dicionário ────────────────────────────────────
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Adicionar Significado',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 16),
                      _buildTextField(_wordController, 'Palavra em Português'),
                      _buildTextField(_originalWordController,
                          'Palavra Original (Opcional, ex: θάλασσα)'),
                      _buildTextField(_meaningController, 'Significado',
                          maxLines: 3),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _addWord,
                        child: const Text('Salvar Significado',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text('Palavras Cadastradas',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dictKeys.length,
                  itemBuilder: (context, index) {
                    final k = dictKeys[index];
                    final v = DataService().dictionary[k];
                    return Card(
                      color: Theme.of(context).colorScheme.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(k,
                            style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(v?.meaning ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blueAccent),
                              onPressed: () => _editWord(k, v!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => _deleteWord(k),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── TAB 2: Opções de Versículo ────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selBook,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            items: List.generate(
                                books.length,
                                (i) => DropdownMenuItem(
                                    value: i, child: Text(books[i].name))),
                            onChanged: (v) => setState(() {
                              _selBook = v!;
                              _selChap = 0;
                              _selVerse = 1;
                              _loadVerseOptionsForCurrent();
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selChap,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            items: List.generate(
                                currentBook.chapters.length,
                                (i) => DropdownMenuItem(
                                    value: i, child: Text('Cap ${i + 1}'))),
                            onChanged: (v) => setState(() {
                              _selChap = v!;
                              _selVerse = 1;
                              _loadVerseOptionsForCurrent();
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selVerse,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            items: currentChapVerses
                                .map((v) => DropdownMenuItem(
                                    value: v.number,
                                    child: Text('Ver ${v.number}')))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selVerse = v!;
                              _loadVerseOptionsForCurrent();
                            }),
                          ),
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.refresh, color: Colors.blueAccent),
                        onPressed: _loadVerseOptionsForCurrent,
                        tooltip: "Carregar dados deste verso",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                    'Configurar Opções para ${currentBook.name} ${_selChap + 1}:$_selVerse',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Comentários (${_currentComments.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (_currentComments.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _currentComments.length,
                          itemBuilder: (context, idx) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_currentComments[idx].author,
                                style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            subtitle: Text(_currentComments[idx].text,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => setState(
                                  () => _currentComments.removeAt(idx)),
                            ),
                          ),
                        ),
                      _buildTextField(
                          _commentAuthorCtrl, 'Autor do Comentário'),
                      _buildTextField(_commentTextCtrl, 'Texto do Comentário',
                          maxLines: 3),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          if (_commentAuthorCtrl.text.isNotEmpty &&
                              _commentTextCtrl.text.isNotEmpty) {
                            setState(() {
                              _currentComments.add(Comment(
                                  author: _commentAuthorCtrl.text.trim(),
                                  text: _commentTextCtrl.text.trim()));
                              _commentAuthorCtrl.clear();
                              _commentTextCtrl.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Comentário'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Images: text field + upload button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildTextField(
                          _imagesCtrl, 'Imagens (URLs separadas por vírgula)'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _uploadImageFile(
                          currentBook.name, _selChap, _selVerse),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label:
                          const Text('Enviar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                // GIFs/Videos: text field + upload button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildTextField(_gifsCtrl,
                          'Vídeos Curtos (URLs separadas por vírgula)'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _uploadVideoFile(
                          currentBook.name, _selChap, _selVerse),
                      icon: const Icon(Icons.videocam, size: 18),
                      label:
                          const Text('Enviar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                _buildTextField(_refsCtrl,
                    'Referências Cruzadas (Separe com vírgula ou ; Ex: Gênesis 1:1; João 3:16)'),
                _buildTextField(_ytCtrl, 'Vídeo YouTube (Link único)'),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saveVerseOptions,
                  child: const Text('Salvar Opções Especiais',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),

          // ── TAB 3: Backup ─────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cloud status card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done,
                          color: Color(0xFF10B981), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sincronizado com a Nuvem',
                                style: GoogleFonts.inter(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              'Dicionário e Opções de Versículos são salvos automaticamente no Firebase Firestore e ficam disponíveis para todos os usuários.',
                              style: GoogleFonts.inter(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Backup Manual (Segurança Extra)',
                    style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFCD34D))),
                const SizedBox(height: 8),
                Text(
                  'Embora os dados já estejam na nuvem, você pode exportar um arquivo JSON como cópia de segurança adicional.',
                  style: GoogleFonts.inter(
                      color: Colors.white60, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _exportData,
                  icon: const Icon(Icons.download),
                  label: const Text('Gerar Cópia de Segurança (Exportar)'),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                Text('Restaurar / Importar Dados',
                    style:
                        GoogleFonts.cinzel(fontSize: 18, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Cole aqui um JSON exportado anteriormente. Isso sobrescreve os dados atuais da nuvem.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildTextField(_backupCtrl, 'Código JSON', maxLines: 10),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _importData,
                  icon: const Icon(Icons.upload),
                  label: const Text('Restaurar Dados (Importar → Nuvem)'),
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Text('Migração de Dados',
                    style:
                        GoogleFonts.cinzel(fontSize: 18, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Migra dados antigos (sem prefixo de idioma) para o formato novo (pt_). Execute apenas UMA VEZ.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await FirestoreService().migrateToLocalizedCollections();
                    await DataService().init();
                    if (mounted) {
                      AppFeedback.showSuccess(
                          context, 'Migração concluída com sucesso! ✅');
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Migrar Dados para Idioma (pt_)'),
                ),
              ],
            ),
          ),

          // ── TAB 4: Áudio & Podcasts ─────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // — Chapter Audio Section —
                Text('Áudio por Capítulo',
                    style: GoogleFonts.cinzel(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Associe uma URL de áudio a um capítulo específico.',
                    style:
                        GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),

                // Book selector
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _audioSelBook,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Livro',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: books
                            .asMap()
                            .entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value.name,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null)
                            setState(() {
                              _audioSelBook = v;
                              _audioSelChap = 0;
                            });
                          _loadCurrentChapterAudio();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _audioSelChap,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Capítulo',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: List.generate(
                          books[_audioSelBook].chapters.length,
                          (i) => DropdownMenuItem(
                              value: i,
                              child: Text('Cap. ${i + 1}',
                                  style: const TextStyle(color: Colors.white))),
                        ),
                        onChanged: (v) {
                          if (v != null) setState(() => _audioSelChap = v);
                          _loadCurrentChapterAudio();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_audioUrlCtrl.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Áudio disponível para este capítulo.',
                              style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: _removeChapterAudio,
                          tooltip: 'Remover este áudio',
                        ),
                      ],
                    ),
                  ),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _uploadAudioFile,
                  icon: const Icon(Icons.drive_folder_upload),
                  label: Text(
                      _audioUrlCtrl.text.isEmpty
                          ? 'Buscar do Dispositivo'
                          : 'Substituir Áudio Atual',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),

                const SizedBox(height: 32),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),

                // — Podcasts Section —
                Text('Podcasts',
                    style: GoogleFonts.cinzel(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Adicione links de podcasts que aparecerão no leitor.',
                    style:
                        GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),
                _buildTextField(_podTitleCtrl, 'Título'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildTextField(
                          _podUrlCtrl, 'URL do podcast (MP3)',
                          hint: 'https://example.com/episode.mp3'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _uploadPodcastFile,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label:
                          const Text('Enviar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                _buildTextField(_podDescCtrl, 'Descrição (opcional)'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _savePodcast,
                  icon: const Icon(Icons.podcasts_rounded),
                  label: const Text('Adicionar Podcast',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),

                // List of podcasts
                if (DataService().podcasts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Nenhum podcast cadastrado.',
                          style: GoogleFonts.inter(color: Colors.white38)),
                    ),
                  )
                else
                  ...DataService().podcasts.asMap().entries.map((e) {
                    final p = e.value;
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.podcasts_rounded,
                            color: Color(0xFF8B5CF6)),
                        title: Text(p['title'] ?? '',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(p['url'] ?? '',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () async {
                            await DataService().removePodcast(e.key);
                            setState(() {});
                            if (mounted)
                              AppFeedback.showSuccess(
                                  context, 'Podcast removido!');
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // ── TAB 5: Versos Literais ─────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versos Literais',
                    style:
                        GoogleFonts.cinzel(fontSize: 22, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Marque os versículos que são literais (sem interpretação simbólica). '
                  'Quando marcado, o botão de interpretar será desabilitado para o leitor.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                // Book/Chapter selectors
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _litSelBook,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        decoration: InputDecoration(
                          labelText: 'Livro',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFF59E0B)),
                          ),
                        ),
                        items: List.generate(DataService().books.length, (i) {
                          return DropdownMenuItem(
                            value: i,
                            child: Text(DataService().books[i].name,
                                style: const TextStyle(color: Colors.white)),
                          );
                        }),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _litSelBook = v;
                            _litSelChap = 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _litSelChap,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        decoration: InputDecoration(
                          labelText: 'Capítulo',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFF59E0B)),
                          ),
                        ),
                        items: List.generate(
                          DataService().books[_litSelBook].chapters.length,
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text('Cap. ${i + 1}',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _litSelChap = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Summary
                Builder(builder: (_) {
                  final book = DataService().books[_litSelBook];
                  final verses = book.chapters[_litSelChap];
                  final literalCount = verses.where((v) {
                    final key = DataService()
                        .literalVerseKey(book.name, _litSelChap, v.number);
                    return DataService().literalVerses.contains(key);
                  }).length;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$literalCount de ${verses.length} versículos marcados como literais',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF10B981), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // Verse list with toggles
                ...DataService()
                    .books[_litSelBook]
                    .chapters[_litSelChap]
                    .map((verse) {
                  final book = DataService().books[_litSelBook];
                  final key = DataService()
                      .literalVerseKey(book.name, _litSelChap, verse.number);
                  final isLiteral = DataService().literalVerses.contains(key);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isLiteral
                          ? const Color(0xFF10B981).withOpacity(0.06)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isLiteral
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : Colors.white10,
                      ),
                    ),
                    child: SwitchListTile(
                      value: isLiteral,
                      activeThumbColor: const Color(0xFF10B981),
                      title: Text(
                        'v${verse.number}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        verse.text.length > 80
                            ? '${verse.text.substring(0, 80)}...'
                            : verse.text,
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: Icon(
                        isLiteral
                            ? Icons.menu_book_rounded
                            : Icons.auto_fix_high,
                        color: isLiteral
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B).withOpacity(0.5),
                        size: 20,
                      ),
                      onChanged: (val) async {
                        await DataService().setVerseLiteral(
                            book.name, _litSelChap, verse.number, val);
                        setState(() {});
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadCurrentChapterAudio() {
    final url = DataService().getChapterAudio(
        DataService().books[_audioSelBook].name, _audioSelChap);
    setState(() => _audioUrlCtrl.text = url ?? '');
  }

  void _saveChapterAudio() async {
    final url = _audioUrlCtrl.text.trim();
    if (url.isEmpty) return;
    await DataService().saveChapterAudio(
        DataService().books[_audioSelBook].name, _audioSelChap, url);
    if (mounted) AppFeedback.showSuccess(context, 'Áudio salvo com sucesso!');
  }

  void _removeChapterAudio() async {
    await DataService().removeChapterAudio(
        DataService().books[_audioSelBook].name, _audioSelChap);
    _audioUrlCtrl.clear();
    if (mounted) AppFeedback.showSuccess(context, 'Áudio removido!');
    setState(() {});
  }

  void _savePodcast() async {
    final title = _podTitleCtrl.text.trim();
    final url = _podUrlCtrl.text.trim();
    final desc = _podDescCtrl.text.trim();
    if (title.isEmpty || url.isEmpty) {
      if (mounted)
        AppFeedback.showError(context, 'Título e URL são obrigatórios.');
      return;
    }
    await DataService().savePodcast(title, url, desc);
    _podTitleCtrl.clear();
    _podUrlCtrl.clear();
    _podDescCtrl.clear();
    if (mounted) AppFeedback.showSuccess(context, 'Podcast adicionado!');
    setState(() {});
  }

  Future<String?> _uploadWithProgress(
      Reference ref, Uint8List? bytes, String? path, String title) async {
    if (bytes == null && path == null) return null;

    UploadTask uploadTask;
    if (kIsWeb || path == null) {
      uploadTask = ref.putData(bytes!);
    } else {
      uploadTask = ref.putFile(File(path));
    }

    if (!mounted) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StreamBuilder<TaskSnapshot>(
          stream: uploadTask.snapshotEvents,
          builder: (context, snapshot) {
            double progress = 0.0;
            if (snapshot.hasData) {
              final snap = snapshot.data!;
              progress = snap.totalBytes > 0
                  ? snap.bytesTransferred / snap.totalBytes
                  : 0.0;
            }
            if (snapshot.hasError) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: const Text('Erro de Upload',
                    style: TextStyle(color: Colors.redAccent)),
                content: Text(snapshot.error.toString(),
                    style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Ok',
                          style: TextStyle(color: Colors.white)))
                ],
              );
            }
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      color: const Color(0xFF10B981)),
                  const SizedBox(height: 16),
                  Text('${(progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final snapshot = await uploadTask;
      if (mounted) Navigator.pop(context);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppFeedback.showError(context, 'Erro detalhado (Storage): $e');
      }
      return null;
    }
  }

  void _uploadAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.audio, withData: true);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bookName = DataService().books[_audioSelBook].name;
      final storagePath =
          AppLocale().audioStoragePath(bookName, _audioSelChap, file.name);
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      final downloadUrl = await _uploadWithProgress(
          ref, file.bytes, file.path, 'Enviando Áudio...');
      if (downloadUrl != null) {
        setState(() => _audioUrlCtrl.text = downloadUrl);
        _saveChapterAudio();
        if (mounted) AppFeedback.showSuccess(context, 'Áudio pronto!');
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, 'Erro ao abrir arquivo: $e');
    }
  }

  void _uploadImageFile(String bookName, int chap, int verse) async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      Uint8List uploadBytes;
      if (kIsWeb) {
        if (mounted)
          AppFeedback.showSuccess(context, 'Comprimindo imagem localmente...');
        uploadBytes = await compressImageWeb(file.bytes!,
            maxDimension: 1024, quality: 0.85);
      } else {
        uploadBytes = file.bytes!;
      }

      final baseName = file.name.replaceAll(RegExp(r'\.[^.]+'), '');
      final storagePath =
          'imagens_versos/$bookName/cap${chap + 1}_v${verse}_$baseName.jpg';
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      final downloadUrl = await _uploadWithProgress(
          ref, uploadBytes, null, 'Enviando Imagem Comprimida...');

      if (downloadUrl != null) {
        setState(() {
          if (_imagesCtrl.text.trim().isNotEmpty) {
            _imagesCtrl.text = '${_imagesCtrl.text.trim()}, $downloadUrl';
          } else {
            _imagesCtrl.text = downloadUrl;
          }
        });
        if (mounted) AppFeedback.showSuccess(context, 'Imagem pronta!');
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, 'Erro ao abrir imagem: $e');
    }
  }

  void _uploadVideoFile(String bookName, int chap, int verse) async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.video, withData: true);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final storagePath =
          'videos_versos/$bookName/cap${chap + 1}_v${verse}_${file.name}';
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      final downloadUrl = await _uploadWithProgress(
          ref, file.bytes, file.path, 'Enviando Vídeo...');

      if (downloadUrl != null) {
        setState(() {
          if (_gifsCtrl.text.trim().isNotEmpty) {
            _gifsCtrl.text = '${_gifsCtrl.text.trim()}, $downloadUrl';
          } else {
            _gifsCtrl.text = downloadUrl;
          }
        });
        if (mounted) AppFeedback.showSuccess(context, 'Vídeo pronto!');
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, 'Erro ao abrir vídeo: $e');
    }
  }

  void _uploadPodcastFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.audio, withData: true);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final storagePath = AppLocale().podcastStoragePath(file.name);
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      final downloadUrl = await _uploadWithProgress(
          ref, file.bytes, file.path, 'Enviando Podcast...');

      if (downloadUrl != null) {
        setState(() => _podUrlCtrl.text = downloadUrl);
        if (mounted) AppFeedback.showSuccess(context, 'Podcast pronto!');
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, 'Erro ao abrir podcast: $e');
    }
  }
}
