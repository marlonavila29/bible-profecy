import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  List<Book> books = [];
  Map<String, DictEntry> dictionary = {};
  Map<String, VerseOptions> verseOptions = {};
  Map<String, UserVerseData> userVerseData = {};
  SharedPreferences? _prefs;

  Future<void> init() async {
    // 1. Load Bible
    final String response = await rootBundle.loadString('assets/bible-data.json');
    final List<dynamic> data = json.decode(response);
    
    books = data.map((b) => Book.fromJson(b)).toList();
    // Ensure Daniel comes first if they were out of order
    books.sort((a, b) => a.name == 'Daniel' ? -1 : 1);

    // 2. Load Dictionary
    _prefs = await SharedPreferences.getInstance();
    final String dictString = _prefs?.getString('dictionary') ?? '{}';
    final Map<String, dynamic> rawDict = json.decode(dictString);
    dictionary = {};
    rawDict.forEach((key, value) {
      dictionary[key] = DictEntry.fromJson(value);
    });

    // 3. Load Verse Options
    final String optsString = _prefs?.getString('verseOptions') ?? '{}';
    try {
      final Map<String, dynamic> rawOpts = json.decode(optsString);
      verseOptions = {};
      rawOpts.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          verseOptions[key] = VerseOptions.fromJson(value);
        }
      });
    } catch (e) {
      verseOptions = {};
    }

    // 4. Load User Verse Data
    final String usrOptsString = _prefs?.getString('userVerseData') ?? '{}';
    try {
      final Map<String, dynamic> rawUsrOpts = json.decode(usrOptsString);
      userVerseData = {};
      rawUsrOpts.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          userVerseData[key] = UserVerseData.fromJson(value);
        }
      });
    } catch (e) {
      userVerseData = {};
    }
  }

  Future<void> saveDictionaryWord(String word, String meaning, [String? originalWord]) async {
    final cleanWord = word.trim().toLowerCase();
    dictionary[cleanWord] = DictEntry(meaning: meaning.trim(), originalWord: originalWord?.trim().isNotEmpty == true ? originalWord!.trim() : null);
    await _saveToPrefs();
  }

  Future<void> removeDictionaryWord(String word) async {
    final cleanWord = word.trim().toLowerCase();
    dictionary.remove(cleanWord);
    await _saveToPrefs();
  }

  Future<void> saveVerseOptions(String key, VerseOptions opts) async {
    verseOptions[key] = opts;
    await _saveOptsToPrefs();
  }

  Future<void> removeVerseOptions(String key) async {
    verseOptions.remove(key);
    await _saveOptsToPrefs();
  }

  Future<void> saveUserVerseData(String key, UserVerseData data) async {
    userVerseData[key] = data;
    await _saveUserOptsToPrefs();
  }

  Future<void> removeUserVerseData(String key) async {
    userVerseData.remove(key);
    await _saveUserOptsToPrefs();
  }

  Future<void> _saveToPrefs() async {
    final encoded = json.encode(dictionary.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString('dictionary', encoded);
  }

  Future<void> _saveOptsToPrefs() async {
    final encoded = json.encode(verseOptions.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString('verseOptions', encoded);
  }

  Future<void> _saveUserOptsToPrefs() async {
    final encoded = json.encode(userVerseData.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString('userVerseData', encoded);
  }

  String exportAll() {
    final Map<String, dynamic> combined = {
      'dictionary': dictionary.map((k, v) => MapEntry(k, v.toJson())),
      'verseOptions': verseOptions.map((k, v) => MapEntry(k, v.toJson())),
      'userVerseData': userVerseData.map((k, v) => MapEntry(k, v.toJson())),
    };
    return json.encode(combined);
  }

  Future<void> importAll(String jsonData) async {
    final Map<String, dynamic> combined = json.decode(jsonData);
    
    if (combined.containsKey('dictionary')) {
      final Map<String, dynamic> rawDict = combined['dictionary'];
      dictionary = {};
      rawDict.forEach((key, value) {
        dictionary[key] = DictEntry.fromJson(value);
      });
      await _saveToPrefs();
    }
    
    if (combined.containsKey('verseOptions')) {
      final Map<String, dynamic> rawOpts = combined['verseOptions'];
      verseOptions = rawOpts.map((key, value) => MapEntry(key, VerseOptions.fromJson(value)));
      await _saveOptsToPrefs();
    }
    
    if (combined.containsKey('userVerseData')) {
      final Map<String, dynamic> rawUsrOpts = combined['userVerseData'];
      userVerseData = rawUsrOpts.map((key, value) => MapEntry(key, UserVerseData.fromJson(value)));
      await _saveUserOptsToPrefs();
    }
  }
}
