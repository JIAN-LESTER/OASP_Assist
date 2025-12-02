  import 'package:flutter/material.dart';

Widget buildTextField({
  BuildContext? context,
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  required bool isMobile,
  TextInputType? keyboardType,
  bool isPassword = false,
  bool isPasswordVisible = false,
  VoidCallback? onTogglePassword,
  String? Function(String?)? validator,
  ValueChanged<String>? onChanged,  // Added this parameter
  int maxLines = 1,
  bool? enabled,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151),
          letterSpacing: -0.1,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword && !isPasswordVisible,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,  // Added this line
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            suffixIcon:
                isPassword
                    ? IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: const Color(0xFF9CA3AF),
                        size: 20,
                      ),
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
          ),
        ),
      ),
    ],
  );
}