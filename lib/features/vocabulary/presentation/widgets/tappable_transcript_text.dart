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
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final highlight = widget.highlightColor;

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final token in widget.tokens)
            if (_isTapTarget(token))
              TextSpan(
                text: token,
                style: highlight == null ? null : TextStyle(color: highlight),
                recognizer: _recognizerFor(token),
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

  TapGestureRecognizer _recognizerFor(String token) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onTokenTap(token);
    _recognizers.add(recognizer);
    return recognizer;
  }
}
