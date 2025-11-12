  import 'package:flutter/material.dart';
  import 'dart:async';

  class TypewriterText extends StatefulWidget {
    final String text;
    final TextStyle? style;
    final TextAlign textAlign;
    final Duration speed;
    final VoidCallback? onComplete;

    const TypewriterText({
      Key? key,
      required this.text,
      this.style,
      this.textAlign = TextAlign.justify,
      this.speed = const Duration(milliseconds: 30),
      this.onComplete,
    }) : super(key: key);

    @override
    State<TypewriterText> createState() => _TypewriterTextState();
  }

  class _TypewriterTextState extends State<TypewriterText> {
    String _displayedText = '';
    Timer? _timer;
    int _currentIndex = 0;

    @override
    void initState() {
      super.initState();
      _startTyping();
    }

    @override
    void didUpdateWidget(TypewriterText oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (oldWidget.text != widget.text) {
        _reset();
        _startTyping();
      }
    }

    void _reset() {
      _timer?.cancel();
      _currentIndex = 0;
      _displayedText = '';
    }

    void _startTyping() {
      _timer = Timer.periodic(widget.speed, (timer) {
        if (_currentIndex < widget.text.length) {
          setState(() {
            _displayedText = widget.text.substring(0, _currentIndex + 1);
            _currentIndex++;
          });
        } else {
          _timer?.cancel();
          widget.onComplete?.call();
        }
      });
    }

    @override
    void dispose() {
      _timer?.cancel();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Text(
        _displayedText,
        style: widget.style,
        textAlign: widget.textAlign,
      );
    }

    
  }