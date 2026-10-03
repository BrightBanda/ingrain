import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/app/theme/app_colors.dart';
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

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref
        .read(contentViewModelProvider.notifier)
        .addContent(
          sourceUrl: _urlController.text.trim(),
          title: _titleController.text.trim(),
        );
    if (result != null && mounted) {
      context.go('/content/${result.id}/transcript');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Content'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryPale,
                  child: Icon(
                    Icons.add,
                    size: 40,
                    color: AppColors.primaryMain,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'YouTube URL or ID',
                    hintText: 'https://youtu.be/dQw4w9WgXcQ',
                    border: OutlineInputBorder(),
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
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: AppColors.textOnPrimary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Add Content'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
