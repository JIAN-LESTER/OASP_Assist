// import 'package:flutter/material.dart';

// Widget buildCategorySection() {
//   String selectedCategory = 'General';
//   bool _isSubmitting = false;

//   final List<String> _categories = [
//     'Admission',
//     'Scholarship',
//     'Placement',
//     'General',
//   ];

//   bool isMobile;
//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Wrap(
//         spacing: .isMobile ? 8 : 10,
//         runSpacing: widget.isMobile ? 8 : 10,
//         children:
//             _categories.map((category) {
//               final isSelected = selectedCategory == category;
//               return Material(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   borderRadius: BorderRadius.circular(22),
//                   onTap: () {
//                     setState(() {
//                       selectedCategory = category;
//                     });
//                   },
//                   child: Container(
//                     padding: EdgeInsets.symmetric(
//                       horizontal: isMobile ? 16 : 20,
//                       vertical: isMobile ? 8 : 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color:
//                           isSelected
//                               ? const Color(0xFF2E7D32)
//                               : const Color(0xFFF9FAFB),
//                       borderRadius: BorderRadius.circular(22),
//                       border: Border.all(
//                         color:
//                             isSelected
//                                 ? const Color(0xFF2E7D32)
//                                 : const Color(0xFFE5E7EB),
//                         width: 1.5,
//                       ),
//                     ),
//                     child: Text(
//                       category,
//                       style: TextStyle(
//                         color:
//                             isSelected ? Colors.white : const Color(0xFF6B7280),
//                         fontWeight:
//                             isSelected ? FontWeight.w600 : FontWeight.w500,
//                         fontSize: widget.isMobile ? 13 : 14,
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             }).toList(),
//       ),
//     ],
//   );
// }
