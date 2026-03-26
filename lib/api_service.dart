import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'app_locale.dart';

/// REST API fallback for when Firestore direct access fails.
/// Calls the Render.com backend API which has server-side Firestore access.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _baseUrl = 'https://bible-admin-api.onrender.com/api/v1';
  static const String _user = 'admin';
  static const String _pass = r'adminBible7#';

  String get _lang => AppLocale().currentCode;

  Map<String, String> get _headers => {
    'Authorization': 'Basic ${base64Encode(utf8.encode('$_user:$_pass'))}',
    'Content-Type': 'application/json',
  };

  // ─── Dictionary ──────────────────────────────────────────────────────────

  Future<Map<String, DictEntry>> loadDictionary() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/dictionary/$_lang'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final raw = json.decode(resp.body) as Map<String, dynamic>;
        final map = <String, DictEntry>{};
        raw.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            map[k] = DictEntry.fromJson(v);
          }
        });
        return map;
      }
    } catch (e) {
      print('[ApiService] loadDictionary error: $e');
    }
    return {};
  }

  // ─── Verse Options ────────────────────────────────────────────────────────

  Future<Map<String, VerseOptions>> loadVerseOptions() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/verse-options/$_lang'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final raw = json.decode(resp.body) as Map<String, dynamic>;
        final map = <String, VerseOptions>{};
        raw.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            map[k] = VerseOptions.fromJson(v);
          }
        });
        return map;
      }
    } catch (e) {
      print('[ApiService] loadVerseOptions error: $e');
    }
    return {};
  }

  // ─── Chapter Audio ────────────────────────────────────────────────────────

  Future<Map<String, String>> loadChapterAudio() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/chapter-audio/$_lang'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final raw = json.decode(resp.body) as Map<String, dynamic>;
        return raw.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      print('[ApiService] loadChapterAudio error: $e');
    }
    return {};
  }

  // ─── Podcasts ─────────────────────────────────────────────────────────────

  Future<List<Map<String, String>>> loadPodcasts() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/podcasts/$_lang'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final raw = json.decode(resp.body) as List<dynamic>;
        return raw.map((e) {
          final m = e as Map<String, dynamic>;
          return <String, String>{
            'id': m['id']?.toString() ?? '',
            'title': m['title']?.toString() ?? '',
            'url': m['url']?.toString() ?? '',
            'description': m['description']?.toString() ?? '',
          };
        }).toList();
      }
    } catch (e) {
      print('[ApiService] loadPodcasts error: $e');
    }
    return [];
  }

  // ─── Literal Verses ───────────────────────────────────────────────────────

  Future<Set<String>> loadLiteralVerses() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/literal-verses/$_lang'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final raw = json.decode(resp.body) as List<dynamic>;
        return raw.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      print('[ApiService] loadLiteralVerses error: $e');
    }
    return {};
  }
}
