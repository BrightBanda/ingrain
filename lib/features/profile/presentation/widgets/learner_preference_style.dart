import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/features/profile/domain/learner_preferences.dart';

// How each onboarding answer looks: one icon and one accent hue apiece, in the
// app's colour language (see `AppColors`).

extension JlptLevelStyle on JlptLevel {
  Color get color => switch (this) {
    JlptLevel.n5 => AppColors.dialogue,
    JlptLevel.n4 => AppColors.sentences,
    JlptLevel.n3 => AppColors.primaryMain,
    JlptLevel.n2 => AppColors.podcast,
    JlptLevel.n1 => AppColors.vocabulary,
  };
}

extension LearningReasonStyle on LearningReason {
  IconData get icon => switch (this) {
    LearningReason.travel => Icons.flight_takeoff,
    LearningReason.animeManga => Icons.auto_awesome,
    LearningReason.career => Icons.work_outline,
    LearningReason.school => Icons.school_outlined,
    LearningReason.livingInJapan => Icons.home_outlined,
    LearningReason.friends => Icons.people_outline,
    LearningReason.hobby => Icons.palette_outlined,
    LearningReason.media => Icons.live_tv_outlined,
    LearningReason.other => Icons.more_horiz,
  };

  Color get color => switch (this) {
    LearningReason.travel => AppColors.sentences,
    LearningReason.animeManga => AppColors.video,
    LearningReason.career => AppColors.primaryMain,
    LearningReason.school => AppColors.review,
    LearningReason.livingInJapan => AppColors.dialogue,
    LearningReason.friends => AppColors.vocabulary,
    LearningReason.hobby => AppColors.podcast,
    LearningReason.media => AppColors.streak,
    LearningReason.other => AppColors.textSecondary,
  };
}

extension ContentInterestStyle on ContentInterest {
  IconData get icon => switch (this) {
    ContentInterest.anime => Icons.auto_awesome,
    ContentInterest.youtube => Icons.smart_display_outlined,
    ContentInterest.podcasts => Icons.podcasts,
    ContentInterest.music => Icons.music_note_outlined,
    ContentInterest.news => Icons.newspaper_outlined,
    ContentInterest.conversations => Icons.forum_outlined,
    ContentInterest.travel => Icons.luggage_outlined,
    ContentInterest.reading => Icons.menu_book_outlined,
    ContentInterest.gaming => Icons.sports_esports_outlined,
    ContentInterest.culture => Icons.temple_buddhist_outlined,
  };

  Color get color => switch (this) {
    ContentInterest.anime => AppColors.video,
    ContentInterest.youtube => const Color(0xFFE53935),
    ContentInterest.podcasts => AppColors.podcast,
    ContentInterest.music => AppColors.vocabulary,
    ContentInterest.news => AppColors.primaryMain,
    ContentInterest.conversations => AppColors.dialogue,
    ContentInterest.travel => AppColors.sentences,
    ContentInterest.reading => AppColors.review,
    ContentInterest.gaming => AppColors.streak,
    ContentInterest.culture => const Color(0xFFD1495B),
  };
}
