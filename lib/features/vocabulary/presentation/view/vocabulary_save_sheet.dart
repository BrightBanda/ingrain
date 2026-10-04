import 'package:flutter/material.dart';

class VocabularySaveRequest {
  final String word;
  final String? reading;
  final String? meaning;
  final String? pos;

  const VocabularySaveRequest({
    required this.word,
    this.reading,
    this.meaning,
    this.pos,
  });
}

/// Save form for a tapped word, pre-filled from the dictionary. Pops a
/// [VocabularySaveRequest] so the caller owns the save.
class VocabularySaveSheet extends StatefulWidget {
  final String title;
  final String word;
  final String? reading;
  final String? meaning;
  final String? pos;
  final String? contextLabel;
  final bool wordEditable;

  const VocabularySaveSheet({
    super.key,
    required this.title,
    required this.word,
    this.reading,
    this.meaning,
    this.pos,
    this.contextLabel,
    this.wordEditable = false,
  });

  @override
  State<VocabularySaveSheet> createState() => _VocabularySaveSheetState();
}

class _VocabularySaveSheetState extends State<VocabularySaveSheet> {
  late final TextEditingController _wordController;
  late final TextEditingController _readingController;
  late final TextEditingController _meaningController;
  late final TextEditingController _posController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.word);
    _readingController = TextEditingController(text: widget.reading);
    _meaningController = TextEditingController(text: widget.meaning);
    _posController = TextEditingController(text: widget.pos);
  }

  @override
  void dispose() {
    _wordController.dispose();
    _readingController.dispose();
    _meaningController.dispose();
    _posController.dispose();
    super.dispose();
  }

  void _submit() {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      setState(() => _errorText = 'Word is required');
      return;
    }
    Navigator.of(context).pop(
      VocabularySaveRequest(
        word: word,
        reading: _nullable(_readingController.text),
        meaning: _nullable(_meaningController.text),
        pos: _nullable(_posController.text),
      ),
    );
  }

  static String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _wordController,
                readOnly: !widget.wordEditable,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Word',
                  border: const OutlineInputBorder(),
                  helperText: widget.wordEditable
                      ? 'Required'
                      : 'Taken from the transcript',
                ),
              ),
              if (widget.contextLabel != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.contextLabel!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _readingController,
                decoration: const InputDecoration(
                  labelText: 'Reading (kana)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _posController,
                decoration: const InputDecoration(
                  labelText: 'Word type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _meaningController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Meaning',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.bookmark_add),
                label: const Text('Save word'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
