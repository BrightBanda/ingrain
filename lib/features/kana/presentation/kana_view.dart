import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/kana/domain/kana_chart.dart';
import 'package:ingrain/features/kana/domain/kana_knowledge.dart';
import 'package:ingrain/features/kana/presentation/kana_progress_view_model.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

extension KanaKnowledgeStyle on KanaKnowledge {
  Color get color => switch (this) {
    KanaKnowledge.somewhat => AppColors.somewhatKnown,
    KanaKnowledge.known => AppColors.fullyKnown,
  };

  IconData get icon => switch (this) {
    KanaKnowledge.somewhat => Icons.adjust_rounded,
    KanaKnowledge.known => Icons.check_rounded,
  };
}

/// Hiragana and katakana boards, laid out like Duolingo's: one tile per
/// character with its romaji, grouped into basic, dakuten and combinations.
///
/// Learners mark each kana yellow ("somewhat know") or green ("fully know"):
/// long-press a tile to step through the marks, or tap it to choose one.
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

class _KanaBoard extends ConsumerWidget {
  final KanaScript script;

  const _KanaBoard({required this.script});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = KanaChart.sections(script);
    final marks = ref.watch(kanaProgressViewModelProvider).value ?? const {};
    return ListView(
      key: PageStorageKey(script),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _ProgressCard(tally: tallyKana(sections, marks)),
        for (final section in sections) ...[
          SectionHeader(
            '${section.title}  ·  ${section.count}',
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          ),
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
                          : _KanaTile(
                              kana: row[i]!,
                              script: script,
                              knowledge: marks[row[i]!.kana],
                            ),
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

/// How much of this script the learner knows, with the legend.
class _ProgressCard extends StatelessWidget {
  final KanaTally tally;

  const _ProgressCard({required this.tally});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = tally.total == 0 ? 1 : tally.total;
    return TintedSurface(
      color: theme.colorScheme.primary,
      alpha: 0.08,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${tally.known}', style: theme.textTheme.headlineSmall),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'of ${tally.total} fully known',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (tally.known > 0)
                    Expanded(
                      flex: tally.known,
                      child: const ColoredBox(color: AppColors.fullyKnown),
                    ),
                  if (tally.somewhat > 0)
                    Expanded(
                      flex: tally.somewhat,
                      child: const ColoredBox(color: AppColors.somewhatKnown),
                    ),
                  if (total - tally.known - tally.somewhat > 0)
                    Expanded(
                      flex: total - tally.known - tally.somewhat,
                      child: ColoredBox(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegendDot(
                color: AppColors.fullyKnown,
                label: 'Fully know · ${tally.known}',
              ),
              _LegendDot(
                color: AppColors.somewhatKnown,
                label: 'Somewhat · ${tally.somewhat}',
              ),
              Text(
                'Long-press a tile to mark it',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _KanaTile extends ConsumerWidget {
  final Kana kana;
  final KanaScript script;
  final KanaKnowledge? knowledge;

  const _KanaTile({required this.kana, required this.script, this.knowledge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final knowledge = this.knowledge;
    final color = knowledge?.color ?? primary;
    final label = switch (knowledge) {
      null => 'not marked',
      final k => k.label.toLowerCase(),
    };

    return Semantics(
      label: '${kana.kana}, ${kana.romaji}, $label',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: knowledge == null
                ? Colors.transparent
                : color.withValues(alpha: 0.75),
            width: 1.6,
          ),
        ),
        child: Stack(
          children: [
            TintedSurface(
              color: color,
              alpha: knowledge == null ? 0.1 : 0.22,
              radius: 12.5,
              padding: const EdgeInsets.symmetric(vertical: 10),
              onTap: () => _showDetail(context),
              onLongPress: () {
                HapticFeedback.selectionClick();
                _mark(
                  context,
                  ref,
                  () => ref
                      .read(kanaProgressViewModelProvider.notifier)
                      .cycle(kana.kana),
                );
              },
              child: Center(
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: knowledge == null
                            ? primary
                            : HSLColor.fromColor(color)
                                  .withLightness(0.32)
                                  .toColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (knowledge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(knowledge.icon, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _KanaDetailSheet(kana: kana, script: script),
    );
  }
}

Future<void> _mark(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not save that mark. Try again.')),
    );
  }
}

class _KanaDetailSheet extends ConsumerWidget {
  final Kana kana;
  final KanaScript script;

  const _KanaDetailSheet({required this.kana, required this.script});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(
      kanaProgressViewModelProvider.select((marks) => marks.value?[kana.kana]),
    );
    final other = script == KanaScript.hiragana
        ? KanaChart.toKatakana(kana.kana)
        : KanaChart.toHiragana(kana.kana);

    void choose(KanaKnowledge? knowledge) => _mark(
      context,
      ref,
      () => ref
          .read(kanaProgressViewModelProvider.notifier)
          .mark(kana.kana, knowledge),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientPanel(
              colors: current == null
                  ? AppColors.heroGradient
                  : [
                      current.color,
                      Color.lerp(current.color, Colors.black, 0.15)!,
                    ],
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Text(
                kana.kana,
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(kana.romaji, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${script == KanaScript.hiragana ? 'Katakana' : 'Hiragana'}: '
              '$other',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'How well do you know it?',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _KnowledgeOption(
                    label: 'Not set',
                    icon: Icons.remove_circle_outline,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    selected: current == null,
                    onTap: () => choose(null),
                  ),
                ),
                const SizedBox(width: 8),
                for (final knowledge in KanaKnowledge.values) ...[
                  Expanded(
                    child: _KnowledgeOption(
                      label: knowledge.label,
                      icon: knowledge.icon,
                      color: knowledge.color,
                      selected: current == knowledge,
                      onTap: () => choose(knowledge),
                    ),
                  ),
                  if (knowledge != KanaKnowledge.values.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              current?.description ??
                  'No mark yet: pick one when you are ready.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _KnowledgeOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.2 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
