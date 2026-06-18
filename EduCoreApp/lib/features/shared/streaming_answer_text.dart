import 'package:flutter/material.dart';

class StreamingAnswerText extends StatefulWidget {
  const StreamingAnswerText({
    super.key,
    required this.text,
    required this.isStreaming,
    required this.textStyle,
    required this.cursorColor,
  });

  final String text;
  final bool isStreaming;
  final TextStyle textStyle;
  final Color cursorColor;

  @override
  State<StreamingAnswerText> createState() => _StreamingAnswerTextState();
}

class _StreamingAnswerTextState extends State<StreamingAnswerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.text, style: widget.textStyle),
          if (widget.isStreaming)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: FadeTransition(
                opacity: _cursorController,
                child: Container(
                  width: 2,
                  height: (widget.textStyle.fontSize ?? 16) * 1.1,
                  margin: const EdgeInsets.only(left: 2),
                  color: widget.cursorColor,
                ),
              ),
            ),
        ],
      ),
      textAlign: TextAlign.start,
    );
  }
}
