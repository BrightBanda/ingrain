import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/immersion/domain/immersion_session.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/progress/presentation/viewmodel/progress_view_model.dart';

/// Counts the time spent on [child] as immersion.
///
/// The session starts when the screen opens and is saved when it closes;
/// while the app is in the background the clock pauses (the session view
/// model follows the app lifecycle). Video uses the player's own play/pause
/// instead, since there time should only run while the video plays.
class ImmersionSessionScope extends ConsumerStatefulWidget {
  /// Distinct per source, so two screens never share one session.
  final String sourceId;
  final String sourceTitle;
  final ActivityType activityType;
  final Widget child;

  const ImmersionSessionScope({
    super.key,
    required this.sourceId,
    required this.sourceTitle,
    required this.activityType,
    required this.child,
  });

  @override
  ConsumerState<ImmersionSessionScope> createState() =>
      _ImmersionSessionScopeState();
}

class _ImmersionSessionScopeState extends ConsumerState<ImmersionSessionScope> {
  // Kept from initState: dispose must not depend on ref.
  late final ImmersionSessionViewModel _session = ref.read(
    immersionSessionViewModelProvider(widget.sourceId).notifier,
  );
  late final ProviderContainer _container = ProviderScope.containerOf(
    context,
    listen: false,
  );

  /// Starting is async; stopping waits for it, so a screen closed straight
  /// away never leaves a session ticking.
  Future<void>? _starting;

  @override
  void initState() {
    super.initState();
    _container; // Resolve now, while the context is still mounted.
    // After the first frame: starting changes provider state, which is not
    // allowed while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _starting = _session
          .startSession(
            sourceTitle: widget.sourceTitle,
            activityType: widget.activityType,
          )
          // Timing is a bonus: if the session cannot be saved (offline, say)
          // the screen still works, the minutes just go uncounted.
          .catchError((Object _) {});
    });
  }

  @override
  void dispose() {
    // Once saved, refresh the totals so Home and Profile show the new minutes.
    _starting
        ?.whenComplete(_session.stopSession)
        .whenComplete(() => _container.invalidate(progressViewModelProvider));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
