import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/features/content/presentation/view/player/transcript_view.dart';
import 'package:ingrain/features/immersion/domain/session_state.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';

final playbackPositionProvider =
    NotifierProvider<PlaybackPositionNotifier, Duration>(
      PlaybackPositionNotifier.new,
    );

class PlaybackPositionNotifier extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;

  void setPosition(Duration position) {
    state = position;
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerControllerNotifier, YoutubePlayerController?>(
      PlayerControllerNotifier.new,
    );

class PlayerControllerNotifier extends Notifier<YoutubePlayerController?> {
  @override
  YoutubePlayerController? build() => null;

  void setController(YoutubePlayerController? controller) {
    state = controller;
  }
}

class ImmersionPlayerView extends ConsumerStatefulWidget {
  final String contentId;

  const ImmersionPlayerView({super.key, required this.contentId});

  @override
  ConsumerState<ImmersionPlayerView> createState() =>
      _ImmersionPlayerViewState();
}

class _ImmersionPlayerViewState extends ConsumerState<ImmersionPlayerView> {
  late YoutubePlayerController _controller;
  bool _videoLoadStarted = false;
  bool _videoReady = false;
  String? _videoId;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: YoutubePlayerParams(
        showFullscreenButton: true,
        enableKeyboard: false,
        showControls: true,
      ),
    );

    _controller.videoStateStream.listen((state) {
      ref.read(playbackPositionProvider.notifier).setPosition(state.position);
      ref
          .read(immersionSessionViewModelProvider(widget.contentId).notifier)
          .updatePosition(state.position.inSeconds);
    });

    // Set controller in provider after first frame to avoid build-phase modification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(playerControllerProvider.notifier).setController(_controller);
      }
    });
  }

  @override
  void dispose() {
    _controller.close();
    ref.read(playerControllerProvider.notifier).setController(null);
    super.dispose();
  }

  Future<void> _loadVideoIfNeeded(AsyncValue<ContentItem> contentAsync) async {
    final content = contentAsync.asData?.value;
    if (content == null || _videoLoadStarted) return;
    if (content.sourceType != SourceType.youtube) return;

    _videoId = content.id;
    _videoLoadStarted = true;
    setState(() {
      _playerError = null;
      _videoReady = false;
    });

    try {
      await _controller.loadVideoById(videoId: content.id);
    } catch (_) {
      // The bridge waits for the iframe API itself, but it can still time out
      // or fail. Without this the rejection was unhandled and the player just
      // stayed black with no explanation.
      _videoLoadStarted = false;
      if (!mounted) return;
      setState(() => _playerError = 'Could not load this video.');
      return;
    }

    if (!mounted) return;
    setState(() => _videoReady = true);
  }

  /// Re-issues the load command after a failure.
  Future<void> _retryLoad() async {
    final videoId = _videoId;
    if (videoId == null) return;
    setState(() {
      _playerError = null;
      _videoReady = false;
    });

    try {
      await _controller.loadVideoById(videoId: videoId);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _playerError = 'Could not load this video. Please try again.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _videoReady = true);
  }

  Future<void> _seekRelative(int deltaSeconds) async {
    final current = await _controller.currentTime;
    final target = (current + deltaSeconds).clamp(0.0, double.infinity);
    await _controller.seekTo(seconds: target);
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(contentItemProvider(widget.contentId));
    final sessionState = ref.watch(
      immersionSessionViewModelProvider(widget.contentId),
    );
    final sessionVm = ref.read(
      immersionSessionViewModelProvider(widget.contentId).notifier,
    );

    // Load video in post-frame callback to avoid modifying state during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadVideoIfNeeded(contentAsync);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ingrain'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          if (sessionState.isRunning && !sessionState.isPaused)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.circle, color: Colors.green, size: 12),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildPlayer(contentAsync),
          if (_playerError != null) _buildPlayerError(),
          _buildPlaybackControls(),
          _buildSessionControls(contentAsync, sessionState, sessionVm),
          Expanded(child: TranscriptView(contentId: widget.contentId)),
        ],
      ),
    );
  }

  Widget _buildPlayer(AsyncValue<ContentItem> contentAsync) {
    return contentAsync.when(
      data: (content) {
        if (content.sourceType != SourceType.youtube) {
          return _placeholderPlayer('Only YouTube content is supported');
        }
        // The iframe needs a moment to boot before the first frame renders.
        // Without this the player is an unexplained black box on slow
        // connections, which reads as "the video is not starting".
        return Stack(
          children: [
            YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
            if (!_videoReady && _playerError == null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black12,
                  child: const Center(
                    child: SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => _placeholderPlayer('Loading...'),
      error: (_, _) => _placeholderPlayer('Failed to load content'),
    );
  }

  Widget _buildPlayerError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      color: AppColors.primaryPale,
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _playerError!,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(onPressed: _retryLoad, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _placeholderPlayer(String message) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black12,
        child: Center(child: Text(message)),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _controller.playVideo(),
          ),
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () => _controller.pauseVideo(),
          ),
          IconButton(
            icon: const Icon(Icons.replay_10),
            onPressed: () => _seekRelative(-10),
          ),
          IconButton(
            icon: const Icon(Icons.forward_10),
            onPressed: () => _seekRelative(10),
          ),
          DropdownButton<double>(
            value: 1.0,
            items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                .map((v) => DropdownMenuItem(value: v, child: Text('${v}x')))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                _controller.setPlaybackRate(value);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () => _controller.enterFullScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionControls(
    AsyncValue<ContentItem> contentAsync,
    SessionUiState sessionState,
    ImmersionSessionViewModel sessionVm,
  ) {
    final title = contentAsync.whenOrNull(data: (c) => c.title) ?? 'Loading...';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            formatDuration(Duration(seconds: sessionState.elapsedSeconds)),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryMain,
            ),
          ),
          const SizedBox(width: 16),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          if (!sessionState.hasActiveSession)
            ElevatedButton.icon(
              onPressed: () {
                sessionVm.startSession(sourceTitle: title);
                _controller.playVideo();
              },
              icon: const Icon(Icons.play_circle),
              label: const Text('Start Session'),
            ),
          if (sessionState.isRunning && !sessionState.isPaused)
            ElevatedButton.icon(
              onPressed: () {
                sessionVm.pauseSession();
                _controller.pauseVideo();
              },
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            ),
          if (sessionState.isPaused)
            ElevatedButton.icon(
              onPressed: () {
                sessionVm.resumeSession();
                _controller.playVideo();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
          if (sessionState.hasActiveSession)
            TextButton.icon(
              onPressed: () async {
                await sessionVm.stopSession();
                await _controller.pauseVideo();
              },
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
        ],
      ),
    );
  }
}
