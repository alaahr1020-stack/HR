import 'package:flutter/material.dart';

import '../models/library.dart';
import '../services/app_state.dart';
import '../widgets/banner_ad.dart';
import '../widgets/document_tile.dart';

/// Lists a category's groups (e.g. one per law) or, when the category is not
/// grouped, its documents directly.
class CategoryScreen extends StatelessWidget {
  final Category category;

  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final lib = AppScope.of(context).library;
    final docs = lib.inCategory(category.id);
    final groups = lib.groupsOf(category.id);
    final ungrouped = docs.where((d) => d.group == null).toList();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      bottomNavigationBar: const BannerAdBar(),
      body: docs.isEmpty
          ? const Center(child: Text('لا يوجد محتوى في هذا القسم بعد'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final d in ungrouped) DocumentTile(document: d),
                for (final g in groups)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.folder_outlined,
                          color: scheme.primary),
                      title: Text(g,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${docs.where((d) => d.group == g).length} عنصر'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupScreen(
                            title: g,
                            documents:
                                docs.where((d) => d.group == g).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class GroupScreen extends StatelessWidget {
  final String title;
  final List<Document> documents;

  const GroupScreen({super.key, required this.title, required this.documents});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: const BannerAdBar(),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: documents.length,
        itemBuilder: (_, i) => DocumentTile(document: documents[i]),
      ),
    );
  }
}
