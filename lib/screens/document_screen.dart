import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/library.dart';
import '../services/app_state.dart';
import '../widgets/banner_ad.dart';

class DocumentScreen extends StatefulWidget {
  final Document document;
  final int? initialSection;

  const DocumentScreen({
    super.key,
    required this.document,
    this.initialSection,
  });

  static void open(BuildContext context, Document doc, {int? initialSection}) {
    AppScope.of(context).monetization.onDocumentOpened();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DocumentScreen(document: doc, initialSection: initialSection),
      ),
    );
  }

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  late final List<GlobalKey> _keys =
      List.generate(widget.document.sections.length, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    final i = widget.initialSection;
    if (i != null && i < _keys.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[i].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 300));
        }
      });
    }
  }

  Future<void> _shareFile() async {
    final path = widget.document.file!;
    final data = await rootBundle.load('assets/$path');
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/${path.split('/').last}');
    await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(out.path)],
      subject: widget.document.title,
    ));
  }

  void _shareText() {
    final d = widget.document;
    SharePlus.instance.share(ShareParams(
      text: '${d.title}\n\n${d.fullText}',
      subject: d.title,
    ));
  }

  void _copy(Section s) {
    Clipboard.setData(ClipboardData(text: '${s.title}\n${s.body}'));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم النسخ')));
  }

  void _fontDialog() {
    final settings = AppScope.of(context).settings;
    showModalBottomSheet(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: settings,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('حجم الخط'),
              Slider(
                value: settings.fontScale,
                min: 0.8,
                max: 1.8,
                divisions: 10,
                onChanged: settings.setFontScale,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = widget.document;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(d.title, maxLines: 2),
        actions: [
          ListenableBuilder(
            listenable: app.favorites,
            builder: (_, __) {
              final fav = app.favorites.contains(d.id);
              return IconButton(
                tooltip: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                icon: Icon(fav ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => app.favorites.toggle(d.id),
              );
            },
          ),
          IconButton(
            tooltip: 'حجم الخط',
            icon: const Icon(Icons.format_size),
            onPressed: _fontDialog,
          ),
          IconButton(
            tooltip: 'مشاركة',
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareText,
          ),
        ],
      ),
      bottomNavigationBar: const BannerAdBar(),
      body: ListenableBuilder(
        listenable: app.settings,
        builder: (context, _) {
          final scale = app.settings.fontScale;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(d.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline)),
                  ),
                if (d.file != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.icon(
                      onPressed: _shareFile,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('حفظ / مشاركة النموذج (Word)'),
                    ),
                  ),
                for (var i = 0; i < d.sections.length; i++)
                  Card(
                    key: _keys[i],
                    color: i == widget.initialSection
                        ? theme.colorScheme.primaryContainer
                        : null,
                    child: InkWell(
                      onLongPress: () => _copy(d.sections[i]),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (d.sections[i].title.isNotEmpty)
                              Text(
                                d.sections[i].title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  fontSize: 16 * scale,
                                ),
                              ),
                            const SizedBox(height: 8),
                            SelectableText(
                              d.sections[i].body,
                              style: TextStyle(fontSize: 15 * scale, height: 1.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('اضغط مطولاً على أي فقرة لنسخها',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          );
        },
      ),
    );
  }
}
