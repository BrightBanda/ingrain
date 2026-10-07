import 'package:flutter/material.dart';
import 'package:ingrain/features/profile/domain/avatar_character.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';
import 'package:ingrain/features/profile/presentation/widgets/avatar_painter.dart';
import 'package:ingrain/features/profile/presentation/widgets/learner_avatar.dart';
import 'package:ingrain/features/profile/presentation/widgets/learner_preference_style.dart';

// The pickers behind onboarding and profile editing. Each is a plain widget
// driven by its `selected` value and an `onChanged` callback; the state lives in
// the caller's view model.

/// A tile that lights up in its accent colour when selected.
class SelectableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const SelectableTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? color : color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(height: 1.2),
                    ),
                  ),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Icon(Icons.check_circle, color: color, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [children] out two to a row (one on very narrow screens).
class _TwoColumns extends StatelessWidget {
  final List<Widget> children;

  const _TwoColumns({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 320 ? 1 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class ReasonPicker extends StatelessWidget {
  final Set<LearningReason> selected;
  final ValueChanged<LearningReason> onToggle;

  const ReasonPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _TwoColumns(
      children: [
        for (final reason in LearningReason.values)
          SelectableTile(
            icon: reason.icon,
            label: reason.label,
            color: reason.color,
            selected: selected.contains(reason),
            onTap: () => onToggle(reason),
          ),
      ],
    );
  }
}

class InterestPicker extends StatelessWidget {
  final Set<ContentInterest> selected;
  final ValueChanged<ContentInterest> onToggle;

  const InterestPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _TwoColumns(
      children: [
        for (final interest in ContentInterest.values)
          SelectableTile(
            icon: interest.icon,
            label: interest.label,
            color: interest.color,
            selected: selected.contains(interest),
            onTap: () => onToggle(interest),
          ),
      ],
    );
  }
}

/// Five bars, filled up to the level: a quick visual of how advanced it is.
class LevelBars extends StatelessWidget {
  final JlptLevel level;
  final Color? color;
  final double height;

  const LevelBars({
    super.key,
    required this.level,
    this.color,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    final fill = color ?? level.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final step in JlptLevel.values)
          Container(
            margin: const EdgeInsets.only(right: 2),
            width: height * 0.28,
            height: height * (0.4 + 0.15 * step.index),
            decoration: BoxDecoration(
              color: step.index <= level.index
                  ? fill
                  : fill.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// The five JLPT levels with plain-language descriptions, plus "I'm not sure".
class LevelPicker extends StatelessWidget {
  final JlptLevel? selected;

  /// True when the learner chose "I'm not sure" (and so got [JlptLevel.fallback]).
  final bool unsure;
  final ValueChanged<JlptLevel> onSelect;

  /// Offers "I'm not sure" when set. Onboarding offers it; editing does not.
  final VoidCallback? onUnsure;

  const LevelPicker({
    super.key,
    required this.selected,
    this.unsure = false,
    required this.onSelect,
    this.onUnsure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final level in JlptLevel.values) ...[
          _LevelCard(
            level: level,
            selected: !unsure && selected == level,
            onTap: () => onSelect(level),
          ),
          const SizedBox(height: 10),
        ],
        if (onUnsure case final onUnsure?)
          _UnsureCard(selected: unsure, onTap: onUnsure),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: unsure
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: JlptLevel.fallback.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: JlptLevel.fallback.color,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No problem! We’ll start you at '
                            '${JlptLevel.fallback.code} '
                            '(${JlptLevel.fallback.title}). You can change your '
                            'level any time from your profile.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final JlptLevel level;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = level.color;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.13)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? color : color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      level.code,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: selected ? Colors.white : color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                level.title,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            LevelBars(level: level),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          level.description,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle, color: color),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsureCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _UnsureCard({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return SelectableTile(
      icon: Icons.help_outline,
      label: 'I’m not sure',
      color: color,
      selected: selected,
      onTap: onTap,
    );
  }
}

/// Every character in a grid, with the chosen one ringed and ticked.
class AvatarPicker extends StatelessWidget {
  final AvatarCharacter? selected;
  final ValueChanged<AvatarCharacter> onSelect;

  const AvatarPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 6 : 4;
        const gap = 12.0;
        final size = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final character in AvatarCharacter.values)
              _AvatarChoice(
                character: character,
                size: size,
                selected: character == selected,
                onTap: () => onSelect(character),
              ),
          ],
        );
      },
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final AvatarCharacter character;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.character,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = theme.colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      label: '${character.name}, ${character.tagline}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          child: Column(
            children: [
              AnimatedScale(
                scale: selected ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size * 0.32),
                        border: Border.all(
                          color: selected ? ring : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: AvatarPortrait(
                        character: character,
                        size: size - 12,
                        rounded: true,
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ring,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                character.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? ring : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chosen character large, with its name and tagline: the avatar step's
/// and the profile editor's showpiece.
class AvatarShowcase extends StatelessWidget {
  final AvatarCharacter character;
  final String? displayName;

  const AvatarShowcase({super.key, required this.character, this.displayName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [character.background, character.accent],
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
            child: AvatarPortrait(
              key: ValueKey(character),
              character: character,
              size: 112,
              rounded: true,
              outlined: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displayName != null && displayName!.trim().isNotEmpty)
                  Text(
                    displayName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF1B1F2E),
                    ),
                  ),
                Text(
                  '${character.name}  ${character.kana}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1B1F2E).withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  character.tagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF1B1F2E).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
