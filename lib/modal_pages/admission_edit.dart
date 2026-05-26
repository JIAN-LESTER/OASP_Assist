
import 'package:capstone_project/modules/admin/service_information/admission/add_edit_admission.dart';
import 'package:capstone_project/modules/admin/service_information/admission/admission_info.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';

void showEditAdmissionDialog(
  BuildContext context,
  DocumentSnapshot userDoc, {
  String? previousModal,
}) {
  final userData = userDoc.data() as Map<String, dynamic>;
  final titleController = TextEditingController(
    text: userData['title'] ?? '',
  );
  final sourceController = TextEditingController(
    text: userData['source'] ?? '',
  );
  final academicYearController = TextEditingController(
    text: userData['academicYear'] ?? '',
  );

  // Parse contact list
  final List<String> contactList = (userData['contact'] as List<dynamic>?)
          ?.map((c) => c.toString().trim())
          .where((c) => c.isNotEmpty)
          .toList() ?? [];
  
  // Parse steps list
  final List<String> stepsList = (userData['steps'] as List<dynamic>?)
          ?.map((s) => s.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList() ?? [];

  showDialog(
      context: context,
    barrierDismissible: false,
    builder: (context) => AdmissionFormDialog(
      doc: userDoc,
      isEdit: true,
    ),
  ).then((result) {
    if (result == true) {
      // Refresh the list if needed
      // You can call setState here or trigger a refresh
    }
  });
  
}

Widget _buildHeader(
  BuildContext context,
  DocumentSnapshot userDoc,
  String? previousModal,
  bool isMobile,
) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(isMobile ? 20 : 24),
    decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
    child: Row(
      children: [
        // Show back button only if previousModal is provided
        if (previousModal == 'info' || previousModal == 'fullContent') ...[
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
                      showADInfoModal(
                        context,
                        userDoc,
                        fromEdit: true,
                      );
                    } else if (previousModal == 'fullContent') {
                      final userData = userDoc.data() as Map<String, dynamic>;
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isMobile = screenWidth < 600;
                      final isTablet = screenWidth >= 600 && screenWidth < 1024;
                      _showFullContentModal(
                        context,
                        userData,
                        isMobile,
                        isTablet,
                        userDoc,
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
                'Edit Admission',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Update admission information',
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
  );
}

Widget _buildScrollableContent({
  required Map<String, dynamic> userData,
  required List<String> contactList,
  required List<String> stepsList,
  required bool isMobile,
  required TextEditingController titleController,
  required TextEditingController sourceController,
  required TextEditingController academicYearController,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Title Section
      buildSectionHeader('Admission Title', Icons.title),
      const SizedBox(height: 12),
      TextFormField(
        controller: titleController,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Enter admission title',
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

      // Source Section
      buildSectionHeader('Source', Icons.source_outlined),
      const SizedBox(height: 12),
      TextFormField(
        controller: sourceController,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Enter source information',
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

      // Academic Year Section
      buildSectionHeader('Academic Year', Icons.calendar_today_outlined),
      const SizedBox(height: 12),
      TextFormField(
        controller: academicYearController,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'e.g., 2024-2025',
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
            userData['content'] ?? 'No content available.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ),
      ),

      const SizedBox(height: 24),

      // Contact Information Section
      buildSectionHeader(
        'Contact Information',
        Icons.contact_phone_outlined,
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 100),
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
            contactList.isNotEmpty
                ? contactList.join('\n')
                : 'No contact information available.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ),
      ),

      const SizedBox(height: 24),

      // Steps Section
      buildSectionHeader(
        'Steps',
        Icons.list_alt_outlined,
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
          child: stepsList.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: stepsList.asMap().entries.map((entry) {
                    int index = entry.key;
                    String step = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < stepsList.length - 1 ? 8 : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.only(right: 8, top: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF475569),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : const Text(
                  'No steps available.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
        ),
      ),
      
      // Add some bottom padding for last item
      const SizedBox(height: 24),
    ],
  );
}

Widget _buildActionButtons(
  BuildContext context,
  DocumentSnapshot userDoc,
  TextEditingController titleController,
  TextEditingController sourceController,
  TextEditingController academicYearController,
  String? previousModal,
  bool isMobile,
  bool isTablet,
) {
  // Professional button sizing
  double buttonHeight = isMobile ? 44 : 48;
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
            onPressed: () => _handleSaveChanges(
              context,
              userDoc,
              titleController.text.trim(),
              sourceController.text.trim(),
              academicYearController.text.trim(),
              previousModal,
            ),
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
                    color: Color(0xFF2E7D32),
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
                              () => showADInfoModal(context, doc),
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
                              data['title'] ?? 'Admission Content',
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
  // Professional button sizing
  double buttonHeight = isMobile ? 44 : 48;
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
                () => showEditAdmissionDialog(context, doc, previousModal: 'fullContent'),
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

Future<void> _handleSaveChanges(
  BuildContext context,
  DocumentSnapshot userDoc,
  String title,
  String source,
  String academicYear,
  String? previousModal,
) async {
  if (title.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter an admission title'),
        backgroundColor: Colors.red,
      ),
    );
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

    // Update the document
    await FirebaseFirestore.instance
        .collection('admissions') // Updated collection name
        .doc(userDoc.id)
        .update({
          'title': title,
          'source': source,
          'academicYear': academicYear,
          'updatedAt': Timestamp.now(),
        });

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
      'action': 'Updated admission: $title',
      'time': Timestamp.now(),
    };
    await logRef.set(logData);

    // Close loading and modal, then navigate back if needed
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(); // Close edit modal

      // Use Future.delayed to prevent black screen flash
      Future.delayed(const Duration(milliseconds: 200), () {
        // If we came from another modal, show it again
        if (previousModal == 'info') {
          showADInfoModal(context, userDoc, fromEdit: true);
        } else if (previousModal == 'fullContent') {
          final userData = userDoc.data() as Map<String, dynamic>;
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;
          final isTablet = screenWidth >= 600 && screenWidth < 1024;
          _showFullContentModal(context, userData, isMobile, isTablet, userDoc);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Admission updated successfully'),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Failed to update: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}