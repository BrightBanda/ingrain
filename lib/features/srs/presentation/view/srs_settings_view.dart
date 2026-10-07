import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/srs/domain/srs_settings.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

/// Anki's deck options, applied to every deck.
class SrsSettingsView extends ConsumerWidget {
  const SrsSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(srsSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard settings'),
        actions: [
          TextButton(
            onPressed: () => _confirmReset(context, ref),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load: $error')),
        data: (s) => _SettingsList(settings: s),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Anki defaults?'),
        content: const Text(
          '20 new cards a day, steps 1m 10m, graduating interval 1 day, '
          'starting ease 250%, and the rest of Anki\'s defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(srsSettingsProvider.notifier).resetToDefaults();
    }
  }
}

class _SettingsList extends ConsumerWidget {
  final SrsSettings settings;

  const _SettingsList({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    void save(SrsSettings next) =>
        ref.read(srsSettingsProvider.notifier).save(next);

    String percent(double value) => '${(value * 100).round()}%';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const SectionHeader('Daily limits'),
        Card(
          child: Column(
            children: [
              _NumberTile(
                title: 'New cards per day',
                subtitle: 'How many unseen cards each deck introduces a day',
                value: s.newCardsPerDay,
                display: '${s.newCardsPerDay}',
                max: 9999,
                onSaved: (v) => save(s.copyWith(newCardsPerDay: v)),
              ),
              _NumberTile(
                title: 'Maximum reviews per day',
                subtitle:
                    'Reviews shown per deck a day; learning cards are '
                    'never capped',
                value: s.maximumReviewsPerDay,
                display: '${s.maximumReviewsPerDay}',
                max: 99999,
                onSaved: (v) => save(s.copyWith(maximumReviewsPerDay: v)),
              ),
            ],
          ),
        ),
        const SectionHeader('New cards'),
        Card(
          child: Column(
            children: [
              _StepsTile(
                title: 'Learning steps',
                subtitle: 'Delays before a new card graduates, e.g. "1m 10m"',
                steps: s.learningSteps,
                allowEmpty: false,
                onSaved: (v) => save(s.copyWith(learningSteps: v)),
              ),
              _NumberTile(
                title: 'Graduating interval',
                subtitle: 'Days until the first review after the last step',
                value: s.graduatingIntervalDays,
                display: '${s.graduatingIntervalDays}d',
                min: 1,
                max: 365,
                onSaved: (v) => save(s.copyWith(graduatingIntervalDays: v)),
              ),
              _NumberTile(
                title: 'Easy interval',
                subtitle: 'Days until the first review after answering Easy',
                value: s.easyIntervalDays,
                display: '${s.easyIntervalDays}d',
                min: 1,
                max: 365,
                onSaved: (v) => save(s.copyWith(easyIntervalDays: v)),
              ),
            ],
          ),
        ),
        const SectionHeader('Lapses'),
        Card(
          child: Column(
            children: [
              _StepsTile(
                title: 'Relearning steps',
                subtitle: 'Delays before a forgotten card returns to review',
                steps: s.relearningSteps,
                allowEmpty: true,
                onSaved: (v) => save(s.copyWith(relearningSteps: v)),
              ),
              _NumberTile(
                title: 'New interval',
                subtitle:
                    'A forgotten card\'s interval, as a % of the old one '
                    '(0% restarts at 1 day)',
                value: (s.lapseIntervalFactor * 100).round(),
                display: percent(s.lapseIntervalFactor),
                max: 100,
                suffix: '%',
                onSaved: (v) => save(s.copyWith(lapseIntervalFactor: v / 100)),
              ),
            ],
          ),
        ),
        const SectionHeader('Advanced'),
        Card(
          child: Column(
            children: [
              _NumberTile(
                title: 'Starting ease',
                subtitle: 'How fast new cards\' intervals grow',
                value: (s.startingEase * 100).round(),
                display: percent(s.startingEase),
                min: 130,
                max: 500,
                suffix: '%',
                onSaved: (v) => save(s.copyWith(startingEase: v / 100)),
              ),
              _NumberTile(
                title: 'Easy bonus',
                subtitle: 'Extra growth when answering Easy',
                value: (s.easyBonus * 100).round(),
                display: percent(s.easyBonus),
                min: 100,
                max: 500,
                suffix: '%',
                onSaved: (v) => save(s.copyWith(easyBonus: v / 100)),
              ),
              _NumberTile(
                title: 'Hard interval',
                subtitle: 'Growth when answering Hard',
                value: (s.hardIntervalMultiplier * 100).round(),
                display: percent(s.hardIntervalMultiplier),
                min: 100,
                max: 200,
                suffix: '%',
                onSaved: (v) =>
                    save(s.copyWith(hardIntervalMultiplier: v / 100)),
              ),
              _NumberTile(
                title: 'Interval modifier',
                subtitle: 'Scales every interval: lower shows cards sooner',
                value: (s.intervalModifier * 100).round(),
                display: percent(s.intervalModifier),
                min: 50,
                max: 200,
                suffix: '%',
                onSaved: (v) => save(s.copyWith(intervalModifier: v / 100)),
              ),
              _NumberTile(
                title: 'Maximum interval',
                subtitle: 'Cards are never scheduled further away than this',
                value: s.maximumIntervalDays,
                display: '${s.maximumIntervalDays}d',
                min: 1,
                max: 36500,
                onSaved: (v) => save(s.copyWith(maximumIntervalDays: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final String display;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onSaved;

  const _NumberTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.display,
    required this.onSaved,
    this.min = 0,
    this.max = 9999,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Pill(label: display, color: primary, solid: true),
      onTap: () async {
        final result = await showDialog<int>(
          context: context,
          builder: (_) => _NumberDialog(
            title: title,
            initial: value,
            min: min,
            max: max,
            suffix: suffix,
          ),
        );
        if (result != null) onSaved(result);
      },
    );
  }
}

class _NumberDialog extends StatefulWidget {
  final String title;
  final int initial;
  final int min;
  final int max;
  final String suffix;

  const _NumberDialog({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.suffix,
  });

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < widget.min || value > widget.max) {
      setState(
        () => _error = 'Enter a number from ${widget.min} to ${widget.max}',
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          suffixText: widget.suffix.isEmpty ? null : widget.suffix,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _StepsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Duration> steps;
  final bool allowEmpty;
  final ValueChanged<List<Duration>> onSaved;

  const _StepsTile({
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.allowEmpty,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Pill(
        label: steps.isEmpty ? 'none' : StepFormat.format(steps),
        color: primary,
        solid: true,
      ),
      onTap: () async {
        final result = await showDialog<List<Duration>>(
          context: context,
          builder: (_) => _StepsDialog(
            title: title,
            initial: StepFormat.format(steps),
            allowEmpty: allowEmpty,
          ),
        );
        if (result != null) onSaved(result);
      },
    );
  }
}

class _StepsDialog extends StatefulWidget {
  final String title;
  final String initial;
  final bool allowEmpty;

  const _StepsDialog({
    required this.title,
    required this.initial,
    required this.allowEmpty,
  });

  @override
  State<_StepsDialog> createState() => _StepsDialogState();
}

class _StepsDialogState extends State<_StepsDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final steps = StepFormat.parse(_controller.text);
    if (steps == null || (steps.isEmpty && !widget.allowEmpty)) {
      setState(
        () => _error = widget.allowEmpty
            ? 'Use steps like "10m" or "1m 10m 1h", or leave empty'
            : 'Use steps like "1m 10m" or "10m 1h 1d"',
      );
      return;
    }
    Navigator.of(context).pop(steps);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          helperText: 's = seconds, m = minutes, h = hours, d = days',
          errorText: _error,
          errorMaxLines: 2,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
