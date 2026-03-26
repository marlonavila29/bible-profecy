class Verse {
  final int number;
  final String text;

  Verse({required this.number, required this.text});

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      number: json['verse'],
      text: json['text'],
    );
  }
}

class Book {
  final String name;
  final String abbrev;
  final List<List<Verse>> chapters;

  Book({required this.name, required this.abbrev, required this.chapters});

  factory Book.fromJson(Map<String, dynamic> json) {
    var rawChapters = json['chapters'] as List;
    List<List<Verse>> parsedChapters = [];
    
    for (var chapterData in rawChapters) {
      var rawVerses = chapterData as List;
      List<Verse> verses = rawVerses.map((v) => Verse.fromJson(v)).toList();
      parsedChapters.add(verses);
    }

    return Book(
      name: json['name'],
      abbrev: json['abbrev'],
      chapters: parsedChapters,
    );
  }
}

class Comment {
  final String author;
  final String text;

  Comment({required this.author, required this.text});

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      author: json['author'] ?? 'Autor Desconhecido',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'text': text,
    };
  }
}

class DictEntry {
  final String meaning;
  final String? originalWord;

  DictEntry({required this.meaning, this.originalWord});

  factory DictEntry.fromJson(dynamic json) {
    if (json is String) {
      return DictEntry(meaning: json);
    } else if (json is Map<String, dynamic>) {
      return DictEntry(
        meaning: json['meaning'] ?? '',
        originalWord: json['originalWord'],
      );
    }
    return DictEntry(meaning: '');
  }

  Map<String, dynamic> toJson() {
    return {
      'meaning': meaning,
      if (originalWord != null && originalWord!.isNotEmpty) 'originalWord': originalWord,
    };
  }
}

class VerseOptions {
  final List<Comment> comments;
  final List<String> images;
  final List<String> gifs;
  final List<String> references;
  final String? youtubeUrl;

  VerseOptions({
    this.comments = const [],
    this.images = const [],
    this.gifs = const [],
    this.references = const [],
    this.youtubeUrl,
  });

  factory VerseOptions.fromJson(Map<String, dynamic> json) {
    List<Comment> parsedComments = [];
    if (json['comments'] is List) {
      for (var e in json['comments']) {
        if (e is Map<String, dynamic>) {
          parsedComments.add(Comment.fromJson(e));
        } else if (e is String) {
          parsedComments.add(Comment(author: 'Autor Desconhecido', text: e));
        }
      }
    }

    return VerseOptions(
      comments: parsedComments,
      images: json['images'] is List ? List<String>.from((json['images'] as List).map((e) => e.toString())) : [],
      gifs: json['gifs'] is List ? List<String>.from((json['gifs'] as List).map((e) => e.toString())) : [],
      references: json['references'] is List ? List<String>.from((json['references'] as List).map((e) => e.toString())) : [],
      youtubeUrl: json['youtubeUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comments': comments.map((e) => e.toJson()).toList(),
      'images': images,
      'gifs': gifs,
      'references': references,
      'youtubeUrl': youtubeUrl,
    };
  }
}

class UserVerseData {
  final int? highlightColor;
  final String? personalNote;
  final bool isFavorite;

  UserVerseData({this.highlightColor, this.personalNote, this.isFavorite = false});

  factory UserVerseData.fromJson(Map<String, dynamic> json) {
    return UserVerseData(
      highlightColor: json['highlightColor'],
      personalNote: json['personalNote'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (highlightColor != null) 'highlightColor': highlightColor,
      if (personalNote != null) 'personalNote': personalNote,
      if (isFavorite) 'isFavorite': isFavorite,
    };
  }

  UserVerseData copyWith({int? highlightColor, String? personalNote, bool? isFavorite, bool clearHighlight = false}) {
    return UserVerseData(
      highlightColor: clearHighlight ? null : (highlightColor ?? this.highlightColor),
      personalNote: personalNote ?? this.personalNote,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
