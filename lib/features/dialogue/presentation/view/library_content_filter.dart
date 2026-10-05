import 'package:flutter/material.dart';

enum LibraryContentFilter { videos, dialogues }

class LibraryContentFilterControl extends StatelessWidget {
  final LibraryContentFilter selected;
  final ValueChanged<LibraryContentFilter> onChanged;

  const LibraryContentFilterControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LibraryContentFilter>(
      segments: const [
        ButtonSegment(
          value: LibraryContentFilter.videos,
          label: Text('Videos'),
          icon: Icon(Icons.smart_display_outlined),
        ),
        ButtonSegment(
          value: LibraryContentFilter.dialogues,
          label: Text('Dialogues'),
          icon: Icon(Icons.forum_outlined),
        ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
