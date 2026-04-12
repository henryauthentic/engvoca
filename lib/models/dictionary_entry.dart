class DictionaryEntry {
  final String word;
  final String? phonetic;
  final List<Phonetic> phonetics;
  final List<Meaning> meanings;
  final String? origin;

  DictionaryEntry({
    required this.word,
    this.phonetic,
    required this.phonetics,
    required this.meanings,
    this.origin,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] as String,
      phonetic: json['phonetic'] as String?,
      phonetics: (json['phonetics'] as List?)
              ?.map((p) => Phonetic.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      meanings: (json['meanings'] as List?)
              ?.map((m) => Meaning.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      origin: json['origin'] as String?,
    );
  }
}

class Phonetic {
  final String? text;
  final String? audio;

  Phonetic({this.text, this.audio});

  factory Phonetic.fromJson(Map<String, dynamic> json) {
    return Phonetic(
      text: json['text'] as String?,
      audio: json['audio'] as String?,
    );
  }
}

class Meaning {
  final String partOfSpeech;
  final List<Definition> definitions;
  final List<String> synonyms;
  final List<String> antonyms;

  Meaning({
    required this.partOfSpeech,
    required this.definitions,
    required this.synonyms,
    required this.antonyms,
  });

  factory Meaning.fromJson(Map<String, dynamic> json) {
    return Meaning(
      partOfSpeech: json['partOfSpeech'] as String,
      definitions: (json['definitions'] as List?)
              ?.map((d) => Definition.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      synonyms: (json['synonyms'] as List?)?.cast<String>() ?? [],
      antonyms: (json['antonyms'] as List?)?.cast<String>() ?? [],
    );
  }
}

class Definition {
  final String definition;
  final String? example;
  final List<String> synonyms;
  final List<String> antonyms;

  Definition({
    required this.definition,
    this.example,
    required this.synonyms,
    required this.antonyms,
  });

  factory Definition.fromJson(Map<String, dynamic> json) {
    return Definition(
      definition: json['definition'] as String,
      example: json['example'] as String?,
      synonyms: (json['synonyms'] as List?)?.cast<String>() ?? [],
      antonyms: (json['antonyms'] as List?)?.cast<String>() ?? [],
    );
  }
}