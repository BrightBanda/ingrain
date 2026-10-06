import 'package:flutter/material.dart';
import 'package:ingrain/features/kana/domain/kana_chart.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

/// Hiragana and katakana boards, laid out like Duolingo's: one tile per
/// character with its romaji, grouped into basic, dakuten and combinations.
class KanaView extends StatelessWidget {
  const KanaView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: KanaScript.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kana'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Hiragana  あ'),
              Tab(text: 'Katakana  ア'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _KanaBoard(script: KanaScript.hiragana),
            _KanaBoard(script: KanaScript.katakana),
          ],
        ),
      ),
    );
  }
}

class _KanaBoard extends StatelessWidget {
  final KanaScript script;

  const _KanaBoard({required this.script});

  @override
  Widget build(BuildContext context) {
    final sections = KanaChart.sections(script);
    return ListView(
      key: PageStorageKey(script),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        for (final section in sections) ...[
          SectionHeader('${section.title}  ·  ${section.count}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              section.subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final row in section.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (var i = 0; i < section.columns; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: row[i] == null
                          ? const SizedBox.shrink()
                          : _KanaTile(kana: row[i]!, script: script),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _KanaTile extends StatelessWidget {
  final Kana kana;
  final KanaScript script;

  const _KanaTile({required this.kana, required this.script});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return TintedSurface(
      color: primary,
      alpha: 0.1,
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 10),
      onTap: () => _showDetail(context),
      child: Column(
        children: [
          FittedBox(
            child: Text(
              kana.kana,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kana.romaji,
            style: theme.textTheme.labelMedium?.copyWith(color: primary),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final theme = Theme.of(context);
    final other = script == KanaScript.hiragana
        ? KanaChart.toKatakana(kana.kana)
        : KanaChart.toHiragana(kana.kana);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientPanel(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Text(
                kana.kana,
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(kana.romaji, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              '${script == KanaScript.hiragana ? 'Katakana' : 'Hiragana'}: '
              '$other',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
