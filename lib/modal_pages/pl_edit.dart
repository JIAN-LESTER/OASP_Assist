import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_project/modal_pages/pl_info.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';

void showEditPLModal(
  BuildContext context,
  DocumentSnapshot userDoc, {
  String? previousModal,
}) {
  final userData = userDoc.data() as Map<String, dynamic>;
  final placementIDController = TextEditingController(
    text: userData['placementID'] ?? '',
  );
  final partnerCompanyController = TextEditingController(
    text: userData['partnerCompany'] ?? '',
  );

  // Parse contacts list
  final List<String> contactsList = (userData['contacts'] as List<dynamic>?)
          ?.map((c) => c.toString().trim())
          .where((c) => c.isNotEmpty)
          .toList() ?? [];
  
  // Parse positions list
  final List<String> positionsList = (userData['positions'] as List<dynamic>?)
          ?.map((s) => s.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList() ?? [];

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit Placement Details',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (context, setState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          final isMobile = screenWidth < 600;
          final isTablet = screenWidth >= 600 && screenWidth < 1024;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.95 : 650,
                maxHeight: screenHeight * 0.9,
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
                  children: [
                    // Header (fixed at top)
                    _buildHeader(
                      context,
                      userDoc,
                      previousModal,
                      isMobile,
                    ),
                    
                    // Scrollable content (fills remaining space)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isMobile ? 20 : 24,
                          isMobile ? 20 : 24,
                          isMobile ? 20 : 24,
                          0, // No bottom padding since buttons are fixed
                        ),
                        child: _buildScrollableContent(
                          userData: userData,
                          contactsList: contactsList,
                          positionsList: positionsList,
                          isMobile: isMobile,
                          placementIDController: placementIDController,
                          partnerCompanyController: partnerCompanyController,
                        ),
                      ),
                    ),
                    
                    // Fixed action buttons at bottom
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: _buildActionButtons(
                        context,
                        userDoc,
                        placementIDController,
                        partnerCompanyController,
                        previousModal,
                        isMobile,
                        isTablet,
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
        if (previousModal == 'info') ...[
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
                      showPLInfoModal(
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
                'Edit Placement',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Update placement information',
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
  required List<String> contactsList,
  required List<String> positionsList,
  required bool isMobile,
  required TextEditingController placementIDController,
  required TextEditingController partnerCompanyController,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [


      // Partner Company Section
      buildSectionHeader('Partner Company', Icons.business_outlined),
      const SizedBox(height: 12),
      TextFormField(
        controller: partnerCompanyController,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Enter partner company name',
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

      // Available Positions Section
      buildSectionHeader(
        'Available Positions',
        Icons.work_outline,
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
          child: positionsList.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: positionsList.asMap().entries.map((entry) {
                    int index = entry.key;
                    String position = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < positionsList.length - 1 ? 8 : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 8, top: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              position,
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
                  'No positions available.',
                  style: TextStyle(
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
          child: contactsList.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: contactsList.asMap().entries.map((entry) {
                    int index = entry.key;
                    String contact = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < contactsList.length - 1 ? 8 : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 16,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              contact,
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
                  'No contact information available.',
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
  TextEditingController placementIDController,
  TextEditingController partnerCompanyController,
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
              placementIDController.text.trim(),
              partnerCompanyController.text.trim(),
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

Future<void> _handleSaveChanges(
  BuildContext context,
  DocumentSnapshot userDoc,
  String placementID,
  String partnerCompany,
  String? previousModal,
) async {
  if (placementID.isEmpty || partnerCompany.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill in all required fields.'),
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
        .collection('placements')
        .doc(userDoc.id)
        .update({
          'placementID': placementID,
          'partnerCompany': partnerCompany,
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
      'action': 'Updated placement: $placementID',
      'time': Timestamp.now(),
    };
    await logRef.set(logData);

    // Close loading and modal, then navigate back if needed
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      Navigator.of(context).pop(); // Close edit modal

      // Use Future.delayed to prevent black screen flash
      Future.delayed(const Duration(milliseconds: 200), () {
        // If we came from info modal, show it again
        if (previousModal == 'info') {
          showPLInfoModal(context, userDoc, fromEdit: true);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Placement updated successfully'),
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