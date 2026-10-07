import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/content/data/transcript_parser.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

/// Review and fix a video's transcript.
///
/// "Lines" shows what the player will show, one line per row, each editable
/// or removable. "Raw text" takes a pasted SRT, WebVTT or plain transcript and
/// turns it into lines.
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

class _TranscriptEditorViewState extends ConsumerState<TranscriptEditorView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _textController = TextEditingController();
  final _durationController = TextEditingController();
  List<TranscriptSentence> _lines = [];
  String? _parseError;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  bool get _fromYoutube =>
      (widget.initialTranscript?.isNotEmpty ?? false) &&
      (widget.initialDuration ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _textController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final initial = widget.initialTranscript;
    final duration = widget.initialDuration ?? 0;
    if (duration > 0) _durationController.text = '$duration';

    if (initial != null && initial.isNotEmpty) {
      _textController.text = initial;
      _parse(switchTab: false);
    } else {
      final existing = await ref
          .read(contentViewModelProvider.notifier)
          .getTranscript(widget.contentId);
      if (!mounted) return;
      _lines = existing;
      _textController.text = TranscriptParser.toSrt(existing);
    }
    if (!mounted) return;
    setState(() => _loading = false);
    // Nothing to review yet: start where the learner pastes.
    if (_lines.isEmpty) _tabs.index = 1;
  }

  void _parse({bool switchTab = true}) {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _parseError = 'Paste a transcript first');
      return;
    }
    try {
      final lines = TranscriptParser.parse(
        text,
        durationSeconds: int.tryParse(_durationController.text) ?? 0,
      );
      setState(() {
        _lines = lines;
        _parseError = lines.isEmpty ? 'No lines found in that text' : null;
        _dirty = true;
      });
      if (switchTab && lines.isNotEmpty) _tabs.animateTo(0);
    } catch (error) {
      setState(() => _parseError = 'Could not read that transcript: $error');
    }
  }

  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final controller = TextEditingController(text: line.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Line at ${formatDuration(Duration(seconds: line.startSeconds))}',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Delete line'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    setState(() {
      final text = result.trim();
      if (text.isEmpty) {
        _lines = [..._lines]..removeAt(index);
      } else {
        _lines = [..._lines]..[index] = line.copyWith(text: text);
      }
      _lines = [for (final (i, l) in _lines.indexed) l.copyWith(index: i)];
      _textController.text = TranscriptParser.toSrt(_lines);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      _tabs.animateTo(1);
      setState(() => _parseError = 'Paste a transcript before saving');
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(contentViewModelProvider.notifier)
        .saveTranscript(widget.contentId, _lines);
    ref.invalidate(transcriptProvider(widget.contentId));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Transcript saved')));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/content/${widget.contentId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Lines (${_lines.length})'),
            const Tab(text: 'Raw text'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_buildLines(), _buildRaw()],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving || _loading ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_dirty ? 'Save transcript' : 'Save'),
          ),
        ),
      ),
    );
  }

  Widget _buildLines() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    if (_lines.isEmpty) {
      return EmptyState(
        icon: Icons.subtitles_off,
        color: primary,
        title: 'No lines yet',
        message: 'Paste a transcript in "Raw text" and it appears here.',
        action: OutlinedButton(
          onPressed: () => _tabs.animateTo(1),
          child: const Text('Paste a transcript'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _lines.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 6),
      itemBuilder: (context, index) {
        if (index == 0) {
          return TintedSurface(
            color: primary,
            alpha: 0.1,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _fromYoutube ? Icons.auto_awesome : Icons.subtitles,
                  size: 18,
                  color: primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _fromYoutube
                        ? 'Fetched from YouTube. Tap a line to fix it.'
                        : 'Tap a line to fix or remove it.',
                    style: theme.textTheme.bodySmall?.copyWith(color: primary),
                  ),
                ),
              ],
            ),
          );
        }
        final line = _lines[index - 1];
        return Card(
          child: InkWell(
            onTap: () => _editLine(index - 1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Pill(
                    label: formatDuration(Duration(seconds: line.startSeconds)),
                    color: primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(line.text, style: theme.textTheme.bodyLarge),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRaw() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paste SRT or WebVTT subtitles to keep their timings, or plain '
            'text with one line per sentence.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _textController,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: '00:00:01,000 --> 00:00:03,000\nこんにちは',
                errorText: _parseError,
                errorMaxLines: 3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Video length (seconds)',
                    helperText: 'Only used for plain text',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _parse,
                icon: const Icon(Icons.format_list_bulleted),
                label: const Text('Make lines'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
