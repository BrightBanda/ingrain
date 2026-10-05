import 'package:flutter/material.dart';

class SpeakerLabel extends StatelessWidget {
  final String speaker;

  const SpeakerLabel({super.key, required this.speaker});

  @override
  Widget build(BuildContext context) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.secondary,
    ];
    var stableHash = 0;
    for (final unit in speaker.codeUnits) {
      stableHash = (stableHash * 31 + unit) & 0x7fffffff;
    }
    final color = colors[stableHash % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        speaker,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}
