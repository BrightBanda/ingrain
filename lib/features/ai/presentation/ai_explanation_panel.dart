import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/ai/domain/ai_explanation.dart';
import 'package:ingrain/features/ai/presentation/ai_explanation_providers.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

/// "Explain with AI" for a tapped word or sentence.
///
/// Starts as a button: a request costs provider quota, so nothing is sent
/// until the learner asks.
class AiExplanationPanel extends ConsumerStatefulWidget {
  final ExplainRequest request;

  const AiExplanationPanel({super.key, required this.request});

  @override
  ConsumerState<AiExplanationPanel> createState() => _AiExplanationPanelState();
}

class _AiExplanationPanelState extends ConsumerState<AiExplanationPanel> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    if (!_requested) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _requested = true),
        icon: const Icon(Icons.auto_awesome),
        label: Text(
          widget.request.kind == ExplainKind.word
              ? 'Explain with AI'
              : 'Explain sentence with AI',
        ),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    return TintedSurface(
      color: primary,
      alpha: 0.08,
      radius: 16,
      child: ref
          .watch(aiExplanationProvider(widget.request))
          .when(
            // A retry refreshes the provider; by default `when` would keep
            // showing the old error until the new answer lands, so the button
            // would look dead. Show the spinner instead.
            skipLoadingOnRefresh: false,
            loading: () => const _Loading(),
            error: (error, _) => _Failure(
              message: error is AiExplanationException
                  ? error.message
                  : 'The AI could not answer. Try again.',
              onRetry: () =>
                  ref.invalidate(aiExplanationProvider(widget.request)),
            ),
            data: (explanation) => AiExplanationContent(
              explanation: explanation,
              kind: widget.request.kind,
            ),
          ),
    );
  }
}

/// The answer itself, shown inside the panel.
class AiExplanationContent extends StatelessWidget {
  final AiExplanation explanation;
  final ExplainKind kind;

  const AiExplanationContent({
    super.key,
    required this.explanation,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final reading = explanation.reading;
    final pos = explanation.partOfSpeech;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: primary),
            const SizedBox(width: 6),
            Text(
              'AI explanation',
              style: theme.textTheme.labelLarge?.copyWith(color: primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          explanation.translation,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (reading != null && kind == ExplainKind.word)
              Pill(label: reading, color: primary),
            if (pos != null) Pill(label: pos, color: primary),
            if (explanation.formality.isNotEmpty)
              Pill(
                label: explanation.formality,
                icon: Icons.record_voice_over,
                color: primary,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(explanation.meaning, style: theme.textTheme.bodyMedium),
        if (explanation.grammar.isNotEmpty) ...[
          const _Heading('Grammar'),
          for (final point in explanation.grammar)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${point.point}  ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: point.explanation),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
        if (explanation.nuance.isNotEmpty) ...[
          const _Heading('Nuance'),
          Text(explanation.nuance, style: theme.textTheme.bodyMedium),
        ],
        if (explanation.alternatives.isNotEmpty) ...[
          const _Heading('Other natural ways to say it'),
          for (final alternative in explanation.alternatives)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alternative.japanese,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(alternative.note, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 12),
      Text('Asking the AI…', style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _Failure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _Failure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
      const SizedBox(width: 10),
      Expanded(
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
      TextButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}
