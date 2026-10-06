import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

/// Speakers alternate between the two brand hues.
final _speakerColors = AppColors.heroGradient;

/// A speaker's colour: by their position in [speakers] when known, so
/// neighbouring speakers differ, otherwise by a stable hash.
Color speakerColor(String speaker, [List<String> speakers = const []]) {
  final index = speakers.indexOf(speaker);
  if (index >= 0) return _speakerColors[index % _speakerColors.length];
  var stableHash = 0;
  for (final unit in speaker.codeUnits) {
    stableHash = (stableHash * 31 + unit) & 0x7fffffff;
  }
  return _speakerColors[stableHash % _speakerColors.length];
}

class SpeakerLabel extends StatelessWidget {
  final String speaker;
  final List<String> speakers;

  const SpeakerLabel({
    super.key,
    required this.speaker,
    this.speakers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pill(
        label: speaker,
        color: speakerColor(speaker, speakers),
        solid: true,
      ),
    );
  }
}
