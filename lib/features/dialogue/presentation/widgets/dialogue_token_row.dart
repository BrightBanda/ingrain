import 'package:flutter/material.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';

class DialogueTokenRow extends StatelessWidget {
  final DialogueLine line;
  final bool showRomaji;
  final ValueChanged<DialogueToken> onTokenTap;

  const DialogueTokenRow({
    super.key,
    required this.line,
    required this.showRomaji,
    required this.onTokenTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 5,
      runSpacing: 8,
      children: [
        for (final token in line.tokens)
          InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () => onTokenTap(token),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(token.surface, style: theme.textTheme.bodyLarge),
                  if (showRomaji && token.romaji != null)
                    Text(
                      token.romaji!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
