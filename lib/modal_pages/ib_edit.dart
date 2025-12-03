import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/ib_info.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

void showEditIBModal(
  BuildContext context,
  DocumentSnapshot userDoc, {
  String? previousModal,
}) {
  final userData = userDoc.data() as Map<String, dynamic>;
  final titleController = TextEditingController(
    text: userData['ib_title'] ?? userData['title'] ?? '',
  );
  
  // FIX: Normalize the category value to match dropdown items
  String rawCategory = userData['category'] ?? 'General';
  String selectedCategory = _normalizeCategory(rawCategory);

  final categories = ['Admission', 'Scholarship', 'Placement', 'General'];

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit Document',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (context, setState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;
          final isTablet = screenWidth >= 600 && screenWidth < 1024;
          final isDesktop = screenWidth >= 1024;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 20 : 28),
                      decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                      child: Row(
                        children: [
                          // Show back button only if previousModal is provided
                          if (previousModal == 'info' ||
                              previousModal == 'fullContent') ...[
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  // Add delay before showing previous modal
                                  Future.delayed(
                                    const Duration(milliseconds: 200),
                                    () {
                                      if (previousModal == 'info') {
                                        showIBInfoModal(
                                          context,
                                          userDoc,
                                          fromEdit: true,
                                        );
                                      }
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.edit_document,
                              color: Colors.white,
                              size: isMobile ? 24 : 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Document',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Update document information',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    color: Colors.white.withOpacity(0.85),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 20 : 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Document Title Section
                            buildSectionHeader('Document Title', Icons.title),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: titleController,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter document title',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2E7D32),
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Content Preview Section
                            buildSectionHeader(
                              'Content Preview',
                              Icons.article_outlined,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 120),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  userData['content'] ??
                                      'No content available.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Category Section
                            buildSectionHeader(
                              'Category',
                              Icons.category_outlined,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF334155),
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2E7D32),
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              items: categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(category),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(category),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedCategory = newValue;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 32),

                            // Action Buttons - ✅ Pass titleController directly
                            _buildActionButtons(
                              context,
                              userDoc,
                              titleController,
                              selectedCategory,
                              previousModal,
                              isMobile,
                              isTablet,
                              isDesktop,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

Widget _buildActionButtons(
  BuildContext context,
  DocumentSnapshot userDoc,
  TextEditingController titleController, // ✅ Changed to accept controller
  String selectedCategory,
  String? previousModal,
  bool isMobile,
  bool isTablet,
  bool isDesktop,
) {
  double buttonHeight = isMobile ? 40 : isTablet ? 44 : 46;
  double fontSize = isMobile ? 14 : 15;
  double borderRadius = 10;

  return Row(
    children: [
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              // ✅ Get the value at the time of button press
              final title = titleController.text.trim();
              print('Saving with title: $title'); // Debug
              _handleSaveChanges(
                context,
                userDoc,
                title,
                selectedCategory,
                previousModal,
              );
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(
              'Save Changes',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
    ],
  );
}

// Helper function to show full content modal (for back navigation)
void _showFullContentModal(
  BuildContext context,
  Map<String, dynamic> data,
  bool isMobile,
  bool isTablet,
  DocumentSnapshot doc,
) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Full Content',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 800,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E7D32), Color(0xFF059669)],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.of(context).pop();
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () => showIBInfoModal(context, doc),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white.withOpacity(0.9),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.article,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full Content',
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['ib_title'] ?? 'Document Content',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 15,
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              color: Colors.white.withOpacity(0.9),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Full Content
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isMobile ? 20 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Content stats
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF2E7D32).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFF2E7D32),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(data['content'] ?? '').toString().length} characters',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Scrollable content
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                data['content'] ?? 'No content available.',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: const Color(0xFF334155),
                                  height: 1.6,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        _buildFullContentActionButtons(
                          context,
                          doc,
                          isMobile,
                          isTablet,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

Widget _buildFullContentActionButtons(
  BuildContext context,
  DocumentSnapshot doc,
  bool isMobile,
  bool isTablet,
) {
  double buttonHeight =
      isMobile
          ? 40
          : isTablet
          ? 44
          : 46;
  double fontSize = isMobile ? 14 : 15;
  double borderRadius = 10;

  return Row(
    children: [
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Future.delayed(
                const Duration(milliseconds: 200),
                () =>
                    showEditIBModal(context, doc, previousModal: 'fullContent'),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'Edit',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
    ],
  );
}

Color _getCategoryColor(String category) {
  switch (category) {
    case 'Admission':
      return const Color(0xFF3B82F6);
    case 'Scholarship':
      return const Color(0xFFF59E0B);
    case 'Placement':
      return const Color(0xFFEF4444);
    case 'General':
    default:
      return const Color(0xFF2E7D32);
  }
}

Future<void> _handleSaveChanges(
  BuildContext context,
  DocumentSnapshot userDoc,
  String title,
  String category,
  String? previousModal,
) async {
  print('_handleSaveChanges called with title: $title'); // Debug
  
  if (title.isEmpty) {
    SnackbarUtil.showError(context, 'Please enter a document title');
    return;
  }

  try {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      ),
    );

    // Prepare update data - ALWAYS update both title fields
    Map<String, dynamic> updateData = {
      'ib_title': title,
      'title': title,
      'category': category,
      'categoryID': category.toLowerCase(),
      'categoryType': category.toLowerCase(),
      'updatedAt': Timestamp.now(),
    };

    print('Updating document ${userDoc.id} with data: $updateData'); // Debug

    // Update the document
    await FirebaseFirestore.instance
        .collection('information_bank')
        .doc(userDoc.id)
        .update(updateData);

    print('Document updated successfully'); // Debug

    // ✅ Fetch the updated document
    final updatedDocSnapshot = await FirebaseFirestore.instance
        .collection('information_bank')
        .doc(userDoc.id)
        .get();

    print('Fetched updated document: ${updatedDocSnapshot.data()}'); // Debug

    // Get current user for logging
    final currentUser = FirebaseAuth.instance.currentUser;
    String actorName = 'Unknown';

    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        actorName = data['name'] ?? currentUser.email ?? 'Unknown';
      }
    }

    // Log the update
    final logRef = FirebaseFirestore.instance.collection('logs').doc();
    final logData = {
      'logId': logRef.id,
      'user': actorName,
      'action': 'Updated document: $title (Category: $category)',
      'time': Timestamp.now(),
    };
    await logRef.set(logData);

    // Close loading and modal
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(); // Close edit modal

      // Navigate back with the UPDATED document
      Future.delayed(const Duration(milliseconds: 200), () {
        if (previousModal == 'info') {
          showIBInfoModal(context, updatedDocSnapshot, fromEdit: true);
        }
      });

      SnackbarUtil.showSuccess(context, 'Document updated successfully');
    }
  } catch (e) {
    print('Error updating document: $e'); // Debug
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      SnackbarUtil.showError(context, 'Failed to update document: $e');
    }
  }
}


String _normalizeCategory(String category) {
  // Convert to lowercase for comparison, then return proper case
  switch (category.toLowerCase()) {
    case 'admission':
      return 'Admission';
    case 'scholarship':
      return 'Scholarship';
    case 'placement':
      return 'Placement';
    case 'general':
    default:
      return 'General';
  }
}