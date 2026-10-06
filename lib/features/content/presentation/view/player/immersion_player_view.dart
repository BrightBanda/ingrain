import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:ingrain/core/utils/duration_format.dart';
import 'package:ingrain/features/content/data/youtube_url_parser.dart';
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
  StreamSubscription<YoutubeVideoState>? _videoStateSubscription;
  StreamSubscription<YoutubePlayerValue>? _playerStreamSubscription;
  bool _videoLoadStarted = false;
  bool _videoReady = false;
  bool _playerIsPlaying = false;
  String? _videoId;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: false,
        enableKeyboard: false,
        showControls: false,
        origin: 'https://www.youtube-nocookie.com',
        strictRelatedVideos: true,
      ),
      onWebResourceError: (error) {
        if (!mounted) return;
        setState(() {
          _playerError = 'Network error: ${error.description}';
          _videoReady = false;
          _videoLoadStarted = false;
        });
      },
    );

    _videoStateSubscription = _controller.videoStateStream.listen((state) {
      ref.read(playbackPositionProvider.notifier).setPosition(state.position);
      ref
          .read(immersionSessionViewModelProvider(widget.contentId).notifier)
          .updatePosition(state.position.inSeconds);
    });

    _playerStreamSubscription = _controller.stream.listen((value) {
      if (!mounted) return;
      if (value.error != YoutubeError.none &&
          value.error != YoutubeError.unknown) {
        setState(() {
          _playerError = _mapYoutubeError(value.error);
          _videoReady = false;
          _videoLoadStarted = false;
        });
      } else if (value.playerState == PlayerState.playing ||
          value.playerState == PlayerState.paused ||
          value.playerState == PlayerState.buffering ||
          value.playerState == PlayerState.cued) {
        if (!_videoReady) {
          setState(() {
            _videoReady = true;
            _playerError = null;
          });
        }
      }

      final sessionVm = ref.read(
        immersionSessionViewModelProvider(widget.contentId).notifier,
      );
      final sessionState = ref.read(
        immersionSessionViewModelProvider(widget.contentId),
      );

      if (value.playerState == PlayerState.playing) {
        _playerIsPlaying = true;
        if (!sessionState.hasActiveSession && !sessionState.isPaused) {
          final title =
              ref
                  .read(contentItemProvider(widget.contentId))
                  .asData
                  ?.value
                  .title ??
              'Video';
          sessionVm.startSession(sourceTitle: title);
        }
      } else if (value.playerState == PlayerState.paused ||
          value.playerState == PlayerState.ended) {
        _playerIsPlaying = false;
        if (sessionState.isRunning && !sessionState.isPaused) {
          sessionVm.pauseSession();
        }
      }
    });

    // Set controller in provider after first frame to avoid build-phase modification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(playerControllerProvider.notifier).setController(_controller);
      }
    });
  }

  String _mapYoutubeError(YoutubeError error) {
    return switch (error) {
      YoutubeError.invalidParam => 'Invalid video ID or parameter.',
      YoutubeError.html5Error => 'HTML5 player error. Please try again.',
      YoutubeError.videoNotFound =>
        'This video could not be found or is private.',
      YoutubeError.notEmbeddable ||
      YoutubeError.sameAsNotEmbeddable ||
      YoutubeError.sameAsNotEmbeddable2 =>
        'The owner does not allow this video to be played in embedded players.',
      YoutubeError.cannotFindVideo => 'Could not find the requested video.',
      YoutubeError.none => '',
      YoutubeError.unknown => 'An error occurred while loading this video.',
    };
  }

  @override
  void dispose() {
    _videoStateSubscription?.cancel();
    _playerStreamSubscription?.cancel();
    _controller.close();
    ref.read(playerControllerProvider.notifier).setController(null);
    super.dispose();
  }

  Future<void> _loadVideoIfNeeded(AsyncValue<ContentItem> contentAsync) async {
    final content = contentAsync.asData?.value;
    if (content == null || _videoLoadStarted) return;
    if (content.sourceType != SourceType.youtube) return;

    // Self-healing: if content.id was previously saved as a raw tracking param
    // or invalid id, re-extract the real video ID from the source URL.
    final resolvedId =
        YoutubeUrlParser.tryParse(content.sourceUrl) ??
        YoutubeUrlParser.tryParse(content.id) ??
        content.id;

    _videoId = resolvedId;
    _videoLoadStarted = true;
    setState(() {
      _playerError = null;
      _videoReady = false;
    });

    try {
      await _controller.loadVideoById(videoId: resolvedId);
    } catch (_) {
      // The bridge waits for the iframe API itself, but it can still time out
      // or fail on weak mobile connections.
      _videoLoadStarted = false;
      if (!mounted) return;
      setState(
        () => _playerError =
            'Could not load this video. Please check your connection.',
      );
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
      _videoLoadStarted = true;
    });

    try {
      await _controller.loadVideoById(videoId: videoId);
    } catch (_) {
      _videoLoadStarted = false;
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

  Future<void> _togglePlayback() async {
    final sessionVm = ref.read(
      immersionSessionViewModelProvider(widget.contentId).notifier,
    );
    final sessionState = ref.read(
      immersionSessionViewModelProvider(widget.contentId),
    );
    final content = ref
        .read(contentItemProvider(widget.contentId))
        .asData
        ?.value;
    final title = content?.title ?? 'Video';

    if (_playerIsPlaying ||
        _controller.value.playerState == PlayerState.playing) {
      await _controller.pauseVideo();
      if (sessionState.isRunning && !sessionState.isPaused) {
        sessionVm.pauseSession();
      }
      return;
    }

    if (!sessionState.hasActiveSession) {
      sessionVm.startSession(sourceTitle: title);
    } else if (sessionState.isPaused) {
      sessionVm.resumeSession();
    }
    await _controller.playVideo();
  }

  Future<void> _confirmStopSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop session?'),
        content: const Text(
          'This will end the current session, but the elapsed time will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Stop session'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final sessionVm = ref.read(
      immersionSessionViewModelProvider(widget.contentId).notifier,
    );
    await sessionVm.stopSession();
    await _controller.pauseVideo();
    if (mounted) {
      setState(() => _playerIsPlaying = false);
    }
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _playerError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
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
    final isPlaying =
        _playerIsPlaying ||
        _controller.value.playerState == PlayerState.playing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            tooltip: isPlaying ? 'Pause' : 'Play',
            onPressed: _togglePlayback,
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryMain,
            ),
          ),
          const SizedBox(width: 16),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          if (sessionState.hasActiveSession)
            TextButton.icon(
              onPressed: _confirmStopSession,
              icon: const Icon(Icons.stop),
              label: const Text('Stop session'),
            ),
        ],
      ),
    );
  }
}
