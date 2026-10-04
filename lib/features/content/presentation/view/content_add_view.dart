import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/features/content/data/youtube_transcript_fetcher.dart';
import 'package:ingrain/features/content/data/youtube_url_parser.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';

class ContentAddView extends ConsumerStatefulWidget {
  const ContentAddView({super.key});

  @override
  ConsumerState<ContentAddView> createState() => _ContentAddViewState();
}

class _ContentAddViewState extends ConsumerState<ContentAddView> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isFetching = false;
  String? _fetchError;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final url = _urlController.text.trim();
    final title = _titleController.text.trim();

    final videoId = YoutubeUrlParser.tryParse(url);
    if (videoId == null) {
      setState(() {
        _fetchError = 'Invalid YouTube URL or video ID. Please check the link.';
      });
      return;
    }

    setState(() {
      _isFetching = true;
      _fetchError = null;
    });

    try {
      final fetcher = ref.read(youtubeTranscriptFetcherProvider);
      final result = await fetcher.fetch(videoId);

      if (!mounted) return;

      final contentItem = await ref
          .read(contentViewModelProvider.notifier)
          .addContentWithTranscript(
            sourceUrl: url,
            title: title,
            durationSeconds: result.durationSeconds,
            transcriptText: result.transcriptText ?? '',
          );

      if (contentItem != null && mounted) {
        context.go(
          '/content/${contentItem.id}/transcript',
          extra: {
            'transcript': result.transcriptText ?? '',
            'duration': result.durationSeconds,
          },
        );
      }
    } on YoutubeTranscriptException catch (e) {
      // Auto-fetch failed, fall back to manual entry
      if (!mounted) return;
      setState(() {
        _fetchError = 'Auto-fetch failed: ${e.message}. You can add manually.';
      });
      final result = await ref
          .read(contentViewModelProvider.notifier)
          .addContent(sourceUrl: url, title: title);
      if (result != null && mounted) {
        context.go('/content/${result.id}/transcript');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Content')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.video_library_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'YouTube URL or ID',
                    hintText: 'https://youtu.be/dQw4w9WgXcQ',
                    prefixIcon: Icon(Icons.link),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter a YouTube URL or video ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter a title';
                    }
                    return null;
                  },
                ),
                if (_fetchError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.shade700.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fetchError!,
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isFetching ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isFetching
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Fetching transcript...'),
                          ],
                        )
                      : const Text('Add Content'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
