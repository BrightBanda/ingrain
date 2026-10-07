import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/profile/domain/avatar_character.dart';
import 'package:ingrain/features/profile/presentation/widgets/avatar_painter.dart';

/// A learner's character on its pastel backdrop.
///
/// The one way an avatar is drawn anywhere in the app, so the character on the
/// profile page, the home greeting and the onboarding picker always match.
class AvatarPortrait extends StatelessWidget {
  final AvatarCharacter character;
  final double size;

  /// Circle by default; a rounded square suits grids and heroes.
  final bool rounded;

  /// A white outline that lifts the avatar off a coloured or gradient surface.
  final bool outlined;

  const AvatarPortrait({
    super.key,
    required this.character,
    this.size = 48,
    this.rounded = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = character.background;
    final radius = BorderRadius.circular(size * 0.3);
    return Semantics(
      label: '${character.name} avatar',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: rounded ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: rounded ? radius : null,
          border: outlined
              ? Border.all(color: Colors.white, width: size * 0.045)
              : null,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(background, Colors.white, 0.35)!, background],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(painter: AvatarPainter(character)),
      ),
    );
  }
}

/// The signed-in learner's own avatar, kept in step with their profile.
class LearnerAvatar extends ConsumerWidget {
  final double size;
  final bool rounded;
  final bool outlined;

  const LearnerAvatar({
    super.key,
    this.size = 48,
    this.rounded = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarId = ref.watch(
      authViewModelProvider.select((state) => state.profile?.avatarId),
    );
    return AvatarPortrait(
      character: AvatarCharacter.fromId(avatarId),
      size: size,
      rounded: rounded,
      outlined: outlined,
    );
  }
}
