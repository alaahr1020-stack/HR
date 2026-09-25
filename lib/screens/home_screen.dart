import 'package:flutter/material.dart';

import '../config.dart';
import '../models/library.dart';
import '../services/app_state.dart';
import '../widgets/banner_ad.dart';
import '../widgets/document_tile.dart';
import 'category_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final lib = app.library;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      bottomNavigationBar: const BannerAdBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SearchBox(),
          const SizedBox(height: 12),
          const _PlanBanner(),
          const SizedBox(height: 8),
          Text('الأقسام', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final c in lib.categories) _CategoryCard(category: c),
          ListenableBuilder(
            listenable: app.favorites,
            builder: (context, _) {
              final favs = app.favorites.ids
                  .map(lib.document)
                  .whereType<Document>()
                  .toList();
              if (favs.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text('المفضلة',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final d in favs) DocumentTile(document: d),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SearchScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.search, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text('ابحث عن مادة، جزاء، إجراء، نموذج...',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanBanner extends StatelessWidget {
  const _PlanBanner();

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context).monetization;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        if (m.purchased) return const SizedBox.shrink();
        final text = m.inTrial
            ? 'فترة تجريبية بدون إعلانات: متبقي ${m.trialDaysLeft} يوم'
            : 'أزل الإعلانات للأبد بدفعة واحدة ${m.price}';
        return Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: ListTile(
            leading: Icon(m.inTrial ? Icons.hourglass_bottom : Icons.block),
            title: Text(text),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final count = AppScope.of(context).library.inCategory(category.id).length;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(category.icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(category.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(category.description.isEmpty
            ? '$count عنصر'
            : '${category.description} • $count عنصر'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CategoryScreen(category: category)),
        ),
      ),
    );
  }
}
