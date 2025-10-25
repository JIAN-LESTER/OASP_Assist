// import 'package:flutter/material.dart';
// import 'package:oasp_capstone_project/pages/admin_pages/buttons/add_user_button.dart';
// import 'package:oasp_capstone_project/pages/admin_pages/widgets/role_dropdown_button.dart';

// Widget _buildUserHeader(
//   String selectedRole,
//   ValueChanged<String> onRoleChanged,
//   TextEditingController searchController,
// ) {
//   return LayoutBuilder(
//     builder: (context, constraints) {
//       double screenWidth = MediaQuery.of(context).size.width;
//       bool isMobile = screenWidth < 600;
//       bool isTablet = screenWidth >= 600 && screenWidth < 1100;

//       return Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Title and Add Button
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Users Management',
//                     style: TextStyle(
//                       fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Manage accounts and user roles',
//                     style: TextStyle(
//                       fontSize: isMobile ? 12 : 14,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                 ],
//               ),
//               AddUserButton(),
//             ],
//           ),
//           SizedBox(height: isMobile ? 16 : 20),

//           // Search and Filter Row
//           isMobile
//               ? Column(
//                 children: [
//                  _buildSearchField(searchController),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: RoleDropdownButton(
//                           initialValue: selectedRole,
//                           onChanged: onRoleChanged,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               )
//               : Row(
//                 children: [
//                   Expanded(flex: 2, child: _buildSearchField(searchController)),
//                   const SizedBox(width: 16),
//                   RoleDropdownButton(
//                     initialValue: selectedRole,
//                     onChanged: onRoleChanged,
//                   ),
//                 ],
//               ),
//         ],
//       );
//     },
//   );
// }

// // Widget _buildHeader(
// //   DateTimeRange? selectedDateRange,
// //   ValueChanged<DateTimeRange?> onDateRangeChanged,
// //   TextEditingController searchController,
// //   VoidCallback onRefresh,
// //   VoidCallback onSearchChanged,
// // ) {
// //   return LayoutBuilder(
// //     builder: (context, constraints) {
// //       double screenWidth = MediaQuery.of(context).size.width;
// //       bool isMobile = screenWidth < 600;
// //       bool isTablet = screenWidth >= 600 && screenWidth < 1100;

// //       return Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // Title and Refresh Button
// //           Row(
// //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //             children: [
// //               Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text(
// //                     'User Activity Logs',
// //                     style: TextStyle(
// //                       fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
// //                       fontWeight: FontWeight.bold,
// //                       color: Colors.black87,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 4),
// //                   Text(
// //                     'Track user interactions and system events',
// //                     style: TextStyle(
// //                       fontSize: isMobile ? 12 : 14,
// //                       color: Colors.grey[600],
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //               ElevatedButton.icon(
// //                 onPressed: onRefresh,
// //                 icon: Icon(
// //                   Icons.refresh,
// //                   size: isMobile ? 16 : 18,
// //                   color: Colors.white,
// //                 ),
// //                 label: Text(
// //                   'Refresh',
// //                   style: TextStyle(
// //                     fontSize: isMobile ? 12 : 14,
// //                     color: Colors.white,
// //                     fontWeight: FontWeight.w600,
// //                   ),
// //                 ),
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor: Colors.green,
// //                   padding: EdgeInsets.symmetric(
// //                     horizontal: isMobile ? 12 : 16,
// //                     vertical: isMobile ? 8 : 10,
// //                   ),
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(8),
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //           SizedBox(height: isMobile ? 16 : 20),

// //           // Search and Filter Row
// //           isMobile
// //               ? Column(
// //                 children: [
// //                   _buildSearchField(
// //                     searchController,
// //                     onSearchChanged: onSearchChanged,
// //                   ),
// //                   const SizedBox(height: 12),
// //                   Row(
// //                     children: [
// //                       Expanded(
// //                         child: DateRangeFilter(
// //                           selectedDateRange: selectedDateRange,
// //                           onDateRangeChanged: onDateRangeChanged,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ],
// //               )
// //               : Row(
// //                 children: [
// //                   Expanded(
// //                     flex: 2,
// //                     child: _buildSearchField(
// //                       searchController,
// //                       onSearchChanged: onSearchChanged,
// //                     ),
// //                   ),
// //                   const SizedBox(width: 16),
// //                   DateRangeFilter(
// //                     selectedDateRange: selectedDateRange,
// //                     onDateRangeChanged: onDateRangeChanged,
// //                   ),
// //                 ],
// //               ),
// //         ],
// //       );
// //     },
// //   );
// // }

// // Widget _buildHeader(
// //   String selectedCategory,
// //   ValueChanged<String> onCategoryChanged,
// //   TextEditingController searchController,
// // ) {
// //   return LayoutBuilder(
// //     builder: (context, constraints) {
// //       double screenWidth = MediaQuery.of(context).size.width;
// //       bool isMobile = screenWidth < 600;
// //       bool isTablet = screenWidth >= 600 && screenWidth < 1100;

// //       return Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // Title and Upload Button
// //           Row(
// //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //             children: [
// //               Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text(
// //                     'Information Bank',
// //                     style: TextStyle(
// //                       fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
// //                       fontWeight: FontWeight.bold,
// //                       color: Colors.black87,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 4),
// //                   Text(
// //                     'Centralized document repository for quick reference',
// //                     style: TextStyle(
// //                       fontSize: isMobile ? 12 : 14,
// //                       color: Colors.grey[600],
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //               UploadDocumentButton(),
// //             ],
// //           ),
// //           SizedBox(height: isMobile ? 16 : 20),

// //           // Search and Filter Row
// //           isMobile
// //               ? Column(
// //                 children: [
// //                   _buildSearchField(searchController),
// //                   const SizedBox(height: 12),
// //                   Row(
// //                     children: [
// //                       Expanded(
// //                         child: CategoryDropdownButton(
// //                           initialValue: selectedCategory,
// //                           onChanged: onCategoryChanged,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ],
// //               )
// //               : Row(
// //                 children: [
// //                   Expanded(flex: 2, child: _buildSearchField(searchController)),
// //                   const SizedBox(width: 16),
// //                   CategoryDropdownButton(
// //                     initialValue: selectedCategory,
// //                     onChanged: onCategoryChanged,
// //                   ),
// //                 ],
// //               ),
// //         ],
// //       );
// //     },
// //   );
// // }

// // Widget _buildHeader(
// //   String selectedCategory,
// //   ValueChanged<String> onCategoryChanged,
// //   TextEditingController searchController,
// // ) {
// //   return LayoutBuilder(
// //     builder: (context, constraints) {
// //       double screenWidth = MediaQuery.of(context).size.width;
// //       bool isMobile = screenWidth < 600;
// //       bool isTablet = screenWidth >= 600 && screenWidth < 1100;

// //       return Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // Title and Upload Button
// //           Row(
// //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //             children: [
// //               Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text(
// //                     'FAQ Management',
// //                     style: TextStyle(
// //                       fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
// //                       fontWeight: FontWeight.bold,
// //                       color: Colors.black87,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 4),
// //                   Text(
// //                     'Manage questions, answers, and categories',
// //                     style: TextStyle(
// //                       fontSize: isMobile ? 12 : 14,
// //                       color: Colors.grey[600],
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //               AddFaqButton(),
// //             ],
// //           ),
// //           SizedBox(height: isMobile ? 16 : 20),

// //           // Search and Filter Row
// //           isMobile
// //               ? Column(
// //                   children: [
// //                     _buildSearchField(searchController),
// //                     const SizedBox(height: 12),
// //                     Row(
// //                       children: [
// //                         Expanded(
// //                           child: FaqCategoryDropdownButton(
// //                             initialValue: selectedCategory,
// //                             onChanged: onCategoryChanged,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ],
// //                 )
// //               : Row(
// //                   children: [
// //                     Expanded(
// //                       flex: 2,
// //                       child: _buildSearchField(searchController),
// //                     ),
// //                     const SizedBox(width: 16),
// //                     FaqCategoryDropdownButton(
// //                       initialValue: selectedCategory,
// //                       onChanged: onCategoryChanged,
// //                     ),
// //                   ],
// //                 ),
// //         ],
// //       );
// //     },
// //   );
// // }