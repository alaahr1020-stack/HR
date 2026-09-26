import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';

import '../models/library.dart';
import '../services/app_state.dart';
import '../services/search.dart';
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
  final _scroll = ItemScrollController();
  bool _searching = false;
  String _query = '';

  Document get _doc => widget.document;

  /// Sections to show: all of them, or only in-document search matches.
  List<int> get _visible => _query.trim().isEmpty
      ? List.generate(_doc.sections.length, (i) => i)
      : searchInDocument(_doc, _query);

  Future<void> _shareFile() async {
    final path = _doc.file!;
    final data = await rootBundle.load('assets/$path');
    final dir = await getTemporaryDirectory();
    final ext = path.split('.').last;
    final safeName = _doc.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    final out = File('${dir.path}/$safeName.$ext');
    await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(out.path)],
      subject: _doc.title,
    ));
  }

  void _shareText() {
    final text = '${_doc.title}\n\n${_doc.fullText}';
    // Very long laws are shared as their first part only; messaging apps
    // truncate huge texts anyway.
    SharePlus.instance.share(ShareParams(
      text: text.length > 60000 ? '${text.substring(0, 60000)}…' : text,
      subject: _doc.title,
    ));
  }

  void _copy(Section s) {
    Clipboard.setData(ClipboardData(text: '${s.title}\n${s.body}'));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم النسخ')));
  }

  void _shareSection(Section s) {
    SharePlus.instance.share(ShareParams(
      text: '${_doc.title}\n${s.title}\n\n${s.body}',
    ));
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

  void _showOutline() {
    final titled = [
      for (var i = 0; i < _doc.sections.length; i++)
        if (_doc.sections[i].title.isNotEmpty) i
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          itemCount: titled.length,
          itemBuilder: (_, k) {
            final i = titled[k];
            final s = _doc.sections[i];
            return ListTile(
              dense: true,
              title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: s.chapter == null ? null : Text(s.chapter!, maxLines: 1),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _searching = false;
                  _query = '';
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.isAttached) _scroll.jumpTo(index: i + 1);
                });
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ابحث في هذا المستند...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(_doc.title, maxLines: 2, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: _searching ? 'إغلاق البحث' : 'بحث في المستند',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
          if (!_searching) ...[
            ListenableBuilder(
              listenable: app.favorites,
              builder: (_, __) {
                final fav = app.favorites.contains(_doc.id);
                return IconButton(
                  tooltip: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  icon: Icon(fav ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () => app.favorites.toggle(_doc.id),
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'outline' => _showOutline(),
                'font' => _fontDialog(),
                _ => _shareText(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'outline', child: Text('فهرس المواد')),
                PopupMenuItem(value: 'font', child: Text('حجم الخط')),
                PopupMenuItem(value: 'share', child: Text('مشاركة النص')),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: const BannerAdBar(),
      body: ListenableBuilder(
        listenable: app.settings,
        builder: (context, _) {
          final scale = app.settings.fontScale;
          return ScrollablePositionedList.builder(
            itemScrollController: _scroll,
            initialScrollIndex: _query.isEmpty &&
                    widget.initialSection != null &&
                    widget.initialSection! < _doc.sections.length
                ? widget.initialSection! + 1
                : 0,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: visible.length + 2,
            itemBuilder: (context, k) {
              if (k == 0) return _header(theme, visible.length);
              if (k == visible.length + 1) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('اضغط مطولاً على أي فقرة لنسخها أو مشاركتها',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                );
              }
              final i = visible[k - 1];
              return _SectionCard(
                section: _doc.sections[i],
                highlighted: i == widget.initialSection,
                scale: scale,
                onCopy: () => _copy(_doc.sections[i]),
                onShare: () => _shareSection(_doc.sections[i]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _header(ThemeData theme, int visibleCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_searching && _query.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              visibleCount == 0 ? 'لا توجد نتائج' : '$visibleCount نتيجة',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        if (!_searching && _doc.note != null)
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: theme.colorScheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_doc.note!,
                        style: TextStyle(
                            color: theme.colorScheme.onTertiaryContainer)),
                  ),
                ],
              ),
            ),
          ),
        if (!_searching && _doc.file != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: _shareFile,
              icon: const Icon(Icons.download_outlined),
              label: Text(_doc.file!.endsWith('.xlsx')
                  ? 'حفظ / مشاركة الملف (Excel)'
                  : 'حفظ / مشاركة النموذج (Word)'),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Section section;
  final bool highlighted;
  final double scale;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _SectionCard({
    required this.section,
    required this.highlighted,
    required this.scale,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section.chapter != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
            child: Text(
              section.chapter!,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Card(
          color: highlighted ? theme.colorScheme.primaryContainer : null,
          child: InkWell(
            onLongPress: () => showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Wrap(children: [
                  ListTile(
                    leading: const Icon(Icons.copy),
                    title: const Text('نسخ'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onCopy();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: const Text('مشاركة'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onShare();
                    },
                  ),
                ]),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (section.title.isNotEmpty) ...[
                    Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 16 * scale,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    section.body,
                    style: TextStyle(fontSize: 15 * scale, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
