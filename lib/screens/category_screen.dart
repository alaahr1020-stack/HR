import 'package:flutter/material.dart';

import '../models/library.dart';
import '../services/app_state.dart';
import '../widgets/banner_ad.dart';
import '../widgets/document_tile.dart';

class CategoryScreen extends StatelessWidget {
  final Category category;

  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final docs = AppScope.of(context).library.inCategory(category.id);
    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      bottomNavigationBar: const BannerAdBar(),
      body: docs.isEmpty
          ? const Center(child: Text('لا يوجد محتوى في هذا القسم بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, i) => DocumentTile(document: docs[i]),
            ),
    );
  }
}
