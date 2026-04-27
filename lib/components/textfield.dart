import 'package:flutter/material.dart';

class Textfield extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isPasswordField;
  final ValueChanged<String>? onSubmitted;
  final String? errorText; // error text parameter

  const Textfield({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.isPasswordField = false,
    this.onSubmitted,
    this.errorText,
  });

  @override
  State<Textfield> createState() => _TextfieldState();
}

class _TextfieldState extends State<Textfield> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  Widget? _getPrefixIcon() {
    if (widget.prefixIcon != null) {
      return widget.prefixIcon;
    }

    String hintLower = widget.hintText.toLowerCase();

    if (hintLower.contains('email') || hintLower.contains('e-mail')) {
      return Icon(Icons.email_outlined, color: Colors.grey[600], size: 20);
    } else if (hintLower.contains('password') || hintLower.contains('pass')) {
      return Icon(Icons.lock_outline, color: Colors.grey[600], size: 20);
    } else if (hintLower.contains('phone') || hintLower.contains('mobile')) {
      return Icon(Icons.phone_outlined, color: Colors.grey[600], size: 20);
    } else if (hintLower.contains('name')) {
      return Icon(Icons.person_outline, color: Colors.grey[600], size: 20);
    }

    return null;
  }

  Widget? _getSuffixIcon() {
    if (widget.suffixIcon != null) {
      return widget.suffixIcon;
    }

    if (widget.isPasswordField || widget.obscureText) {
      return IconButton(
        icon: Icon(
          _isObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: Colors.grey[600],
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _isObscured = !_isObscured;
          });
        },
        splashRadius: 20,
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.controller,
            obscureText: _isObscured,
            validator: widget.validator,
            keyboardType:
                widget.keyboardType ??
                (_isObscured ? TextInputType.text : TextInputType.emailAddress),
            onFieldSubmitted: widget.onSubmitted,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
              ),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: _getPrefixIcon(),
              suffixIcon: _getSuffixIcon(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey[400]!,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey,
                  width: 2.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 2.0),
              ),
            ),
          ),
          // Error text below the textfield
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text(
                widget.errorText!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
