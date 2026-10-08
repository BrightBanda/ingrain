import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders transcript text with one tap target per token.
///
/// A stateful widget is required because every token owns a
/// [TapGestureRecognizer], and those have to be disposed when the sentence
/// changes or the row leaves the tree.
class TappableTranscriptText extends StatefulWidget {
  /// Tokenised form of the sentence; concatenating them rebuilds the text.
  final List<String> tokens;
  final TextStyle? style;
  final Color? highlightColor;
  final Color tapColor;
  final void Function(String token) onTokenTap;

  const TappableTranscriptText({
    super.key,
    required this.tokens,
    required this.onTokenTap,
    this.style,
    this.highlightColor,
    this.tapColor = Colors.transparent,
  });

  @override
  State<TappableTranscriptText> createState() => _TappableTranscriptTextState();
}

class _TappableTranscriptTextState extends State<TappableTranscriptText> {
  /// One recognizer per token, kept across rebuilds. A transcript line rebuilds
  /// whenever the current line moves, and churning a recognizer per word on
  /// each of those frames competed with video playback for the UI thread.
  final List<TapGestureRecognizer> _recognizers = [];
  List<String>? _recognizedTokens;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  void didUpdateWidget(TappableTranscriptText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.tokens, widget.tokens)) _disposeRecognizers();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _recognizedTokens = null;
  }

  /// Creates the recognizers once per token list. Each reads `widget` when
  /// tapped, so a new callback from the parent is still honoured.
  void _ensureRecognizers() {
    if (_recognizedTokens != null) return;
    for (final token in widget.tokens) {
      _recognizers.add(
        TapGestureRecognizer()..onTap = () => widget.onTokenTap(token),
      );
    }
    _recognizedTokens = widget.tokens;
  }

  @override
  Widget build(BuildContext context) {
    _ensureRecognizers();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final highlight = widget.highlightColor;

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final (index, token) in widget.tokens.indexed)
            if (_isTapTarget(token))
              TextSpan(
                text: token,
                style: highlight == null ? null : TextStyle(color: highlight),
                recognizer: _recognizers[index],
              )
            else
              TextSpan(text: token),
        ],
      ),
    );
  }

  bool _isTapTarget(String token) {
    // Punctuation, spaces and the like are not words, so they stay inert.
    return token.trim().isNotEmpty;
  }
}
