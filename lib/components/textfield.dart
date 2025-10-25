import 'package:flutter/material.dart';

class Textfield extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final String? Function(String?)? validator; // Optional validation
  final TextInputType? keyboardType; // Optional custom keyboard type
  final Widget? prefixIcon; // Optional prefix icon
  final Widget? suffixIcon; // Optional suffix icon (like show/hide password)
  final bool isPasswordField; // New parameter to identify password fields

  const Textfield({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.isPasswordField = false, // Default to false
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

  // Method to get appropriate prefix icon based on hint text
  Widget? _getPrefixIcon() {
    if (widget.prefixIcon != null) {
      return widget.prefixIcon;
    }

    // Auto-detect icon based on hint text
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

  // Method to get suffix icon (eye icon for password fields)
  Widget? _getSuffixIcon() {
    if (widget.suffixIcon != null) {
      return widget.suffixIcon;
    }

    // Add eye icon for password fields
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ), // Match button padding
      child: TextFormField(
        // Use TextFormField for validation support
        controller: widget.controller,
        obscureText: _isObscured,
        validator: widget.validator,
        keyboardType:
            widget.keyboardType ??
            (_isObscured ? TextInputType.text : TextInputType.emailAddress),
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
            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey, width: 2.0),
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
    );
  }
}
