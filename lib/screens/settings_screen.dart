import 'package:flutter/material.dart';

import '../config.dart';
import '../services/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final m = app.monetization;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        m.purchased ? Icons.verified : Icons.block,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        m.purchased
                            ? 'النسخة الكاملة مفعّلة — بدون إعلانات'
                            : 'إزالة الإعلانات',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (!m.purchased) ...[
                        Text(
                          m.inTrial
                              ? 'أنت الآن في الفترة التجريبية المجانية بدون إعلانات '
                                  '(متبقي ${m.trialDaysLeft} يوم من ${AppConfig.trialDays}).'
                              : 'انتهت الفترة التجريبية. التطبيق مجاني بالكامل مع إعلانات.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ادفع مرة واحدة فقط ${m.price} وتخلّص من الإعلانات للأبد.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: m.busy ? null : m.buyRemoveAds,
                          child: m.busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : Text('شراء بـ ${m.price}'),
                        ),
                        TextButton(
                          onPressed: m.busy ? null : m.restore,
                          child: const Text('استعادة عملية شراء سابقة'),
                        ),
                        if (m.lastError != null)
                          Text(m.lastError!,
                              style:
                                  TextStyle(color: theme.colorScheme.error)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: app.settings,
                builder: (_, __) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('حجم خط القراءة'),
                        Slider(
                          value: app.settings.fontScale,
                          min: 0.8,
                          max: 1.8,
                          divisions: 10,
                          onChanged: app.settings.setFontScale,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('تنبيه'),
                  subtitle: Text(
                      'المحتوى للاسترشاد فقط، ويُرجع دائماً للنصوص الرسمية '
                      'للقوانين والقرارات الوزارية السارية.'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
