import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ingrain/features/onboarding/presentation/viewmodel/onboarding_view_model.dart';
import 'package:ingrain/features/profile/domain/avatar_character.dart';
import 'package:ingrain/features/profile/presentation/viewmodel/edit_profile_view_model.dart';
import 'package:ingrain/features/profile/presentation/widgets/preference_pickers.dart';
import 'package:ingrain/shared/widgets/colorful.dart';

/// Change anything chosen during onboarding: character, name, level, reasons
/// and interests. Saving a new level or interests refreshes the daily videos.
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ref.read(editProfileViewModelProvider).draft.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await ref.read(editProfileViewModelProvider.notifier).save();
    if (saved && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileViewModelProvider);
    final viewModel = ref.read(editProfileViewModelProvider.notifier);
    final draft = state.draft;
    final character = AvatarCharacter.fromId(draft.avatarId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: state.canSave ? _save : null,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AvatarShowcase(character: character, displayName: draft.displayName),
          const SectionHeader('Character'),
          AvatarPicker(selected: character, onSelect: viewModel.chooseAvatar),
          const SectionHeader('Display name'),
          TextField(
            controller: _name,
            maxLength: OnboardingDraft.maxNameLength,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.badge_outlined),
              errorText: state.nameError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onChanged: viewModel.setDisplayName,
          ),
          const SectionHeader('Japanese level'),
          LevelPicker(selected: draft.level, onSelect: viewModel.selectLevel),
          const SectionHeader('Why you’re learning'),
          ReasonPicker(
            selected: draft.learningReasons.toSet(),
            onToggle: viewModel.toggleReason,
          ),
          const SectionHeader('Interests'),
          InterestPicker(
            selected: draft.interests.toSet(),
            onToggle: viewModel.toggleInterest,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.canSave ? _save : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: state.isSaving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
