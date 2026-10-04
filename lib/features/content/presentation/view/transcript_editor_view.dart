import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/features/content/data/transcript_parser.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';

class TranscriptEditorView extends ConsumerStatefulWidget {
  final String contentId;
  final String? initialTranscript;
  final int? initialDuration;

  const TranscriptEditorView({
    super.key,
    required this.contentId,
    this.initialTranscript,
    this.initialDuration,
  });

  @override
  ConsumerState<TranscriptEditorView> createState() =>
      _TranscriptEditorViewState();
}

class _TranscriptEditorViewState extends ConsumerState<TranscriptEditorView> {
  final _textController = TextEditingController();
  final _durationController = TextEditingController(text: '0');
  List<TranscriptSentence> _preview = [];
  String _parseError = '';
  bool _hasAutoFetched = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyInitialValues();
  }

  void _applyInitialValues() {
    if (_hasAutoFetched) return;
    _hasAutoFetched = true;

    if (widget.initialTranscript != null && widget.initialTranscript!.isNotEmpty) {
      _textController.text = widget.initialTranscript!;
    }
    if (widget.initialDuration != null && widget.initialDuration! > 0) {
      _durationController.text = widget.initialDuration.toString();
    }
    // Auto-parse if we have both transcript and duration
    if (widget.initialTranscript != null &&
        widget.initialTranscript!.isNotEmpty &&
        widget.initialDuration != null &&
        widget.initialDuration! > 0) {
      _parse();
    }
  }

  Future<void> _loadExisting() async {
    final sentences = await ref
        .read(contentViewModelProvider.notifier)
        .getTranscript(widget.contentId);
    if (sentences.isNotEmpty) {
      _textController.text = _sentencesToText(sentences);
    }
    if (mounted) {
      setState(() {
        _preview = sentences;
      });
    }
  }

  void _parse() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _preview = [];
        _parseError = 'Enter transcript text';
      });
      return;
    }

    final duration = int.tryParse(_durationController.text) ?? 0;

    try {
      final sentences = TranscriptParser.parse(
        text,
        durationSeconds: duration,
        format: TranscriptFormat.auto,
      );
      setState(() {
        _preview = sentences;
        _parseError = '';
      });
    } catch (e) {
      setState(() {
        _preview = [];
        _parseError = e.toString();
      });
    }
  }

  String _sentencesToText(List<TranscriptSentence> sentences) {
    return sentences.map((s) => s.text).join('\n');
  }

  Future<void> _save() async {
    if (_preview.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parse the transcript first')),
      );
      return;
    }
    await ref
        .read(contentViewModelProvider.notifier)
        .saveTranscript(widget.contentId, _preview);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Transcript saved')));
    if (!mounted) return;
    context.go('/immerse');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transcript'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _parse,
            tooltip: 'Preview',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (seconds)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.tonalIcon(
                  onPressed: _parse,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Parse'),
                ),
              ],
            ),
          ),
          if (widget.initialTranscript != null &&
              widget.initialTranscript!.isNotEmpty &&
              widget.initialDuration != null &&
              widget.initialDuration! > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Transcript auto-fetched from YouTube',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildEditor()),
                const VerticalDivider(width: 1),
                Expanded(child: _buildPreview()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Transcript', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: _parseError.isNotEmpty
                    ? ''
                    : 'Paste SRT, WebVTT, or plain text...',
                errorText: _parseError.isNotEmpty ? _parseError : null,
              ),
              maxLines: null,
              expands: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Preview', style: theme.textTheme.titleMedium),
        ),
        Expanded(
          child: _preview.isEmpty
              ? Center(
                  child: Text(
                    'No preview',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _preview.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = _preview[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${s.startSeconds}s',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
