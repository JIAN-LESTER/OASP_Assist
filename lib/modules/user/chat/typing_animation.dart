// Add this new widget to your chat_page.dart file
// Replace the typing cursor implementation with this typing text animation

// Simple direct text display - no animation needed since streaming already provides the effect
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class StreamingTextDisplay extends StatelessWidget {
  final String text;
  final bool isUser;
  final TextStyle? style;
  final MarkdownStyleSheet? markdownStyleSheet;
  final Function(LinkableElement)? onLinkTap;

  const StreamingTextDisplay({
    Key? key,
    required this.text,
    required this.isUser,
    this.style,
    this.markdownStyleSheet,
    this.onLinkTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Just display the text directly - streaming provides the typing effect
    if (isUser) {
      return SelectableLinkify(
        onOpen: onLinkTap,
        text: text,
        textAlign: TextAlign.justify,
        style: style ?? TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        linkStyle: TextStyle(
          decoration: TextDecoration.underline,
          color: Colors.yellow[100],
          fontWeight: FontWeight.w600,
        ),
        options: LinkifyOptions(
          humanize: false,
          looseUrl: true,
          defaultToHttps: true,
        ),
      );
    } else {
      return MarkdownBody(
        data: text,
        selectable: true,
        onTapLink: (linkText, href, title) {
          if (href != null && onLinkTap != null) {
            onLinkTap!(LinkableElement(href, linkText));
          }
        },
        styleSheet: markdownStyleSheet,
      );
    }
  }
}

// Blinking cursor for streaming messages
class BlinkingCursor extends StatefulWidget {
  final Color color;
  
  const BlinkingCursor({required this.color});
  
  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 16,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}