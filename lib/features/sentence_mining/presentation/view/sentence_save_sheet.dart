import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

class SentenceSaveRequest {
  final String japanese;
  final String? translation;
  final String? explanation;

  const SentenceSaveRequest({
    required this.japanese,
    this.translation,
    this.explanation,
  });
}

/// Shared save form used both when mining a transcript line and when adding a
/// sentence by hand. Pops a [SentenceSaveRequest] on confirm.
class SentenceSaveSheet extends StatefulWidget {
  final String title;
  final String japanese;
  final String? translation;
  final String? explanation;
  final bool japaneseEditable;
  final String? contextLabel;

  const SentenceSaveSheet({
    super.key,
    required this.title,
    required this.japanese,
    this.translation,
    this.explanation,
    this.japaneseEditable = false,
    this.contextLabel,
  });

  @override
  State<SentenceSaveSheet> createState() => _SentenceSaveSheetState();
}

class _SentenceSaveSheetState extends State<SentenceSaveSheet> {
  late final TextEditingController _japaneseController;
  late final TextEditingController _translationController;
  late final TextEditingController _explanationController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _japaneseController = TextEditingController(text: widget.japanese);
    _translationController = TextEditingController(text: widget.translation);
    _explanationController = TextEditingController(text: widget.explanation);
  }

  @override
  void dispose() {
    _japaneseController.dispose();
    _translationController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  void _submit() {
    final japanese = _japaneseController.text.trim();
    if (japanese.isEmpty) {
      setState(() => _errorText = 'Japanese text is required');
      return;
    }
    Navigator.of(context).pop(
      SentenceSaveRequest(
        japanese: japanese,
        translation: _nullable(_translationController.text),
        explanation: _nullable(_explanationController.text),
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
              if (widget.contextLabel != null) ...[
                const SizedBox(height: 8),
                _ContextBox(label: widget.contextLabel!),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _japaneseController,
                readOnly: !widget.japaneseEditable,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Japanese',
                  helperText: widget.japaneseEditable
                      ? 'Required'
                      : 'Taken from the transcript',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _translationController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Translation (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _explanationController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Explanation / notes (optional)',
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
                style: accentButtonStyle(AppColors.primaryMain),
                onPressed: _submit,
                icon: const Icon(Icons.bookmark_add),
                label: const Text('Save sentence'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextBox extends StatelessWidget {
  final String label;

  const _ContextBox({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryMain.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.5),
      ),
    );
  }
}
