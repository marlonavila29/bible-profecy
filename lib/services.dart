import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'firestore_service.dart';
import 'api_service.dart';
import 'app_locale.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  List<Book> books = [];
  Map<String, DictEntry> dictionary = {};
  Map<String, VerseOptions> verseOptions = {};
  Map<String, UserVerseData> userVerseData = {};
  Map<String, String> chapterAudio = {};
  List<Map<String, String>> podcasts = [];
  Set<String> literalVerses = {}; // keys: "BookName_chapter_verse"
  SharedPreferences? _prefs;

  Future<void> init() async {
    // 1. Load Bible from locale-specific asset (fallback to Portuguese)
    final bibleAsset = AppLocale().current.bibleAsset;
    String response;
    try {
      response = await rootBundle.loadString(bibleAsset);
    } catch (_) {
      // Fallback to Portuguese if translation file doesn't exist yet
      response = await rootBundle.loadString('assets/bible-data.json');
    }
    final List<dynamic> data = json.decode(response);
    books = data.map((b) => Book.fromJson(b)).toList();
    books.sort((a, b) => a.name == 'Daniel' ? -1 : 1);

    _prefs = await SharedPreferences.getInstance();

    // 2. Load Local Data First (Instant)
    _loadDictFromPrefs();
    _loadOptsFromPrefs();
    _loadUserDataFromPrefs();
    _loadChapterAudioFromPrefs();
    _loadPodcastsFromPrefs();

    // 3. Try Firestore first (fast, 4s timeout)
    bool firestoreWorked = false;
    try {
      final fs = FirestoreService();
      await Future.wait([
        fs.loadDictionary().then((remote) {
          if (remote.isNotEmpty) {
            dictionary = remote;
            _saveDictToPrefs();
            firestoreWorked = true;
          }
        }).catchError((_) {}),
        
        fs.loadVerseOptions().then((remote) {
          if (remote.isNotEmpty) {
            verseOptions = remote;
            _saveOptsToPrefs();
            firestoreWorked = true;
          }
        }).catchError((_) {}),
        
        fs.loadChapterAudio().then((remote) {
          if (remote.isNotEmpty) {
            chapterAudio = remote;
            _saveChapterAudioToPrefs();
            firestoreWorked = true;
          }
        }).catchError((_) {}),
        
        fs.loadPodcasts().then((remote) {
          if (remote.isNotEmpty) {
            podcasts = remote;
            _savePodcastsToPrefs();
            firestoreWorked = true;
          }
        }).catchError((_) {}),

        fs.loadLiteralVerses().then((remote) {
          if (remote.isNotEmpty) {
            literalVerses = remote;
            firestoreWorked = true;
          }
        }).catchError((_) {}),

      ]).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('[DataService] Firestore sync timed out: $e');
    }

    // 4. If Firestore didn't return data, fallback to REST API (backend on Render)
    if (!firestoreWorked) {
      print('[DataService] Firestore empty/blocked. Trying REST API fallback...');
      try {
        final api = ApiService();
        final results = await Future.wait([
          api.loadDictionary().catchError((_) => <String, DictEntry>{}),
          api.loadVerseOptions().catchError((_) => <String, VerseOptions>{}),
          api.loadChapterAudio().catchError((_) => <String, String>{}),
          api.loadPodcasts().catchError((_) => <Map<String, String>>[]),
          api.loadLiteralVerses().catchError((_) => <String>{}),
        ]).timeout(const Duration(seconds: 90));

        final remoteDictionary = results[0] as Map<String, DictEntry>;
        final remoteVerseOptions = results[1] as Map<String, VerseOptions>;
        final remoteChapterAudio = results[2] as Map<String, String>;
        final remotePodcasts = results[3] as List<Map<String, String>>;
        final remoteLiterals = results[4] as Set<String>;

        if (remoteDictionary.isNotEmpty) {
          dictionary = remoteDictionary;
          _saveDictToPrefs();
        }
        if (remoteVerseOptions.isNotEmpty) {
          verseOptions = remoteVerseOptions;
          _saveOptsToPrefs();
        }
        if (remoteChapterAudio.isNotEmpty) {
          chapterAudio = remoteChapterAudio;
          _saveChapterAudioToPrefs();
        }
        if (remotePodcasts.isNotEmpty) {
          podcasts = remotePodcasts;
          _savePodcastsToPrefs();
        }
        if (remoteLiterals.isNotEmpty) {
          literalVerses = remoteLiterals;
        }
        print('[DataService] REST API fallback loaded successfully.');
      } catch (e) {
        print('[DataService] REST API fallback also failed: $e. Using local cache.');
      }
    }
  }



  // ─── Chapter Audio (local + future cloud) ───────────────────────────────────

  /// key = "BookName_chapterIndex", e.g. "Daniel_0"
  String chapterAudioKey(String bookName, int chapterIndex) =>
      '${bookName}_$chapterIndex';



  String? getChapterAudio(String bookName, int chapterIndex) =>
      chapterAudio[chapterAudioKey(bookName, chapterIndex)];

  // ─── Literal Verses ──────────────────────────────────────────────────────────

  String literalVerseKey(String bookName, int chapter, int verse) =>
      '${bookName}_${chapter}_$verse';

  bool isVerseLiteral(String bookName, int chapter, int verse) =>
      literalVerses.contains(literalVerseKey(bookName, chapter, verse));



  // ─── User Verse Data (local only) ───────────────────────────────────────────

  Future<void> saveUserVerseData(String key, UserVerseData data) async {
    userVerseData[key] = data;
    await _saveUserDataToPrefs();
  }

  Future<void> removeUserVerseData(String key) async {
    userVerseData.remove(key);
    await _saveUserDataToPrefs();
  }



  // ─── Private: LocalPrefs helpers ─────────────────────────────────────────────

  void _loadDictFromPrefs() {
    try {
      final s = _prefs?.getString('dictionary') ?? '{}';
      final raw = json.decode(s) as Map<String, dynamic>;
      dictionary = {};
      raw.forEach((k, v) => dictionary[k] = DictEntry.fromJson(v));
    } catch (_) {
      dictionary = {};
    }
  }

  void _loadOptsFromPrefs() {
    try {
      final s = _prefs?.getString('verseOptions') ?? '{}';
      final raw = json.decode(s) as Map<String, dynamic>;
      verseOptions = {};
      raw.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          verseOptions[k] = VerseOptions.fromJson(v);
        }
      });
    } catch (_) {
      verseOptions = {};
    }
  }

  void _loadUserDataFromPrefs() {
    try {
      final s = _prefs?.getString('userVerseData') ?? '{}';
      final raw = json.decode(s) as Map<String, dynamic>;
      userVerseData = {};
      raw.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          userVerseData[k] = UserVerseData.fromJson(v);
        }
      });
    } catch (_) {
      userVerseData = {};
    }
  }

  Future<void> _saveDictToPrefs() async {
    final encoded =
        json.encode(dictionary.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString('dictionary', encoded);
  }

  Future<void> _saveOptsToPrefs() async {
    final encoded =
        json.encode(verseOptions.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString('verseOptions', encoded);
  }

  Future<void> _saveUserDataToPrefs() async {
    final encoded =
        json.encode(userVerseData.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString('userVerseData', encoded);
  }
  Future<void> _saveChapterAudioToPrefs() async {
    final encoded = json.encode(chapterAudio);
    await _prefs?.setString('chapterAudio', encoded);
  }

  void _loadChapterAudioFromPrefs() {
    try {
      final s = _prefs?.getString('chapterAudio') ?? '{}';
      final raw = json.decode(s) as Map<String, dynamic>;
      chapterAudio = raw.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      chapterAudio = {};
    }
  }

  Future<void> _savePodcastsToPrefs() async {
    final encoded = json.encode(podcasts);
    await _prefs?.setString('podcasts', encoded);
  }

  void _loadPodcastsFromPrefs() {
    try {
      final s = _prefs?.getString('podcasts') ?? '[]';
      final raw = json.decode(s) as List<dynamic>;
      podcasts = raw.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      podcasts = [];
    }
  }
}
