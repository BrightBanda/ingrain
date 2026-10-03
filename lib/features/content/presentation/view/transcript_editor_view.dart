import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/content/data/transcript_parser.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';

class TranscriptEditorView extends ConsumerStatefulWidget {
  final String contentId;

  const TranscriptEditorView({super.key, required this.contentId});

  @override
  ConsumerState<TranscriptEditorView> createState() =>
      _TranscriptEditorViewState();
}

class _TranscriptEditorViewState extends ConsumerState<TranscriptEditorView> {
  final _textController = TextEditingController();
  final _durationController = TextEditingController(text: '0');
  List<TranscriptSentence> _preview = [];
  String _parseError = '';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final sentences = await ref
        .read(contentViewModelProvider.notifier)
        .getTranscript(widget.contentId);
    if (sentences.isNotEmpty) {
      _textController.text = _sentencesToText(sentences);
    }
    setState(() => _preview = sentences);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transcript'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
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
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _parse,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Parse'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                ),
              ],
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
          const Text('Transcript'),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: _parseError.isNotEmpty
                    ? ''
                    : 'Paste SRT, WebVTT, or plain text...',
                border: const OutlineInputBorder(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _preview.isEmpty
              ? const Center(child: Text('No preview'))
              : ListView.builder(
                  itemCount: _preview.length,
                  itemBuilder: (context, index) {
                    final s = _preview[index];
                    return ListTile(
                      leading: CircleClient(text: '${s.startSeconds}s'),
                      title: Text(
                        s.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${s.startSeconds}s - ${s.endSeconds}s',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class CircleClient extends StatelessWidget {
  final String text;
  const CircleClient({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primaryPale,
      child: Text(
        text,
        style: const TextStyle(color: AppColors.primaryMain, fontSize: 10),
      ),
    );
  }
}
