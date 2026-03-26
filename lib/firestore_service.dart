import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'app_locale.dart';

/// Centralizes all Firestore read/write operations.
/// Collections are namespaced by locale:
///   - '{lang}_dictionary'     → documents keyed by word (lowercase)
///   - '{lang}_verseOptions'   → comments (language-specific)
///   - 'verseOptions'          → images, videos, refs, youtube (global/shared)
///   - '{lang}_chapterAudio'   → audio links per chapter
///   - '{lang}_podcasts'       → podcast entries
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _lang => AppLocale().currentCode;

  // ─── Dynamic collection references ─────────────────────────────────────────
  CollectionReference get _dict => _db.collection('${_lang}_dictionary');
  CollectionReference get _opts => _db.collection('${_lang}_verseOptions');
  CollectionReference get _globalOpts => _db.collection('verseOptions');
  CollectionReference get _audio => _db.collection('${_lang}_chapterAudio');
  CollectionReference get _podcasts => _db.collection('${_lang}_podcasts');

  // ─── Dictionary ────────────────────────────────────────────────────────────

  Future<Map<String, DictEntry>> loadDictionary() async {
    try {
      final snap = await _dict.get();
      final map = <String, DictEntry>{};
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        map[doc.id] = DictEntry.fromJson(data);
      }
      return map;
    } catch (e) {
      print('[Firestore] loadDictionary error: $e');
      return {};
    }
  }



  // ─── Verse Options (language-specific: comments) ───────────────────────────

  Future<Map<String, VerseOptions>> loadVerseOptions() async {
    try {
      // Load language-specific data (comments)
      final langSnap = await _opts.get();
      final map = <String, VerseOptions>{};
      for (final doc in langSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        map[doc.id] = VerseOptions.fromJson(data);
      }

      // Load global data (images, videos, refs, youtube) and merge
      final globalSnap = await _globalOpts.get();
      for (final doc in globalSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final globalOpts = VerseOptions.fromJson(data);
        if (map.containsKey(doc.id)) {
          // Merge: keep language comments, add global media
          final existing = map[doc.id]!;
          map[doc.id] = VerseOptions(
            comments: existing.comments,
            images: globalOpts.images.isNotEmpty ? globalOpts.images : existing.images,
            gifs: globalOpts.gifs.isNotEmpty ? globalOpts.gifs : existing.gifs,
            references: globalOpts.references.isNotEmpty ? globalOpts.references : existing.references,
            youtubeUrl: globalOpts.youtubeUrl ?? existing.youtubeUrl,
          );
        } else {
          map[doc.id] = globalOpts;
        }
      }

      return map;
    } catch (e) {
      print('[Firestore] loadVerseOptions error: $e');
      return {};
    }
  }



  // ─── Chapter Audio ─────────────────────────────────────────────────────────

  Future<Map<String, String>> loadChapterAudio() async {
    try {
      final snap = await _audio.get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        map[doc.id] = data['url'] as String? ?? '';
      }
      return map;
    } catch (e) {
      print('[Firestore] loadChapterAudio error: $e');
      return {};
    }
  }



  // ─── Podcasts ──────────────────────────────────────────────────────────────

  Future<List<Map<String, String>>> loadPodcasts() async {
    try {
      final snap = await _podcasts.orderBy('createdAt', descending: true).get();
      final list = <Map<String, String>>[];
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        list.add({
          'id': doc.id,
          'title': data['title'] as String? ?? '',
          'url': data['url'] as String? ?? '',
          'description': data['description'] as String? ?? '',
        });
      }
      return list;
    } catch (e) {
      print('[Firestore] loadPodcasts error: $e');
      return [];
    }
  }



  // ─── Literal Verses ────────────────────────────────────────────────────────
  // key: "BookName_chapter_verse" (e.g. "Daniel_1_3")
  // Marks a verse as literal (no prophetic interpretation needed)

  CollectionReference get _literals => _db.collection('${_lang}_literalVerses');

  Future<Set<String>> loadLiteralVerses() async {
    try {
      final snap = await _literals.get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (e) {
      print('[Firestore] loadLiteralVerses error: $e');
      return {};
    }
  }


}
