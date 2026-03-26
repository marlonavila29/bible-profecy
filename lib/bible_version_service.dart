import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class BibleVersion {
  final String id;
  final String name;
  final String shortName;
  final String language;
  final String langCode;
  /// If non-null, fetch from bible-api.com with this code.
  final String? apiCode;
  /// If non-null, fetch from STEPBible API with this version code.
  final String? stepCode;
  /// If non-null, load from local bundled asset.
  final String? assetPath;
  /// If true, text is RTL (Hebrew/Aramaic/Arabic)
  final bool isRtl;

  const BibleVersion({
    required this.id,
    required this.name,
    required this.shortName,
    required this.language,
    required this.langCode,
    this.apiCode,
    this.stepCode,
    this.assetPath,
    this.isRtl = false,
  });
}

// ─── Available Versions ───────────────────────────────────────────────────────

const List<BibleVersion> kBibleVersions = [
  BibleVersion(
    id: 'arc',
    name: 'Almeida Revista e Corrigida',
    shortName: 'ARC',
    language: 'Português',
    langCode: 'pt',
    assetPath: 'assets/bible-data.json',
  ),
  BibleVersion(
    id: 'almeida',
    name: 'Almeida Clássica (João Ferreira)',
    shortName: 'ARA/API',
    language: 'Português',
    langCode: 'pt',
    apiCode: 'almeida',
  ),
  BibleVersion(
    id: 'kjv',
    name: 'King James Version',
    shortName: 'KJV',
    language: 'English',
    langCode: 'en',
    apiCode: 'kjv',
  ),
  BibleVersion(
    id: 'web',
    name: 'World English Bible',
    shortName: 'WEB',
    language: 'English',
    langCode: 'en',
    apiCode: 'web',
  ),
  BibleVersion(
    id: 'bbe',
    name: 'Bible in Basic English',
    shortName: 'BBE',
    language: 'English',
    langCode: 'en',
    apiCode: 'bbe',
  ),
  // ── Original Languages ──────────────────────────────────────────────────────
  BibleVersion(
    id: 'heb',
    name: 'Hebraico / Aramaico (OHB)',
    shortName: 'HEB',
    language: 'עברית / אֲרָמִית',
    langCode: 'he',
    stepCode: 'OHB', // Open Hebrew Bible via STEPBible
    isRtl: true,
  ),
  BibleVersion(
    id: 'grk',
    name: 'Grego (THGNT — Tyndale House)',
    shortName: 'GRK',
    language: 'Ἑλληνικά',
    langCode: 'el',
    stepCode: 'THGNT', // Tyndale House GNT via STEPBible
    isRtl: false,
  ),
];

// ─── Book name mapping to API format ─────────────────────────────────────────

const Map<String, String> _ptToApiBook = {
  'Daniel': 'Daniel',
  'Apocalipse': 'Revelation',
  'Gênesis': 'Genesis',
  'Êxodo': 'Exodus',
  'Levítico': 'Leviticus',
  'Números': 'Numbers',
  'Deuteronômio': 'Deuteronomy',
  'Josué': 'Joshua',
  'Juízes': 'Judges',
  'Rute': 'Ruth',
  'Isaías': 'Isaiah',
  'Jeremias': 'Jeremiah',
  'Ezequiel': 'Ezekiel',
  'Oséias': 'Hosea',
  'Obadias': 'Obadiah',
  'Jonas': 'Jonah',
  'Miquéias': 'Micah',
  'Naum': 'Nahum',
  'Habacuque': 'Habakkuk',
  'Sofonias': 'Zephaniah',
  'Ageu': 'Haggai',
  'Zacarias': 'Zechariah',
  'Malaquias': 'Malachi',
  'Mateus': 'Matthew',
  'Marcos': 'Mark',
  'Lucas': 'Luke',
  'João': 'John',
  'Atos': 'Acts',
  'Romanos': 'Romans',
  'Gálatas': 'Galatians',
  'Efésios': 'Ephesians',
  'Filipenses': 'Philippians',
  'Colossenses': 'Colossians',
  'Tito': 'Titus',
  'Filemom': 'Philemon',
  'Hebreus': 'Hebrews',
  'Tiago': 'James',
  'Judas': 'Jude',
};

// STEPBible OSIS book name mapping
const Map<String, String> _ptToStepBook = {
  'Daniel': 'Dan',
  'Apocalipse': 'Rev',
  'Gênesis': 'Gen',
  'Êxodo': 'Exod',
  'Levítico': 'Lev',
  'Números': 'Num',
  'Deuteronômio': 'Deut',
  'Josué': 'Josh',
  'Juízes': 'Judg',
  'Rute': 'Ruth',
  'Isaías': 'Isa',
  'Jeremias': 'Jer',
  'Ezequiel': 'Ezek',
  'Mateus': 'Matt',
  'Marcos': 'Mark',
  'Lucas': 'Luke',
  'João': 'John',
  'Atos': 'Acts',
  'Romanos': 'Rom',
  'Hebreus': 'Heb',
  'Tiago': 'Jas',
  'Judas': 'Jude',
};

String _toStepBook(String ptName) => _ptToStepBook[ptName] ?? ptName;

// ─── Service ─────────────────────────────────────────────────────────────────

class BibleVersionService extends ChangeNotifier {
  static final BibleVersionService _instance = BibleVersionService._internal();
  factory BibleVersionService() => _instance;
  BibleVersionService._internal();

  String _primaryVersionId = 'arc';
  List<String> _compareVersionIds = [];

  String get primaryVersionId => _primaryVersionId;
  List<String> get compareVersionIds => List.unmodifiable(_compareVersionIds);

  BibleVersion get primaryVersion =>
      kBibleVersions.firstWhere((v) => v.id == _primaryVersionId,
          orElse: () => kBibleVersions.first);

  List<BibleVersion> get compareVersions => _compareVersionIds
      .map((id) => kBibleVersions.firstWhere((v) => v.id == id,
          orElse: () => kBibleVersions.first))
      .toList();

  // Cache: "versionId|book|chapter:verse" → text
  final Map<String, String> _cache = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _primaryVersionId = prefs.getString('primaryBibleVersion') ?? 'arc';
    _compareVersionIds =
        prefs.getStringList('compareBibleVersions') ?? [];
  }

  Future<void> setPrimaryVersion(String id) async {
    _primaryVersionId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('primaryBibleVersion', id);
    notifyListeners();
  }

  /// Whether the primary version uses a local bundled asset.
  bool get isPrimaryLocal => primaryVersion.assetPath != null;

  // Chapter-level cache for API versions: "versionId|book|chapter" -> List<Verse>
  final Map<String, List<Verse>> _chapterCache = {};

  /// Fetch an entire chapter for the primary version.
  /// For local (asset-based) versions, returns null (use DataService.books).
  /// For API versions, fetches all verses and returns them.
  Future<List<Verse>?> fetchChapter({
    required String bookName,
    required int chapter, // 1-based
  }) async {
    final version = primaryVersion;
    if (version.assetPath != null) return null; // use local data
    if (version.apiCode == null) return null;

    final cacheKey = '${version.id}|$bookName|$chapter';
    if (_chapterCache.containsKey(cacheKey)) return _chapterCache[cacheKey]!;

    try {
      final apiBook = _ptToApiBook[bookName] ?? bookName;
      final uri = Uri.parse(
          'https://bible-api.com/$apiBook+$chapter?translation=${version.apiCode}');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final apiVerses = data['verses'] as List? ?? [];
        final verses = apiVerses.map((v) {
          return Verse(
            number: v['verse'] as int,
            text: (v['text'] as String?)?.trim() ?? '',
          );
        }).toList();
        _chapterCache[cacheKey] = verses;
        return verses;
      }
    } catch (e) {
      print('[BibleVersionService] fetchChapter error: $e');
    }
    return null;
  }

  Future<void> setCompareVersions(List<String> ids) async {
    _compareVersionIds = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('compareBibleVersions', ids);
  }

  /// Fetch a single verse text for a given version.
  Future<String> fetchVerse({
    required String versionId,
    required String bookName,
    required int chapter, // 1-based
    required int verse,   // 1-based
  }) async {
    final cacheKey = '$versionId|$bookName|$chapter:$verse';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final version = kBibleVersions.firstWhere((v) => v.id == versionId,
        orElse: () => kBibleVersions.first);

    String text;

    if (version.assetPath != null) {
      text = await _fetchFromAsset(version.assetPath!, bookName, chapter, verse);
    } else if (version.stepCode != null) {
      // Original language via STEPBible API
      text = await _fetchFromStepBible(version.stepCode!, bookName, chapter, verse);
    } else if (version.apiCode != null) {
      text = await _fetchFromApi(version.apiCode!, bookName, chapter, verse);
    } else {
      text = '(Versão não disponível)';
    }

    _cache[cacheKey] = text;
    return text;
  }

  Future<String> _fetchFromAsset(
      String assetPath, String bookName, int chapter, int verse) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final List<dynamic> data = json.decode(raw);
      final bookData = data.firstWhere(
          (b) => b['name'] == bookName,
          orElse: () => null);
      if (bookData == null) return '(Livro não encontrado)';
      final chapters = bookData['chapters'] as List;
      if (chapter < 1 || chapter > chapters.length) return '(Capítulo inválido)';
      final verses = chapters[chapter - 1] as List;
      final verseData = verses.firstWhere(
          (v) => v['verse'] == verse,
          orElse: () => null);
      return verseData?['text'] ?? '(Versículo não encontrado)';
    } catch (e) {
      return '(Erro ao carregar: $e)';
    }
  }

  Future<String> _fetchFromApi(
      String apiCode, String bookName, int chapter, int verse) async {
    try {
      final apiBook = _ptToApiBook[bookName] ?? bookName;
      final uri = Uri.parse(
          'https://bible-api.com/$apiBook+$chapter:$verse?translation=$apiCode');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = (data['verses'] as List?)?.first['text']?.toString().trim();
        return text ?? '(Versículo não disponível)';
      }
      return '(Erro na requisição: ${response.statusCode})';
    } catch (e) {
      return '(Sem conexão ou erro: $e)';
    }
  }

  /// Fetch from STEPBible API (original language texts: Hebrew, Greek)
  Future<String> _fetchFromStepBible(
      String stepVersion, String bookName, int chapter, int verse) async {
    try {
      final stepBook = _toStepBook(bookName);
      // STEPBible v2 API endpoint
      final uri = Uri.parse(
          'https://api.stepbible.org/v2/bible/text'
          ';version=$stepVersion'
          ';reference=$stepBook.$chapter.$verse'
          ';options=VN');
      final response = await http.get(uri,
          headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Try to extract plain text from the STEP response
        return _parseStepResponse(data, stepVersion) ;
      }
      return '(Erro STEPBible: ${response.statusCode})';
    } catch (e) {
      return '(Sem conexão com STEPBible: $e)';
    }
  }

  String _parseStepResponse(Map<String, dynamic> data, String version) {
    try {
      // STEPBible returns passages → blocks → lines → words
      final passages = data['passages'] as List?;
      if (passages == null || passages.isEmpty) return '(Texto não encontrado)';

      final blocks = passages.first['blocks'] as List?;
      if (blocks == null || blocks.isEmpty) return '(Bloco não encontrado)';

      final buffer = StringBuffer();
      for (final block in blocks) {
        final lines = block['lines'] as List? ?? [];
        for (final line in lines) {
          final words = line['words'] as List? ?? [];
          for (final word in words) {
            // In STEP response, each word has a 'w' (word) or 'lemma' field
            final w = word['w']?.toString() ?? word['lemma']?.toString() ?? '';
            if (w.isNotEmpty) {
              buffer.write('$w ');
            }
          }
        }
      }
      final result = buffer.toString().trim();
      if (result.isNotEmpty) return result;

      // Fallback: try rawText if available
      final rawText = data['rawText']?.toString() ??
          passages.first['rawText']?.toString();
      return rawText ?? '(Texto não disponível)';
    } catch (e) {
      return '(Erro ao parsear resposta: $e)';
    }
  }

  /// Fetch multiple versions for comparison at once.
  Future<Map<BibleVersion, String>> fetchComparison({
    required String bookName,
    required int chapter,
    required int verse,
    required List<String> versionIds,
  }) async {
    final result = <BibleVersion, String>{};
    await Future.wait(versionIds.map((id) async {
      final version = kBibleVersions.firstWhere((v) => v.id == id,
          orElse: () => kBibleVersions.first);
      final text = await fetchVerse(
        versionId: id,
        bookName: bookName,
        chapter: chapter,
        verse: verse,
      );
      result[version] = text;
    }));
    return result;
  }
}
