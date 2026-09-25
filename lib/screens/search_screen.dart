import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../services/search.dart';
import '../widgets/banner_ad.dart';
import '../widgets/document_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final hits = search(app.library, _query);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اكتب كلمة البحث...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      bottomNavigationBar: const BannerAdBar(),
      body: _query.trim().isEmpty
          ? const _Hint()
          : hits.isEmpty
              ? const Center(child: Text('لا توجد نتائج'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: hits.length,
                  itemBuilder: (_, i) {
                    final h = hits[i];
                    final section = h.sectionIndex == null
                        ? null
                        : h.document.sections[h.sectionIndex!].title;
                    final cat =
                        app.library.category(h.document.categoryId)?.title;
                    return DocumentTile(
                      document: h.document,
                      sectionIndex: h.sectionIndex,
                      subtitle: [
                        if (cat != null) cat,
                        if (section != null && section.isNotEmpty) section,
                        if (h.snippet.isNotEmpty) h.snippet,
                      ].join(' • '),
                    );
                  },
                ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'ابحث في كل التشريعات واللوائح والإجراءات والنماذج.\n'
        'أمثلة: "إنذار كتابي"، "إجازة سنوية"، "غياب"، "استقالة"',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
