import 'package:capstone_project/modal_pages/add_edit_scholarship.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_project/crud/delete/delete.dart';
import 'package:capstone_project/modal_pages/scholarship_edit.dart';
import 'package:capstone_project/modal_pages/modal_widget/section_header.dart';
import 'package:capstone_project/utils/snackbar_util.dart';

// Custom delete handler that uses SnackbarUtil
Future<void> handleScholarshipDelete(
  BuildContext context,
  DocumentSnapshot doc,
) async {
  try {
    await FirebaseFirestore.instance
        .collection('scholarships')
        .doc(doc.id)
        .delete();

    if (context.mounted) {
      SnackbarUtil.showSuccess(context, 'Scholarship deleted successfully');
    }
  } catch (e) {
    if (context.mounted) {
      SnackbarUtil.showError(context, 'Failed to delete scholarship: $e');
    }
  }
}

void showSCInfoModal(
  BuildContext context,
  DocumentSnapshot doc, {
  bool fromEdit = false,
}) {
  final data = doc.data() as Map<String, dynamic>;
  final scholarshipID = data['scholarshipID'] ?? data['id'] ?? '';
  final name = data['name'] ?? 'Unnamed Scholarship';
  final description = data['description'] ?? 'No description available';
  final scholarshipProvider = data['scholarshipProvider'] ?? 'Unknown Provider';

  final deadline =
      data['deadline'] != null
          ? (data['deadline'] is Timestamp
              ? (data['deadline'] as Timestamp).toDate()
              : DateTime.tryParse(data['deadline'].toString()) ??
                  DateTime.now())
          : DateTime.now();

  final applicationLink = data['applicationLink'] ?? '';

  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1024;

  final Timestamp timeStamp = data['createdAt'] ?? Timestamp.now();
  final DateTime date = timeStamp.toDate();
  final String formattedDate = DateFormat(
    'MMM dd, yyyy • hh:mm a',
  ).format(date);

  // Parse eligibility requirements list
  final List<String> eligibilityRequirements =
      (data['eligibilityRequirements'] as List<dynamic>?)
          ?.map((c) => c.toString().trim())
          .where((c) => c.isNotEmpty)
          .toList() ??
      [];

  // Parse privileges list
  final List<String> privileges =
      (data['privileges'] as List<dynamic>?)
          ?.map((s) => s.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList() ??
      [];

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Scholarship Info',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isMobile ? screenWidth * 0.95 : 600,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                  child: Row(
                    children: [
                      // Back button (shown when coming from edit)
                      if (fromEdit) ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.of(context).pop(),
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
                          Icons.school_outlined,
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
                              'Scholarship Details',
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Information and metadata',
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
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Section
                        buildSectionHeader('Scholarship Name', Icons.title),
                        const SizedBox(height: 12),
                        _buildContentCard(name),

                        const SizedBox(height: 24),

                        // Description Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildSectionHeader(
                              'Description',
                              Icons.description_outlined,
                            ),
                            TextButton.icon(
                              onPressed:
                                  () => _showFullDescriptionModal(
                                    context,
                                    data,
                                    isMobile,
                                    isTablet,
                                    doc,
                                  ),
                              icon: const Icon(
                                Icons.open_in_full,
                                size: 16,
                                color: Color(0xFF2E7D32),
                              ),
                              label: const Text(
                                'View Full',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 120),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF475569),
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Eligibility Requirements Section
                        if (eligibilityRequirements.isNotEmpty) ...[
                          buildSectionHeader(
                            'Eligibility Requirements',
                            Icons.checklist_outlined,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 150),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    eligibilityRequirements.asMap().entries.map(
                                      (entry) {
                                        int index = entry.key;
                                        String requirement = entry.value;
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom:
                                                index <
                                                        eligibilityRequirements
                                                                .length -
                                                            1
                                                    ? 12
                                                    : 0,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                margin: const EdgeInsets.only(
                                                  right: 12,
                                                  top: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF2E7D32,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  requirement,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF475569),
                                                    height: 1.5,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Privileges Section
                        if (privileges.isNotEmpty) ...[
                          buildSectionHeader(
                            'Privileges',
                            Icons.star_border_outlined,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 150),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    privileges.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      String privilege = entry.value;
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              index < privileges.length - 1
                                                  ? 12
                                                  : 0,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 16,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                privilege,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF475569),
                                                  height: 1.5,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Metadata Section
                        buildSectionHeader(
                          'Additional Info',
                          Icons.info_outline,
                        ),
                        const SizedBox(height: 12),
                        Container(
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
                          child: Column(
                            children: [
                              _buildMetadataRow(
                                'Scholarship ID',
                                scholarshipID,
                                Icons.fingerprint_outlined,
                              ),
                              const SizedBox(height: 16),
                              _buildMetadataRow(
                                'Provider',
                                scholarshipProvider,
                                Icons.business_outlined,
                              ),
                              const SizedBox(height: 16),
                              _buildMetadataRow(
                                'Deadline',
                                DateFormat('MMM dd, yyyy').format(deadline),
                                Icons.schedule_outlined,
                              ),
                              if (applicationLink.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildMetadataRow(
                                  'Application Link',
                                  applicationLink,
                                  Icons.link_outlined,
                                ),
                              ],
                              const SizedBox(height: 16),
                              _buildMetadataRow(
                                'Created',
                                formattedDate,
                                Icons.add_circle_outline,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: _buildActionButtons(context, doc, isMobile, isTablet),
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

Widget _buildActionButtons(
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
      // Delete Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton.icon(
            onPressed:
                () => showDeleteConfirmation(
                  context,
                  doc,
                  DeleteConfigs.scholarships,
                  'scholarships',
                  customDeleteHandler: handleScholarshipDelete,
                ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(
              'Delete',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Edit Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Future.delayed(
                const Duration(milliseconds: 200),
                () => showDialog(
                  context: context,
                  builder:
                      (context) =>
                          ScholarshipFormDialog(doc: doc, isEdit: true),
                ),
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

void _showFullDescriptionModal(
  BuildContext context,
  Map<String, dynamic> data,
  bool isMobile,
  bool isTablet,
  DocumentSnapshot doc,
) {
  // Close the current modal first to prevent stacking
  Navigator.of(context).pop();

  // Add delay before showing new modal
  Future.delayed(const Duration(milliseconds: 200), () {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Full Description',
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
                    decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                    child: Row(
                      children: [
                        // Back button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              Navigator.of(context).pop();
                              // Re-show the document info modal with delay
                              Future.delayed(
                                const Duration(milliseconds: 200),
                                () => showSCInfoModal(context, doc),
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
                            Icons.description,
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
                                'Full Description',
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['name'] ?? 'Scholarship Description',
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

                  // Full Description
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
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
                                color: Color(0xFF2E7D32).withOpacity(0.2),
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
                                  '${(data['description'] ?? '').toString().length} characters',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2E7D32),
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
                                  data['description'] ??
                                      'No description available.',
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
                          _buildFullDescriptionActionButtons(
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
  });
}

Widget _buildFullDescriptionActionButtons(
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
      // Delete Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: OutlinedButton.icon(
            onPressed:
                () => showDeleteConfirmation(
                  context,
                  doc,
                  DeleteConfigs.scholarships,
                  'scholarships',
                  customDeleteHandler: handleScholarshipDelete,
                ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(
              'Delete',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Edit Button
      Expanded(
        child: SizedBox(
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Future.delayed(
                const Duration(milliseconds: 200),
                () => showDialog(
                  context: context,
                  builder:
                      (context) =>
                          ScholarshipFormDialog(doc: doc, isEdit: true),
                ),
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

Widget _buildContentCard(String content) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
    ),
    child: Text(
      content,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF334155),
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
    ),
  );
}

Widget _buildMetadataRow(String label, String value, IconData icon) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF64748B)),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    ],
  );
}
