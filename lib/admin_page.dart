import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services.dart';
import 'models.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _loadDictionary() {
    setState(() {});
  }

  void _addWord() async {
    final word = _wordController.text;
    final meaning = _meaningController.text;
    final originalWord = _originalWordController.text;
    if (word.isEmpty || meaning.isEmpty) return;

    await DataService().saveDictionaryWord(word, meaning, originalWord.isNotEmpty ? originalWord : null);
    _wordController.clear();
    _meaningController.clear();
    _originalWordController.clear();
    _loadDictionary();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Palavra salva com sucesso!')),
      );
    }
  }

  void _deleteWord(String word) async {
    await DataService().removeDictionaryWord(word);
    _loadDictionary();
  }

  void _editWord(String word, DictEntry entry) {
    _wordController.text = word;
    _meaningController.text = entry.meaning;
    _originalWordController.text = entry.originalWord ?? '';
    _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _saveVerseOptions() async {
    final bookName = DataService().books[_selBook].name;
    final key = "${bookName}_${_selChap}_$_selVerse";

    final opts = VerseOptions(
      comments: _currentComments.toList(),
      images: _imagesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      gifs: _gifsCtrl.text.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      references: _refsCtrl.text.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      youtubeUrl: _ytCtrl.text.trim().isNotEmpty ? _ytCtrl.text.trim() : null,
    );

    await DataService().saveVerseOptions(key, opts);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opções de Versículo salvas com sucesso!')),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conteúdo exportado e copiado para a área de transferência!')),
    );
  }

  void _importData() async {
    try {
      final data = _backupCtrl.text;
      if (data.isEmpty) return;
      await DataService().importAll(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados importados com sucesso!')),
        );
        setState(() {}); // refresh UI in case we are looking at something
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao importar. Verifique se o código JSON é válido.')),
        );
      }
    }
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {int maxLines = 1, String? hint}) {
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Dicionario
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
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 16),
                      _buildTextField(_wordController, 'Palavra em Português'),
                      _buildTextField(_originalWordController, 'Palavra Original (Opcional, ex: θάλασσα)'),
                      _buildTextField(_meaningController, 'Significado', maxLines: 3),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _addWord,
                        child: const Text('Salvar Significado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text('Palavras Cadastradas', 
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
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
                        title: Text(k, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                        subtitle: Text(v?.meaning ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              onPressed: () => _editWord(k, v!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteWord(k),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              ],
            ),
          ),

          // TAB 2: Opcoes de Verso
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selBook,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            items: List.generate(books.length, (i) => DropdownMenuItem(value: i, child: Text(books[i].name))),
                            onChanged: (v) => setState(() { _selBook = v!; _selChap = 0; _selVerse = 1; _loadVerseOptionsForCurrent(); }),
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
                            items: List.generate(currentBook.chapters.length, (i) => DropdownMenuItem(value: i, child: Text('Cap ${i+1}'))),
                            onChanged: (v) => setState(() { _selChap = v!; _selVerse = 1; _loadVerseOptionsForCurrent(); }),
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
                            items: currentChapVerses.map((v) => DropdownMenuItem(value: v.number, child: Text('Ver ${v.number}'))).toList(),
                            onChanged: (v) => setState(() { _selVerse = v!; _loadVerseOptionsForCurrent(); }),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                        onPressed: _loadVerseOptionsForCurrent,
                        tooltip: "Carregar dados deste verso",
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Configurar Opções para ${currentBook.name} ${_selChap+1}:$_selVerse', 
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
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
                      Text('Comentários (${_currentComments.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (_currentComments.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _currentComments.length,
                          itemBuilder: (context, idx) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_currentComments[idx].author, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(_currentComments[idx].text, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => setState(() => _currentComments.removeAt(idx)),
                            ),
                          ),
                        ),
                      _buildTextField(_commentAuthorCtrl, 'Autor do Comentário'),
                      _buildTextField(_commentTextCtrl, 'Texto do Comentário', maxLines: 3),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          if (_commentAuthorCtrl.text.isNotEmpty && _commentTextCtrl.text.isNotEmpty) {
                            setState(() {
                              _currentComments.add(Comment(author: _commentAuthorCtrl.text.trim(), text: _commentTextCtrl.text.trim()));
                              _commentAuthorCtrl.clear();
                              _commentTextCtrl.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Comentário'),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(_imagesCtrl, 'Imagens (URLs separadas por vírgula ou ponto e vírgula)'),
                _buildTextField(_gifsCtrl, 'GIFs/Vídeos Curtos (URLs separadas por vírgula ou ponto e vírgula)'),
                _buildTextField(_refsCtrl, 'Referências Cruzadas (Separe com vírgula ou ; Ex: Gênesis 1:1; João 3:16)'),
                _buildTextField(_ytCtrl, 'Vídeo YouTube (Link único)'),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saveVerseOptions,
                  child: const Text('Salvar Opções Especiais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                )
              ],
            ),
          ),

          // TAB 3: Backup
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Segurança de Dados', style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFFCD34D))),
                const SizedBox(height: 8),
                const Text(
                  'Dica: Se você estiver usando o Chrome (Web), o Flutter pode limpar seus dados ao reiniciar. Use os botões abaixo para salvar um "Cópia" do seu trabalho em um bloco de notas.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _exportData,
                  icon: const Icon(Icons.download),
                  label: const Text('Gerar Cópia de Segurança (Exportar)'),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                Text('Importar Dados', style: GoogleFonts.cinzel(fontSize: 18, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Cole aqui o código JSON que você exportou anteriormente:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                _buildTextField(_backupCtrl, 'Código JSON', maxLines: 10),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _importData,
                  icon: const Icon(Icons.upload),
                  label: const Text('Restaurar Dados (Importar)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
