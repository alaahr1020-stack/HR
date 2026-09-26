import 'package:flutter/material.dart';

class Category {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const Category({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  static const _icons = <String, IconData>{
    'gavel': Icons.gavel,
    'rule': Icons.rule,
    'policy': Icons.policy,
    'warning': Icons.report_problem_outlined,
    'forms': Icons.description_outlined,
    'steps': Icons.account_tree_outlined,
    'book': Icons.menu_book_outlined,
  };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        icon: _icons[j['icon']] ?? Icons.folder_outlined,
      );
}

class Section {
  final String title;
  final String body;

  /// Enclosing chapter (e.g. "الباب الأول › الفصل الثاني"), set on the first
  /// section of each chapter only.
  final String? chapter;

  Section({required this.title, required this.body, this.chapter});

  /// Search-normalized "title body", computed once on first search.
  String? normalized;

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        chapter: j['chapter'] as String?,
      );
}

class Document {
  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final String? group;

  /// Caveat shown above the text (e.g. OCR-extracted content).
  final String? note;
  final List<Section> sections;

  /// Optional attached file (e.g. a Word form) under assets/forms/.
  final String? file;

  Document({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.sections,
    this.group,
    this.note,
    this.file,
  });

  String? normalizedTitle;

  factory Document.fromJson(Map<String, dynamic> j) => Document(
        id: j['id'] as String,
        categoryId: j['category'] as String,
        title: j['title'] as String,
        summary: (j['summary'] ?? '') as String,
        sections: ((j['sections'] ?? []) as List)
            .map((s) => Section.fromJson(s as Map<String, dynamic>))
            .toList(),
        group: j['group'] as String?,
        note: j['note'] as String?,
        file: j['file'] as String?,
      );

  String get fullText =>
      sections.map((s) => '${s.title}\n${s.body}').join('\n\n');
}

class Library {
  final List<Category> categories;
  final List<Document> documents;

  const Library({required this.categories, required this.documents});

  factory Library.fromJson(Map<String, dynamic> j) => Library(
        categories: (j['categories'] as List)
            .map((c) => Category.fromJson(c as Map<String, dynamic>))
            .toList(),
        documents: (j['documents'] as List)
            .map((d) => Document.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  List<Document> inCategory(String id) =>
      documents.where((d) => d.categoryId == id).toList();

  /// Groups of a category in first-appearance order; empty when the
  /// category's documents are not grouped.
  List<String> groupsOf(String categoryId) {
    final seen = <String>{};
    for (final d in documents) {
      if (d.categoryId == categoryId && d.group != null) seen.add(d.group!);
    }
    return seen.toList();
  }

  Category? category(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Document? document(String id) {
    for (final d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }
}
