import 'package:flutter/material.dart';

import '../models/library.dart';
import '../screens/document_screen.dart';

class DocumentTile extends StatelessWidget {
  final Document document;
  final String? subtitle;
  final int? sectionIndex;

  const DocumentTile({
    super.key,
    required this.document,
    this.subtitle,
    this.sectionIndex,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subtitle ??
        (document.summary == document.group ? '' : document.summary);
    return Card(
      child: ListTile(
        leading: Icon(
          document.file != null
              ? Icons.description_outlined
              : Icons.article_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(document.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: sub.isEmpty
            ? null
            : Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => DocumentScreen.open(context, document,
            initialSection: sectionIndex),
      ),
    );
  }
}
