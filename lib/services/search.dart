import '../models/library.dart';

/// Normalizes Arabic text so searches ignore diacritics and letter variants
/// (أ/إ/آ → ا, ة → ه, ى → ي, Arabic-Indic digits → Latin digits).
String normalizeArabic(String input) {
  final b = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    // Tashkeel and tatweel.
    if ((r >= 0x064B && r <= 0x0652) || r == 0x0670 || r == 0x0640) continue;
    switch (r) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        b.writeCharCode(0x0627);
      case 0x0629: // ة
        b.writeCharCode(0x0647);
      case 0x0649: // ى
        b.writeCharCode(0x064A);
      default:
        if (r >= 0x0660 && r <= 0x0669) {
          b.writeCharCode(r - 0x0660 + 0x30);
        } else if (r >= 0x06F0 && r <= 0x06F9) {
          b.writeCharCode(r - 0x06F0 + 0x30);
        } else {
          b.writeCharCode(r);
        }
    }
  }
  return b.toString();
}

class SearchHit {
  final Document document;

  /// Index of the matching section, or null when only the title matched.
  final int? sectionIndex;
  final String snippet;
  final int score;

  const SearchHit({
    required this.document,
    required this.sectionIndex,
    required this.snippet,
    required this.score,
  });
}

/// Indices of [doc]'s sections containing every word of [query].
List<int> searchInDocument(Document doc, String query) {
  final terms = normalizeArabic(query)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final out = <int>[];
  for (var i = 0; i < doc.sections.length; i++) {
    final s = doc.sections[i];
    final norm = s.normalized ??= normalizeArabic('${s.title}\n${s.body}');
    if (terms.every(norm.contains)) out.add(i);
  }
  return out;
}

List<SearchHit> search(Library library, String query, {int limit = 100}) {
  final terms = normalizeArabic(query)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (terms.isEmpty) return const [];

  bool matchesAll(String text) => terms.every(text.contains);

  final hits = <SearchHit>[];
  for (final doc in library.documents) {
    final title = doc.normalizedTitle ??= normalizeArabic(doc.title);
    if (matchesAll(title)) {
      hits.add(SearchHit(
        document: doc,
        sectionIndex: null,
        snippet: doc.summary,
        score: 100,
      ));
    }
    for (var i = 0; i < doc.sections.length; i++) {
      final s = doc.sections[i];
      final norm = s.normalized ??= normalizeArabic('${s.title}\n${s.body}');
      if (!matchesAll(norm)) continue;
      final nl = norm.indexOf('\n');
      final titleHit = nl > 0 && matchesAll(norm.substring(0, nl));
      hits.add(SearchHit(
        document: doc,
        sectionIndex: i,
        snippet: _snippet(s.body, normalizeArabic(s.body), terms.first),
        score: titleHit ? 50 : 10,
      ));
      if (hits.length > limit * 5) break;
    }
  }
  // Stable: equal scores keep library order (laws before model regulations).
  final order = {for (var i = 0; i < hits.length; i++) hits[i]: i};
  hits.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : order[a]!.compareTo(order[b]!);
  });
  return hits.take(limit).toList();
}

/// Cuts a short excerpt around the first match. [normalized] has the same
/// length as [original] except for removed diacritics, so we map the offset
/// back conservatively by searching the original with a small window.
String _snippet(String original, String normalized, String term) {
  const radius = 60;
  final idx = normalized.indexOf(term);
  if (idx < 0 || original.length <= radius * 2) {
    return original.length > radius * 2
        ? '${original.substring(0, radius * 2)}…'
        : original;
  }
  final ratio = original.length / normalized.length;
  final center = (idx * ratio).round().clamp(0, original.length);
  final start = (center - radius).clamp(0, original.length);
  final end = (center + radius).clamp(0, original.length);
  return '${start > 0 ? '…' : ''}${original.substring(start, end).replaceAll('\n', ' ')}${end < original.length ? '…' : ''}';
}
